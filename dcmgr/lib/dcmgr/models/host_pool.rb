# -*- coding: utf-8 -*-

module Dcmgr::Models
  class HostPool < AccountResource
    taggable 'hp'
    with_timestamps

    HYPERVISOR_XEN_34=:'xen-3.4'
    HYPERVISOR_XEN_40=:'xen-4.0'
    HYPERVISOR_KVM=:'kvm'

    ARCH_X86=:x86.to_s
    ARCH_X86_64=:x86_64.to_s

    SUPPORTED_ARCH=[ARCH_X86, ARCH_X86_64]

    inheritable_schema do
      String :node_id, :size=>80, :null=>true
      
      String :arch, :size=>10, :null=>false # :x86, :x86_64
      String :hypervisor, :size=>30, :null=>false
      Fixnum :network_id, :null=>false

      Fixnum :offering_cpu_cores,   :null=>false, :unsigned=>true
      Fixnum :offering_memory_size, :null=>false, :unsigned=>true
      Fixnum :allow_memory_overcommit, :null=>false, :default=>1
    end
    
    one_to_many :instances
    many_to_one :node, :class=>Isono::Models::NodeState, :key=>:node_id, :primary_key=>:node_id
    many_to_one :network

    def after_initialize
      super
    end

    def validate
      super
      unless self.node_id =~ /^hva-/
        errors.add(:node_id, "hva node has to be associated: #{self.node_id}")
      end
      
      unless SUPPORTED_ARCH.member?(self.arch)
        errors.add(:arch, "unknown architecture type: #{self.arch}")
      end

      unless self.offering_cpu_cores > 0
        errors.add(:offering_cpu_cores, "it must have digit more than zero")
      end
      unless self.offering_memory_size > 0
        errors.add(:offering_memory_size, "it must have digit more than zero")
      end
    end

    def to_hash
      super.merge(:status=>self.status)
    end

    # Check if the resources exist depending on the HostPool.
    # @return [boolean] 
    def depend_resources?
      !self.instances_dataset.runnings.empty?
    end
    
    # Factory method for Instance model to run on this HostPool.
    # @param [Models::Account] account
    # @param [Models::Image] image
    # @param [Models::InstanceSpec] spec
    # @return [Models::Instance] created new Instance object.
    def create_instance(account, image, spec, &blk)
      raise ArgumentError unless image.is_a?(Image)
      raise ArgumentError unless spec.is_a?(InstanceSpec)
      i = Instance.new &blk
      i.account_id = account.canonical_uuid
      i.image = image
      i.instance_spec = spec
      i.host_pool = self
      i.save

      # TODO: set vnic spec from InstanceSpec
      vnic = i.add_nic
      IpLease.lease(vnic)
      i
    end

    def status
      node.nil? ? :offline : node.state
    end

    # Returns true/false if the host pool has enough capacity to run the spec.
    # @param [InstanceSpec] spec 
    def check_capacity(spec)
      raise TypeError unless spec.is_a?(InstanceSpec)
      inst_on_hp = self.instances_dataset.lives.all

      (self.offering_cpu_cores > inst_on_hp.inject(0) {|t, i| t += i.spec.cpu_cores } + spec.cpu_cores) &&
        (self.offering_memory_size > inst_on_hp.inject(0) {|t, i| t += i.spec.memory_size } + spec.memory_size)
    end
    
    
  end
end