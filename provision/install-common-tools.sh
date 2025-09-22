#!/bin/bash
# Common tools installation script for Kubernetes nodes
# This script is run on all nodes (master and workers)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[PROVISION]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

log "Starting common tools installation..."

# Disable swap and add kernel settings
log "Configuring system settings for Kubernetes..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules
log "Loading required kernel modules..."
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl settings for Kubernetes
log "Configuring sysctl settings..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Reload sysctl settings
sudo sysctl --system

# Install dependencies for container runtime
log "Installing system dependencies..."
sudo apt update
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# Add Docker's official GPG key
log "Adding Docker repository..."
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install Docker (for development use)
log "Installing Docker CE..."
sudo apt-get install -y docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin

# Add vagrant user to docker group for rootless Docker
log "Configuring Docker permissions..."
sudo groupadd docker || true  # Don't fail if group already exists
sudo usermod -aG docker vagrant

# Install containerd (for Kubernetes)
log "Installing containerd..."
sudo apt update
sudo apt install -y containerd

# Configure containerd to use systemd as the cgroup driver
log "Configuring containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Restart and enable containerd
log "Starting containerd service..."
sudo systemctl restart containerd
sudo systemctl enable containerd

# Add Kubernetes repository
log "Adding Kubernetes repository..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update

# Install Kubernetes components
log "Installing Kubernetes components..."
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

log "Common tools installation completed successfully!"
log "Installed components:"
log "  - Docker CE (for development)"
log "  - containerd (for Kubernetes)"
log "  - kubelet, kubeadm, kubectl (v1.30)"
log "  - System configured for Kubernetes"
