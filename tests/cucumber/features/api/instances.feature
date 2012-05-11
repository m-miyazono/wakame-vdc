@api_from_v11.12
Feature: Instance API

  @api_until_v11.12
  Scenario: Create and delete new instance (volume store)
    # Security groups is an array?...
    Given a managed instance with the following options
      | image_id   | instance_spec_id | ssh_key_id | security_groups | ha_enabled | network_scheduler |
      | wmi-lucid6 | is-demo2         | ssh-demo   | sg-demofgr      | false      | vif3type1         |
    Then from the previous api call take {"id":} and save it to <registry:id>

    When the created instance has reached the state "running"
    
    When we make an api delete call to instances/<registry:id> with no options
      Then the previous api call should be successful  

  @api_until_v11.12
  Scenario: Create and delete new instance (local store)
    # Security groups is an array?...
    Given a managed instance with the following options
      | image_id   | instance_spec_id | ssh_key_id | security_groups | ha_enabled | network_scheduler |
      | wmi-lucid7 | is-demo2         | ssh-demo   | sg-demofgr      | false      | vif3type1         |
    Then from the previous api call take {"id":} and save it to <registry:id>

    When the created instance has reached the state "running"
    
    When we make an api delete call to instances/<registry:id> with no options
      Then the previous api call should be successful  

  @api_from_v12.03
  Scenario: Create and delete new kvm instance
    # Security groups is an array?...
    Given a managed instance with the following json document:
     """
      {"image_id": "wmi-lucid6",
       "ssh_key_id": "ssh-demo",
       "cpu_cores": 1,
       "memory_size": 256,
       "hypervisor": "kvm",
       "arch": "x86_64",
       "uuid": "i-testinstance1",
       "drive": [
         {"device":"ide", "size":300, "storage_id": "stor-uxuxuxu", "description": "ephemeral1"},
         {"uuid":"testiephe", "backup_object_id":"snap-demo1", "description": "ephemeral2"},
       ],
       "vif": [
         {"ipv4_addr": "192.168.1.5", "device":"virtio", "macaddr": "00:10:ab:ab:ab:ab", "network_id": "nw-demo1"},
         {"network_id": "nw-demo2"},
       ]
      }
     """
    Then from the previous api call take {"id":} and save it to <registry:id>
    
    When the created instance has reached the state "running"
    
    When we make an api delete call to instances/<registry:id> with no options
      Then the previous api call should be successful  
