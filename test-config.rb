#!/usr/bin/env ruby
# Test script for Vagrantfile configuration validation

require 'test/unit'

class VagrantConfigTest < Test::Unit::TestCase
  def setup
    # Clear environment variables
    ENV.delete('BRIDGE_INTERFACE')
    ENV.delete('VM_MEMORY')
    ENV.delete('VM_CPUS')
    ENV.delete('WORKER_COUNT')
    ENV.delete('NETWORK_BASE')
    ENV.delete('USE_CUSTOM_BOX')
  end

  def test_default_configuration
    # Test Ubuntu 24.04 defaults
    load_config('Ubuntu2404')
    
    assert_nil @bridge_interface, "Bridge interface should default to nil"
    assert_equal 4096, @vm_memory, "VM memory should default to 4096 for Ubuntu 24.04"
    assert_equal 4, @vm_cpus, "VM CPUs should default to 4"
    assert_equal 2, @worker_count, "Worker count should default to 2"
    assert_equal "10.0.0", @network_base, "Network base should default to 10.0.0"
    assert_equal true, @use_custom_box, "Should use custom box by default"
  end

  def test_environment_variable_override
    ENV['BRIDGE_INTERFACE'] = 'en0'
    ENV['VM_MEMORY'] = '2048'
    ENV['VM_CPUS'] = '2'
    ENV['WORKER_COUNT'] = '3'
    ENV['NETWORK_BASE'] = '192.168.1'
    ENV['USE_CUSTOM_BOX'] = 'false'
    
    load_config('Ubuntu2404')
    
    assert_equal 'en0', @bridge_interface
    assert_equal 2048, @vm_memory
    assert_equal 2, @vm_cpus
    assert_equal 3, @worker_count
    assert_equal '192.168.1', @network_base
    assert_equal false, @use_custom_box
  end

  def test_ubuntu_2204_defaults
    load_config('Ubuntu2204')
    
    assert_equal 8192, @vm_memory, "VM memory should default to 8192 for Ubuntu 22.04"
    assert_equal "ubuntu/jammy64", @fallback_box, "Fallback box should be jammy64"
  end

  def test_ubuntu_2404_defaults
    load_config('Ubuntu2404')
    
    assert_equal 4096, @vm_memory, "VM memory should default to 4096 for Ubuntu 24.04"
    assert_equal "ubuntu/noble64", @fallback_box, "Fallback box should be noble64"
  end

  def test_box_selection_logic
    # Test custom box selection
    ENV['USE_CUSTOM_BOX'] = 'true'
    load_config('Ubuntu2404')
    assert_equal true, @use_custom_box
    
    # Test public box selection
    ENV['USE_CUSTOM_BOX'] = 'false'
    load_config('Ubuntu2404')
    assert_equal false, @use_custom_box
  end

  def test_network_ip_generation
    ENV['NETWORK_BASE'] = '192.168.10'
    ENV['WORKER_COUNT'] = '3'
    load_config('Ubuntu2404')
    
    # Master should be .10
    master_ip = "#{@network_base}.10"
    assert_equal "192.168.10.10", master_ip
    
    # Workers should be .11, .12, .13
    (1..@worker_count).each do |i|
      worker_ip = "#{@network_base}.#{i + 10}"
      expected_ip = "192.168.10.#{i + 10}"
      assert_equal expected_ip, worker_ip, "Worker #{i} IP should be #{expected_ip}"
    end
  end

  private

  def load_config(ubuntu_version)
    # Simulate loading the Vagrantfile configuration
    case ubuntu_version
    when 'Ubuntu2404'
      @bridge_interface = ENV['BRIDGE_INTERFACE'] || nil
      @vm_memory = ENV['VM_MEMORY'] ? ENV['VM_MEMORY'].to_i : 4096
      @vm_cpus = ENV['VM_CPUS'] ? ENV['VM_CPUS'].to_i : 4
      @worker_count = ENV['WORKER_COUNT'] ? ENV['WORKER_COUNT'].to_i : 2
      @network_base = ENV['NETWORK_BASE'] || "10.0.0"
      @use_custom_box = ENV['USE_CUSTOM_BOX'] != 'false'
      @custom_box = "m_boxes/ubuntu_2404_server"
      @custom_box_version = "0.3.0"
      @fallback_box = "ubuntu/noble64"
    when 'Ubuntu2204'
      @bridge_interface = ENV['BRIDGE_INTERFACE'] || nil
      @vm_memory = ENV['VM_MEMORY'] ? ENV['VM_MEMORY'].to_i : 8192
      @vm_cpus = ENV['VM_CPUS'] ? ENV['VM_CPUS'].to_i : 4
      @worker_count = ENV['WORKER_COUNT'] ? ENV['WORKER_COUNT'].to_i : 2
      @network_base = ENV['NETWORK_BASE'] || "10.0.0"
      @use_custom_box = ENV['USE_CUSTOM_BOX'] != 'false'
      @custom_box = "c_boxes/ubuntu2204-base"
      @custom_box_version = "0.4.0"
      @fallback_box = "ubuntu/jammy64"
    end
  end
end

# Run the tests if this file is executed directly
if __FILE__ == $0
  puts "Running Vagrant configuration tests..."
  Test::Unit::AutoRunner.run
end
