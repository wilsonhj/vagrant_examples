#!/bin/bash
# Performance and load testing for Vagrant Kubernetes cluster

set -e

UBUNTU_VERSION=${1:-"Ubuntu2404"}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

cd "$UBUNTU_VERSION" || exit 1

log "Starting performance tests for $UBUNTU_VERSION"
log "=============================================="

# Test 1: Cluster startup time
log "Test 1: Measuring cluster startup time"
start_time=$(date +%s)

vagrant up

end_time=$(date +%s)
startup_time=$((end_time - start_time))

log "Cluster startup time: ${startup_time} seconds"

# Test 2: Resource utilization
log "Test 2: Checking resource utilization"

vagrant ssh master -c '
echo "=== Master Node Resources ==="
echo "Memory usage:"
free -h
echo ""
echo "CPU usage:"
top -bn1 | grep "Cpu(s)"
echo ""
echo "Disk usage:"
df -h
echo ""
echo "Running processes:"
ps aux | grep -E "(kube|docker|containerd)" | wc -l
'

vagrant ssh worker1 -c '
echo "=== Worker1 Node Resources ==="
echo "Memory usage:"
free -h
echo ""
echo "CPU usage:"
top -bn1 | grep "Cpu(s)"
echo ""
echo "Disk usage:"
df -h
'

# Test 3: Pod scheduling performance
log "Test 3: Testing pod scheduling performance"

vagrant ssh master -c '
echo "Creating 10 nginx pods to test scheduling..."
kubectl create deployment nginx-perf --image=nginx:latest --replicas=10

echo "Waiting for pods to be scheduled..."
kubectl wait --for=condition=available --timeout=300s deployment/nginx-perf

echo "Pod distribution across nodes:"
kubectl get pods -o wide | grep nginx-perf | awk "{print \$7}" | sort | uniq -c

echo "Cleanup..."
kubectl delete deployment nginx-perf
'

# Test 4: Network performance
log "Test 4: Testing network performance between nodes"

vagrant ssh master -c '
echo "Testing network latency between nodes..."

# Get worker node IPs
WORKER1_IP=$(kubectl get nodes -o wide | grep worker1 | awk "{print \$6}")
WORKER2_IP=$(kubectl get nodes -o wide | grep worker2 | awk "{print \$6}")

echo "Pinging worker1 ($WORKER1_IP):"
ping -c 5 $WORKER1_IP

echo "Pinging worker2 ($WORKER2_IP):"
ping -c 5 $WORKER2_IP
'

# Test 5: Storage performance
log "Test 5: Testing storage performance"

vagrant ssh master -c '
echo "Testing disk I/O performance..."
echo "Write test:"
dd if=/dev/zero of=/tmp/testfile bs=1M count=100 2>&1 | grep copied

echo "Read test:"
dd if=/tmp/testfile of=/dev/null bs=1M 2>&1 | grep copied

rm -f /tmp/testfile
'

# Test 6: API server performance
log "Test 6: Testing Kubernetes API server performance"

vagrant ssh master -c '
echo "Testing API server response times..."

for i in {1..10}; do
    start=$(date +%s%N)
    kubectl get nodes >/dev/null
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))
    echo "API call $i: ${duration}ms"
done
'

log "Performance tests completed!"
log "To destroy the test cluster: vagrant destroy -f"
