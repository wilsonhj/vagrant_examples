# Provisioning Scripts

This directory contains the provisioning scripts used by the Vagrant Kubernetes setup.

## Scripts

### `install-common-tools.sh`
**Purpose**: Installs common tools and dependencies on all nodes (master and workers)

**What it does**:
- Disables swap and configures kernel settings for Kubernetes
- Installs Docker CE for development use
- Installs containerd as the Kubernetes container runtime
- Configures containerd with systemd cgroup driver
- Adds Kubernetes repository and installs kubelet, kubeadm, kubectl (v1.30)
- Configures Docker permissions for the vagrant user

**Usage**: Automatically called by Vagrant during VM provisioning

### `setup-master.sh`
**Purpose**: Initializes the Kubernetes cluster on the master node

**What it does**:
- Initializes Kubernetes cluster with kubeadm
- Generates worker join script (`/vagrant/join.sh`)
- Configures kubectl access for the vagrant user
- Configures kubelet with correct node IP
- Installs Calico CNI for pod networking
- Provides status information and optional components

**Environment Variables**:
- `NETWORK_BASE`: Base IP for the private network (e.g., "10.0.0")
- `POD_NETWORK_CIDR`: CIDR for pod networking (default: "192.168.0.0/16")

**Usage**: Automatically called by Vagrant on the master node

## Features

### Error Handling
- Scripts use `set -e` to exit on any error
- Comprehensive error checking and logging
- Colored output for better visibility

### Logging
- Structured logging with timestamps and prefixes
- Different log levels (info, warning, error)
- Progress indicators for long-running operations

### Flexibility
- Environment variable configuration
- Optional components (commented out by default)
- Support for alternative CNI providers

### Optional Components
Both scripts include commented sections for:
- **Flannel CNI**: Alternative to Calico
- **MetalLB**: Load balancer for bare metal
- **kube-proxy configuration**: For MetalLB compatibility

## Customization

### Adding Custom Components
To add custom components, edit the scripts directly:

```bash
# Add to install-common-tools.sh for all nodes
log "Installing custom component..."
sudo apt install -y my-custom-package

# Add to setup-master.sh for master-only components
log "Installing master-only component..."
kubectl apply -f https://example.com/my-component.yaml
```

### Environment Variables
Scripts support these environment variables:
- `NETWORK_BASE`: Network base IP (set by Vagrant)
- `POD_NETWORK_CIDR`: Pod network CIDR
- `CALICO_VERSION`: Calico version to install

### Alternative CNI
To use Flannel instead of Calico:

1. Comment out Calico installation in `setup-master.sh`
2. Uncomment Flannel installation section
3. Adjust pod network CIDR if needed

## Testing

### Script Testing
```bash
# Test script syntax
bash -n provision/install-common-tools.sh
bash -n provision/setup-master.sh

# Test with shellcheck (if installed)
shellcheck provision/*.sh
```

### Integration Testing
The scripts are tested as part of the full integration test suite:
```bash
./test-integration.sh Ubuntu2404
```

## Troubleshooting

### Common Issues

**Script fails with permission errors**:
- Ensure scripts are executable: `chmod +x provision/*.sh`
- Check Vagrant has access to provision directory

**Network connectivity issues**:
- Verify internet connectivity from VMs
- Check firewall settings on host system

**Kubernetes initialization fails**:
- Check system resources (memory, CPU)
- Verify container runtime is running: `sudo systemctl status containerd`

### Debug Mode
To enable debug output, modify scripts to add:
```bash
set -x  # Enable debug output
```

## Version Compatibility

| Ubuntu Version | Kubernetes | Docker CE | Calico |
|---------------|------------|-----------|---------|
| 22.04 LTS     | v1.30      | Latest    | v3.29.2 |
| 24.04 LTS     | v1.30      | Latest    | v3.29.2 |

## Contributing

When modifying scripts:
1. Test on both Ubuntu versions
2. Update this README if adding new features
3. Follow existing logging and error handling patterns
4. Add comments for complex operations
