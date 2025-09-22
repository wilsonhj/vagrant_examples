#!/bin/bash
# Comprehensive integration test for Vagrant Kubernetes cluster

set -e

# Configuration
UBUNTU_VERSION=${1:-"Ubuntu2404"}
CLEANUP=${2:-"true"}  # Set to false to keep cluster running after tests

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TESTS_PASSED++))
}

error() {
    echo -e "${RED}✗ $1${NC}"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$1")
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

run_test() {
    local test_name="$1"
    local command="$2"
    local timeout="${3:-60}"
    
    log "Running: $test_name"
    
    if timeout "$timeout" bash -c "$command" >/dev/null 2>&1; then
        success "$test_name"
        return 0
    else
        error "$test_name"
        return 1
    fi
}

# Cleanup function
cleanup() {
    if [[ "$CLEANUP" == "true" ]]; then
        log "Cleaning up test environment..."
        cd "$UBUNTU_VERSION" 2>/dev/null || true
        vagrant destroy -f >/dev/null 2>&1 || true
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Start tests
log "Starting integration tests for $UBUNTU_VERSION"
log "======================================================="

cd "$UBUNTU_VERSION" || {
    error "Directory $UBUNTU_VERSION not found"
    exit 1
}

# Set test environment
export USE_CUSTOM_BOX=false
export VM_MEMORY=2048
export WORKER_COUNT=2
export BRIDGE_INTERFACE=en0  # Adjust for your system

log "Test Configuration:"
log "  USE_CUSTOM_BOX: $USE_CUSTOM_BOX"
log "  VM_MEMORY: $VM_MEMORY"
log "  WORKER_COUNT: $WORKER_COUNT"
log "  BRIDGE_INTERFACE: $BRIDGE_INTERFACE"

# Phase 1: Pre-flight checks
log "\n=== Phase 1: Pre-flight Checks ==="

run_test "Vagrantfile syntax validation" "vagrant validate"
run_test "VirtualBox installation" "which VBoxManage"
run_test "Vagrant installation" "vagrant --version"

# Phase 2: Cluster provisioning
log "\n=== Phase 2: Cluster Provisioning ==="

log "Starting cluster provisioning (this may take 15-20 minutes)..."
if vagrant up; then
    success "Cluster provisioning completed"
else
    error "Cluster provisioning failed"
    exit 1
fi

# Phase 3: Basic connectivity tests
log "\n=== Phase 3: Basic Connectivity Tests ==="

run_test "Master VM running" "vagrant status master | grep running"
run_test "Worker1 VM running" "vagrant status worker1 | grep running"
run_test "Worker2 VM running" "vagrant status worker2 | grep running"

run_test "SSH to master" "vagrant ssh master -c 'echo SSH OK'"
run_test "SSH to worker1" "vagrant ssh worker1 -c 'echo SSH OK'"
run_test "SSH to worker2" "vagrant ssh worker2 -c 'echo SSH OK'"

# Phase 4: Kubernetes cluster tests
log "\n=== Phase 4: Kubernetes Cluster Tests ==="

run_test "kubectl available" "vagrant ssh master -c 'which kubectl'" 30
run_test "Kubernetes API server responding" "vagrant ssh master -c 'kubectl cluster-info'" 60

# Wait for nodes to be ready
log "Waiting for nodes to be ready..."
sleep 60

run_test "Master node ready" "vagrant ssh master -c 'kubectl get nodes | grep master | grep Ready'" 120
run_test "Worker nodes ready" "vagrant ssh master -c 'kubectl get nodes | grep worker | grep Ready | wc -l | grep 2'" 120

run_test "All nodes ready" "vagrant ssh master -c 'kubectl get nodes --no-headers | grep -v Ready | wc -l | grep 0'" 60

# Phase 5: System components tests
log "\n=== Phase 5: System Components Tests ==="

run_test "kube-system pods running" "vagrant ssh master -c 'kubectl get pods -n kube-system | grep Running | wc -l | awk \"\$1 >= 5\"'" 120

if [[ "$UBUNTU_VERSION" == "Ubuntu2404" ]]; then
    run_test "Calico pods running" "vagrant ssh master -c 'kubectl get pods -n calico-system | grep Running'" 120
fi

run_test "CoreDNS pods running" "vagrant ssh master -c 'kubectl get pods -n kube-system | grep coredns | grep Running'" 60

# Phase 6: Container runtime tests
log "\n=== Phase 6: Container Runtime Tests ==="

run_test "containerd running" "vagrant ssh master -c 'sudo systemctl is-active containerd'" 30
run_test "kubelet running" "vagrant ssh master -c 'sudo systemctl is-active kubelet'" 30
run_test "Docker available" "vagrant ssh master -c 'docker --version'" 30
run_test "Docker service running" "vagrant ssh master -c 'sudo systemctl is-active docker'" 30

# Phase 7: Network connectivity tests
log "\n=== Phase 7: Network Connectivity Tests ==="

run_test "Pod-to-pod communication" "vagrant ssh master -c '
    kubectl run test-pod1 --image=busybox --restart=Never --rm -it --command -- sleep 30 &
    kubectl run test-pod2 --image=busybox --restart=Never --rm -it --command -- sleep 30 &
    sleep 10
    kubectl get pods | grep test-pod | grep Running | wc -l | grep 2
'" 60

# Phase 8: Application deployment tests
log "\n=== Phase 8: Application Deployment Tests ==="

log "Deploying test application..."
vagrant ssh master -c 'kubectl create deployment nginx-test --image=nginx:latest' || true
vagrant ssh master -c 'kubectl expose deployment nginx-test --port=80 --type=NodePort' || true

sleep 30

run_test "Test app deployment" "vagrant ssh master -c 'kubectl get deployment nginx-test | grep nginx-test'" 60
run_test "Test app pods running" "vagrant ssh master -c 'kubectl get pods | grep nginx-test | grep Running'" 120
run_test "Test app service created" "vagrant ssh master -c 'kubectl get service nginx-test'" 30

# Test service accessibility
run_test "Service endpoint accessible" "vagrant ssh master -c '
    SERVICE_IP=\$(kubectl get service nginx-test -o jsonpath=\"{.spec.clusterIP}\")
    curl -s http://\$SERVICE_IP | grep \"Welcome to nginx\"
'" 60

# Phase 9: Resource utilization tests
log "\n=== Phase 9: Resource Utilization Tests ==="

run_test "Master node resources" "vagrant ssh master -c 'free -h && df -h'" 30
run_test "Worker node resources" "vagrant ssh worker1 -c 'free -h && df -h'" 30

# Cleanup test deployment
log "Cleaning up test deployment..."
vagrant ssh master -c 'kubectl delete deployment nginx-test' >/dev/null 2>&1 || true
vagrant ssh master -c 'kubectl delete service nginx-test' >/dev/null 2>&1 || true
vagrant ssh master -c 'kubectl delete pod test-pod1' >/dev/null 2>&1 || true
vagrant ssh master -c 'kubectl delete pod test-pod2' >/dev/null 2>&1 || true

# Final results
log "\n=== Test Results Summary ==="
log "Tests Passed: $TESTS_PASSED"
log "Tests Failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -gt 0 ]]; then
    error "Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "${RED}  - $test${NC}"
    done
    exit 1
else
    success "All tests passed! 🎉"
    log "Cluster is ready for use."
    
    if [[ "$CLEANUP" != "true" ]]; then
        log "\nTo access the cluster:"
        log "  vagrant ssh master"
        log "  kubectl get nodes"
        log "\nTo destroy the cluster:"
        log "  vagrant destroy -f"
    fi
fi
