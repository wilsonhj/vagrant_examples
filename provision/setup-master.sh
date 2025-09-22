#!/bin/bash
# Kubernetes master node setup script
# This script initializes the Kubernetes cluster and installs CNI

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[MASTER]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration - these will be interpolated by Vagrant
NETWORK_BASE=${NETWORK_BASE:-"10.0.0"}
POD_NETWORK_CIDR=${POD_NETWORK_CIDR:-"192.168.0.0/16"}
MASTER_IP="${NETWORK_BASE}.10"

log "Starting Kubernetes master node setup..."
log "Master IP: $MASTER_IP"
log "Pod Network CIDR: $POD_NETWORK_CIDR"

# Prepare join script output file
OUTPUT_FILE=/vagrant/join.sh
rm -rf $OUTPUT_FILE

# Initialize Kubernetes cluster
log "Initializing Kubernetes cluster..."
if sudo kubeadm init \
    --apiserver-advertise-address=$MASTER_IP \
    --pod-network-cidr=$POD_NETWORK_CIDR | \
    grep -E -- "kubeadm join|--discovery-token-ca-cert-hash" > ${OUTPUT_FILE}; then
    log "Kubernetes cluster initialized successfully"
else
    error "Failed to initialize Kubernetes cluster"
fi

chmod +x $OUTPUT_FILE
log "Worker join script created at $OUTPUT_FILE"

# Configure kubectl for vagrant user
log "Configuring kubectl access..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Configure kubelet to use the correct node IP
log "Configuring kubelet node IP..."
sudo rm -f /etc/default/kubelet
sudo touch /etc/default/kubelet
echo "KUBELET_EXTRA_ARGS=--node-ip=$MASTER_IP" | sudo tee -a /etc/default/kubelet

# Restart kubelet with new configuration
log "Restarting kubelet..."
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Wait for API server to be ready
log "Waiting for Kubernetes API server to be ready..."
timeout=60
while ! kubectl cluster-info >/dev/null 2>&1; do
    if [ $timeout -le 0 ]; then
        error "Kubernetes API server failed to start within 60 seconds"
    fi
    sleep 2
    ((timeout-=2))
done

log "Kubernetes API server is ready"

# Install Calico CNI
log "Installing Calico CNI..."
if kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/tigera-operator.yaml; then
    log "Calico operator installed"
else
    warning "Calico operator installation failed or already exists"
fi

if kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/custom-resources.yaml; then
    log "Calico custom resources installed"
else
    warning "Calico custom resources installation failed or already exists"
fi

# Wait for Calico to be ready
log "Waiting for Calico pods to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n calico-system --timeout=300s || warning "Calico pods may still be starting"

# Display cluster status
log "Kubernetes master setup completed!"
log "Cluster information:"
kubectl cluster-info

log "Node status:"
kubectl get nodes

log "System pods status:"
kubectl get pods -n kube-system

log "Calico pods status:"
kubectl get pods -n calico-system

log "Master node setup completed successfully!"
log "Workers can now join using: vagrant ssh worker1 (etc.)"

# Optional components (commented out by default)
# Uncomment and customize as needed

# Alternative CNI: Flannel (uncomment to use instead of Calico)
# log "Installing Flannel CNI..."
# wget https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
# sed -i 's/10.244/192.168/g' kube-flannel.yml
# kubectl apply -f kube-flannel.yml

# MetalLB Load Balancer (uncomment to enable)
# log "Installing MetalLB..."
# kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
# 
# # Configure MetalLB IP pool
# kubectl apply -f - <<EOF
# apiVersion: metallb.io/v1beta1
# kind: IPAddressPool
# metadata:
#   name: first-pool
#   namespace: metallb-system
# spec:
#   addresses:
#   - ${NETWORK_BASE}.20-${NETWORK_BASE}.30
# ---
# apiVersion: metallb.io/v1beta1
# kind: L2Advertisement
# metadata:
#   name: example
#   namespace: metallb-system
# EOF

# kube-proxy configuration for MetalLB (uncomment if using MetalLB)
# log "Configuring kube-proxy for MetalLB..."
# kubectl get configmap kube-proxy -n kube-system -o yaml | \
# sed -e "s/mode: \"\"/mode: \"ipvs\"/" | \
# kubectl apply -f - -n kube-system
# 
# kubectl get configmap kube-proxy -n kube-system -o yaml | \
# sed -e "s/strictARP: false/strictARP: true/" | \
# kubectl apply -f - -n kube-system
