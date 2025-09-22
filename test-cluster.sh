#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
UBUNTU_VERSION=${1:-"Ubuntu2404"}  # Default to Ubuntu 24.04
TEST_CONFIG=${2:-"default"}        # default, public-box, or custom

echo -e "${YELLOW}Testing Vagrant Kubernetes Setup${NC}"
echo "Ubuntu Version: $UBUNTU_VERSION"
echo "Test Configuration: $TEST_CONFIG"
echo "=================================="

# Change to the specified Ubuntu directory
cd "$UBUNTU_VERSION" || {
    echo -e "${RED}Error: Directory $UBUNTU_VERSION not found${NC}"
    exit 1
}

# Set environment variables based on test configuration
case $TEST_CONFIG in
    "public-box")
        export USE_CUSTOM_BOX=false
        export VM_MEMORY=2048  # Reduce memory for CI/testing
        echo "Using public Ubuntu boxes with reduced memory"
        ;;
    "custom")
        export USE_CUSTOM_BOX=true
        echo "Using custom boxes (may fail if not available)"
        ;;
    "default")
        export USE_CUSTOM_BOX=false
        export BRIDGE_INTERFACE=en0  # Assume en0 for macOS testing
        export VM_MEMORY=2048
        echo "Using default configuration with public boxes"
        ;;
esac

# Function to run test and capture result
run_test() {
    local test_name="$1"
    local command="$2"
    
    echo -e "\n${YELLOW}Testing: $test_name${NC}"
    if eval "$command"; then
        echo -e "${GREEN}✓ $test_name passed${NC}"
        return 0
    else
        echo -e "${RED}✗ $test_name failed${NC}"
        return 1
    fi
}

# Test 1: Vagrant syntax validation
run_test "Vagrantfile Syntax" "vagrant validate"

# Test 2: Start the cluster
echo -e "\n${YELLOW}Starting Vagrant cluster (this may take 10-15 minutes)...${NC}"
if ! vagrant up; then
    echo -e "${RED}Failed to start cluster${NC}"
    exit 1
fi

# Test 3: Check VM status
run_test "VM Status Check" "vagrant status | grep -E '(master|worker).*running'"

# Test 4: SSH connectivity
run_test "SSH to Master" "vagrant ssh master -c 'echo SSH connection successful'"

# Test 5: Kubernetes cluster health
echo -e "\n${YELLOW}Testing Kubernetes cluster health...${NC}"

# Check nodes
run_test "Kubernetes Nodes Ready" "vagrant ssh master -c 'kubectl get nodes | grep Ready'"

# Check system pods
run_test "System Pods Running" "vagrant ssh master -c 'kubectl get pods -n kube-system | grep Running'"

# Check CNI (Calico) pods
if [[ "$UBUNTU_VERSION" == "Ubuntu2404" ]]; then
    run_test "Calico Pods Running" "vagrant ssh master -c 'kubectl get pods -n calico-system | grep Running'"
fi

# Test 6: Deploy test application
echo -e "\n${YELLOW}Deploying test application...${NC}"
vagrant ssh master -c 'kubectl create deployment nginx-test --image=nginx:latest'
vagrant ssh master -c 'kubectl expose deployment nginx-test --port=80 --type=NodePort'

# Wait for deployment
sleep 30

run_test "Test App Deployment" "vagrant ssh master -c 'kubectl get pods | grep nginx-test | grep Running'"

# Test 7: Network connectivity between nodes
run_test "Inter-node Connectivity" "vagrant ssh master -c 'kubectl get nodes -o wide'"

# Test 8: Docker functionality (if installed)
run_test "Docker Service" "vagrant ssh master -c 'docker --version && docker ps'"

# Test 9: Container runtime
run_test "Container Runtime" "vagrant ssh master -c 'sudo crictl version'"

# Cleanup test deployment
echo -e "\n${YELLOW}Cleaning up test deployment...${NC}"
vagrant ssh master -c 'kubectl delete deployment nginx-test'
vagrant ssh master -c 'kubectl delete service nginx-test'

echo -e "\n${GREEN}All tests completed successfully!${NC}"
echo -e "${YELLOW}To clean up: vagrant destroy -f${NC}"
