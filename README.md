# Vagrant Kubernetes Examples

This repository contains Vagrant configurations to spin up local Kubernetes clusters for development and testing.

## Available Configurations

- **Ubuntu2204/**: Ubuntu 22.04 LTS based cluster with Kubernetes 1.26
- **Ubuntu2404/**: Ubuntu 24.04 LTS based cluster with Kubernetes 1.30 (recommended)

## Prerequisites

- [Vagrant](https://www.vagrantup.com/) (latest version)
- [VirtualBox](https://www.virtualbox.org/) (6.1+ or 7.0+)
- At least 8GB RAM available for VMs
- At least 20GB free disk space

## Quick Start

1. Choose your Ubuntu version (24.04 recommended):

   ```bash
   cd Ubuntu2404  # or Ubuntu2204
   ```

2. **macOS Users**: The bridge interface needs to be configured. Either:
   - Let Vagrant prompt you interactively: `vagrant up`
   - Set the interface explicitly: `BRIDGE_INTERFACE=en0 vagrant up`

3. Start the cluster:

   ```bash
   vagrant up
   ```

4. SSH into the master node:

   ```bash
   vagrant ssh master
   ```

5. Verify the cluster:

   ```bash
   kubectl get nodes
   ```

## Configuration Options

Both Vagrantfiles support environment variables for customization:

| Variable | Default | Description |
|----------|---------|-------------|
| `BRIDGE_INTERFACE` | `nil` | Network bridge interface (e.g., `en0` on macOS, `eth0` on Linux) |
| `VM_MEMORY` | `4096` (24.04) / `8192` (22.04) | Memory per VM in MB |
| `VM_CPUS` | `4` | CPU cores per VM |
| `WORKER_COUNT` | `2` | Number of worker nodes |
| `NETWORK_BASE` | `10.0.0` | Private network base (nodes get .10, .11, .12, etc.) |
| `USE_CUSTOM_BOX` | `true` | Use custom boxes or fallback to public Ubuntu boxes |

### Examples

```bash
# Use different network interface and more workers
BRIDGE_INTERFACE=en1 WORKER_COUNT=3 vagrant up

# Reduce memory usage for smaller machines
VM_MEMORY=2048 vagrant up

# Use different private network range
NETWORK_BASE=192.168.10 vagrant up

# Use public Ubuntu boxes instead of custom boxes
USE_CUSTOM_BOX=false vagrant up
```

## Platform-Specific Notes

### macOS

- Bridge interface is typically `en0` or `en1`
- On Apple Silicon Macs, VirtualBox may have limitations
- Consider using UTM or Parallels as alternatives

### Linux

- Bridge interface is typically `eth0`, `eno1`, or `enp0s3`
- Ensure your user is in the `vboxusers` group

### Windows

- Bridge interface varies by network adapter
- Run PowerShell/CMD as Administrator for best results

## Network Configuration

The cluster uses:

- **Public Network**: Bridged to your host interface for external access
- **Private Network**: Host-only network for inter-node communication
- **Port Forwarding**: Master node port 8080 → host port 8080

### VirtualBox Host-Only Network Setup

VirtualBox restricts host-only networks to specific ranges. Add this to `/etc/vbox/networks.conf`:

```text
* 10.0.0.0/8 192.168.0.0/16
* 2001::/64
```

## What Gets Installed

### Both Versions

- containerd (container runtime)
- kubelet, kubeadm, kubectl
- Docker CE (for development)
- Calico CNI (Ubuntu 24.04 auto-installs, Ubuntu 22.04 requires manual setup)

### Ubuntu 24.04 Additional Features

- k8sgpt integration ready
- Kubescape security scanning
- ArgoCD installation instructions
- Metrics Server manifest included

## Troubleshooting

### Common Issues

#### Bridge Interface Error

```text
The specified host network collides with a non-hostonly network!
```

Solution: Set `BRIDGE_INTERFACE` to your correct interface name.

#### Memory Issues

```text
VBoxManage: error: Not enough physical memory is available
```

Solution: Reduce `VM_MEMORY` or increase available RAM.

#### Custom Box Not Found

```text
Box 'm_boxes/ubuntu_2404_server' could not be found
```

Solution: Use public Ubuntu boxes instead:

```bash
USE_CUSTOM_BOX=false vagrant up
```

This will use `ubuntu/noble64` (24.04) or `ubuntu/jammy64` (22.04) instead.

### Getting Help

1. Check the specific Ubuntu version README in the subdirectory
2. Verify your VirtualBox and Vagrant versions
3. Ensure sufficient system resources
4. Check VirtualBox host-only network configuration

## Security Notes

- These configurations are designed for **local development only**
- Metrics Server uses insecure TLS settings for simplicity
- Default passwords and tokens are used
- **Do not use in production environments**

## Testing

### Quick Test

To quickly validate your setup works:

```bash
# Test Ubuntu 24.04 with public boxes
./test-cluster.sh Ubuntu2404 public-box

# Test Ubuntu 22.04 with default settings
./test-cluster.sh Ubuntu2204 default
```

### Comprehensive Integration Test

For thorough testing of all cluster functionality:

```bash
# Run full integration test (takes 20-30 minutes)
./test-integration.sh Ubuntu2404

# Keep cluster running after tests for manual inspection
./test-integration.sh Ubuntu2404 false
```

### Performance Testing

To test cluster performance and resource usage:

```bash
./test-performance.sh Ubuntu2404
```

### Configuration Testing

To test Vagrantfile configuration logic:

```bash
ruby test-config.rb
```

### Manual Testing Steps

1. **Basic Functionality**:
   ```bash
   cd Ubuntu2404
   USE_CUSTOM_BOX=false vagrant up
   vagrant ssh master
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

2. **Deploy Test Application**:
   ```bash
   kubectl create deployment nginx --image=nginx
   kubectl expose deployment nginx --port=80 --type=NodePort
   kubectl get services
   ```

3. **Test Inter-node Communication**:
   ```bash
   kubectl run test-pod --image=busybox --rm -it -- /bin/sh
   # Inside pod: nslookup kubernetes.default
   ```

4. **Cleanup**:
   ```bash
   exit  # from SSH
   vagrant destroy -f
   ```

## Contributing

See `.github/pull_request_template.md` for contribution guidelines.

### Running Tests Before Contributing

Before submitting a PR, run:

```bash
# Validate syntax
vagrant validate

# Run configuration tests
ruby test-config.rb

# Run integration tests
./test-integration.sh Ubuntu2404
./test-integration.sh Ubuntu2204
```
