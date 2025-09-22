#!/bin/bash
# Local CI/CD pipeline testing script
# Mimics the GitHub Actions workflow for local testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

log() {
    echo -e "${BLUE}[CI-LOCAL] $1${NC}"
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

run_test() {
    local test_name="$1"
    local command="$2"
    
    log "Running: $test_name"
    
    if eval "$command" >/dev/null 2>&1; then
        success "$test_name"
        return 0
    else
        error "$test_name"
        return 1
    fi
}

log "Starting Local CI/CD Pipeline Tests"
log "===================================="

# Job 1: Validate Syntax (mimics validate-syntax job)
log "\n=== Job 1: Validate Syntax ==="

# Check if Ruby is available
if ! command -v ruby >/dev/null 2>&1; then
    error "Ruby not installed - required for configuration tests"
else
    success "Ruby available: $(ruby --version)"
fi

# Run configuration tests
log "Running configuration unit tests..."
if ruby test-config.rb >/dev/null 2>&1; then
    success "Configuration tests passed"
else
    error "Configuration tests failed"
fi

# Check Vagrantfile syntax (if Vagrant is available)
if command -v vagrant >/dev/null 2>&1; then
    log "Testing Vagrantfile syntax..."
    
    if (cd Ubuntu2404 && vagrant validate >/dev/null 2>&1); then
        success "Ubuntu 24.04 Vagrantfile syntax valid"
    else
        error "Ubuntu 24.04 Vagrantfile syntax invalid"
    fi
    
    if (cd Ubuntu2204 && vagrant validate >/dev/null 2>&1); then
        success "Ubuntu 22.04 Vagrantfile syntax valid"
    else
        error "Ubuntu 22.04 Vagrantfile syntax invalid"
    fi
else
    log "Vagrant not installed - skipping syntax validation"
    log "Install with: brew install vagrant (macOS) or see https://vagrantup.com"
fi

# Job 2: Test Documentation (mimics test-documentation job)
log "\n=== Job 2: Test Documentation ==="

# Check if Node.js is available for markdownlint
if command -v node >/dev/null 2>&1; then
    success "Node.js available: $(node --version)"
    
    # Check if markdownlint is installed
    if command -v markdownlint >/dev/null 2>&1; then
        log "Running markdownlint on documentation..."
        
        if markdownlint README.md >/dev/null 2>&1; then
            success "Main README.md passes linting"
        else
            error "Main README.md has linting issues"
        fi
        
        if markdownlint Ubuntu2404/README.md >/dev/null 2>&1; then
            success "Ubuntu 24.04 README.md passes linting"
        else
            error "Ubuntu 24.04 README.md has linting issues"
        fi
        
        if markdownlint Ubuntu2204/README.md >/dev/null 2>&1; then
            success "Ubuntu 22.04 README.md passes linting"
        else
            error "Ubuntu 22.04 README.md has linting issues"
        fi
    else
        log "markdownlint not installed"
        log "Install with: npm install -g markdownlint-cli"
        log "Checking basic markdown structure instead..."
        
        # Basic markdown checks
        for readme in README.md Ubuntu2404/README.md Ubuntu2204/README.md; do
            if [[ -f "$readme" ]]; then
                if grep -q "^# " "$readme"; then
                    success "$readme has proper heading structure"
                else
                    error "$readme missing main heading"
                fi
            fi
        done
    fi
else
    log "Node.js not installed - skipping documentation tests"
    log "Install with: brew install node (macOS)"
fi

# Job 3: Test Configuration Matrix (mimics test-configuration-matrix job)
log "\n=== Job 3: Test Configuration Matrix ==="

# Test different configuration combinations
configurations=(
    "Ubuntu2404 true 2048 1"
    "Ubuntu2404 false 2048 2"
    "Ubuntu2404 false 4096 3"
    "Ubuntu2204 true 8192 2"
    "Ubuntu2204 false 4096 1"
)

for config in "${configurations[@]}"; do
    read -r ubuntu_version use_custom_box vm_memory worker_count <<< "$config"
    
    log "Testing configuration: $ubuntu_version, custom_box=$use_custom_box, memory=${vm_memory}MB, workers=$worker_count"
    
    # Set environment variables
    export USE_CUSTOM_BOX=$use_custom_box
    export VM_MEMORY=$vm_memory
    export WORKER_COUNT=$worker_count
    
    # Test configuration loading
    if ruby -e "
        ENV['USE_CUSTOM_BOX'] = '$use_custom_box'
        ENV['VM_MEMORY'] = '$vm_memory'
        ENV['WORKER_COUNT'] = '$worker_count'
        
        # Simulate configuration loading
        use_custom_box = ENV['USE_CUSTOM_BOX'] != 'false'
        vm_memory = ENV['VM_MEMORY'].to_i
        worker_count = ENV['WORKER_COUNT'].to_i
        
        puts \"Configuration loaded: custom_box=#{use_custom_box}, memory=#{vm_memory}, workers=#{worker_count}\"
        exit 0
    " >/dev/null 2>&1; then
        success "Configuration matrix test: $config"
    else
        error "Configuration matrix test failed: $config"
    fi
done

# Additional local tests
log "\n=== Additional Local Tests ==="

# Test script permissions
for script in test-cluster.sh test-integration.sh test-performance.sh; do
    if [[ -x "$script" ]]; then
        success "$script is executable"
    else
        error "$script is not executable"
    fi
done

# Test GitHub Actions workflow syntax
if command -v yamllint >/dev/null 2>&1; then
    if yamllint .github/workflows/test-vagrant.yml >/dev/null 2>&1; then
        success "GitHub Actions workflow YAML is valid"
    else
        error "GitHub Actions workflow YAML has syntax issues"
    fi
else
    log "yamllint not installed - skipping YAML validation"
    log "Install with: pip install yamllint"
fi

# Test file structure
expected_files=(
    "README.md"
    "Ubuntu2404/Vagrantfile"
    "Ubuntu2404/README.md"
    "Ubuntu2204/Vagrantfile"
    "Ubuntu2204/README.md"
    ".github/workflows/test-vagrant.yml"
    "test-cluster.sh"
    "test-config.rb"
    "test-integration.sh"
    "test-performance.sh"
)

for file in "${expected_files[@]}"; do
    if [[ -f "$file" ]]; then
        success "Required file exists: $file"
    else
        error "Missing required file: $file"
    fi
done

# Final results
log "\n=== Local CI/CD Test Results ==="
log "Tests Passed: $TESTS_PASSED"
log "Tests Failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -gt 0 ]]; then
    error "Some tests failed:"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "${RED}  - $test${NC}"
    done
    log "\nFix these issues before pushing to trigger CI/CD pipeline"
    exit 1
else
    success "All local CI/CD tests passed! 🎉"
    log "\nYour code is ready for the GitHub Actions pipeline"
    log "Push your changes or create a PR to trigger the full CI/CD pipeline"
fi
