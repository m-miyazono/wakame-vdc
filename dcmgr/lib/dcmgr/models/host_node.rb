# -*- coding: utf-8 -*-

require 'isono/models/node_state'

module Dcmgr::Models
  class HostNode < AccountResource
    taggable 'hp'
    with_timestamps

    HYPERVISOR_XEN_34='xen-3.4'
    HYPERVISOR_XEN_40='xen-4.0'
    HYPERVISOR_KVM='kvm'
    HYPERVISOR_LXC='lxc'

    ARCH_X86=:x86.to_s
    ARCH_X86_64=:x86_64.to_s

    SUPPORTED_ARCH=[ARCH_X86, ARCH_X86_64]
    SUPPORTED_HYPERVISOR=[HYPERVISOR_KVM, HYPERVISOR_LXC]

    inheritable_schema do
      String :node_id, :size=>80, :null=>true
      
      String :arch, :size=>10, :null=>false # :x86, :x86_64
      String :hypervisor, :size=>30, :null=>false

      Fixnum :offering_cpu_cores,   :null=>false, :unsigned=>true
      Fixnum :offering_memory_size, :null=>false, :unsigned=>true

      index :node_id
    end
    
    one_to_many :instances
    many_to_one :node, :class=>Isono::Models::NodeState, :key=>:node_id, :primary_key=>:node_id

    def_dataset_method(:online_nodes) do
      # SELECT * FROM `host_nodes` WHERE ('node_id' IN (SELECT `node_id` FROM `node_states` WHERE (`state` = 'online')))
      r = Isono::Models::NodeState.filter(:state => 'online').select(:node_id)
      filter(:node_id => r)
    end

    def after_initialize
      super
    end

    def validate
      super
      # for compatibility: hva.xxx or hva-xxxx
      unless self.node_id =~ /^hva[-.]/
        errors.add(:node_id, "is invalid ID: #{self.node_id}")
      end

      if (h = self.class.filter(:node_id=>self.node_id).first) && h.id != self.id
        errors.add(:node_id, " #{self.node_id} is already been associated to #{h.canonical_uuid} ")
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

    # Check if the resources exist depending on the HostNode.
    # @return [boolean] 
    def depend_resources?
      !self.instances_dataset.runnings.empty?
    end
    
    def status
      node.nil? ? :offline : node.state
    end

    # Returns true/false if the host pool has enough capacity to run the spec.
    # @param [InstanceSpec] spec 
    def check_capacity(spec)
      raise TypeError unless spec.is_a?(InstanceSpec)
      inst_on_hp = self.instances_dataset.lives.all

      (self.offering_cpu_cores >= inst_on_hp.inject(0) {|t, i| t += i.cpu_cores } + spec.cpu_cores) &&
        (self.offering_memory_size >= inst_on_hp.inject(0) {|t, i| t += i.memory_size } + spec.memory_size)
    end
    
    def to_api_document
      h = super()
      h.merge!(:status=>self.status)
      h.delete(:node_id)
      h
    end

    # Returns reserved CPU cores used by running/scheduled instances.
    def cpu_core_usage
      instances_usage(:cpu_cores)
    end

    # Returns reserved memory size used by running/scheduled instances.
    def memory_size_usage
      instances_usage(:memory_size)
    end

    # Returns available CPU cores.
    def available_cpu_cores
      self.offering_cpu_cores - self.cpu_core_usage
    end

    # Returns available memory size.
    def available_memory_size
      self.offering_memory_size - self.memory_size_usage
    end

    protected
    def instances_usage(colname)
      instances_dataset.lives.sum(colname).to_i
    end
  end
end
