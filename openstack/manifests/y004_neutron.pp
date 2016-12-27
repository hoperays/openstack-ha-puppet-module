class openstack::y004_neutron (
  $bootstrap_node   = 'controller-1',
  $neutron_password = 'neutron1234',
  $nova_password    = 'nova1234',
  $allowed_hosts    = ['%'],
  $cluster_nodes    = ['controller-1', 'controller-2', 'controller-3'],
  $host             = 'controller-vip',
  $rbd_secret_uuid  = '2ad6a20f-ffdd-460d-afba-04ab286f365f',) {
  if $::hostname == $bootstrap_node {
    $sync_db = true
  } else {
    $sync_db = false
  }

  class { '::neutron':
    host                    => $::hostname,
    bind_host               => $::hostname,
    auth_strategy           => 'keystone',
    #
    notification_driver     => 'neutron.openstack.common.notifier.rpc_notifier',
    rabbit_user             => 'guest',
    rabbit_password         => 'guest',
    rabbit_hosts            => $cluster_nodes,
    rabbit_ha_queues        => true,
    #
    core_plugin             => 'neutron.plugins.ml2.plugin.Ml2Plugin',
    service_plugins         => ['router', 'firewall', 'neutron_lbaas.services.loadbalancer.plugin.LoadBalancerPluginv2', 'vpnaas'],
    #
    dhcp_agents_per_network => '2',
  }

  class { '::neutron::keystone::authtoken':
    auth_uri            => "http://${host}:5000/",
    auth_url            => "http://${host}:35357/",
    memcached_servers   => $cluster_nodes,
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    region_name         => 'RegionOne',
    project_name        => 'service',
    username            => 'neutron',
    password            => $neutron_password,
  }

  class { '::neutron::server':
    database_connection      => "mysql+pymysql://neutron:${neutron_password}@${host}/neutron",
    database_max_retries     => '-1',
    service_providers        => [
      'LOADBALANCERV2:Octavia:neutron_lbaas.drivers.octavia.driver.OctaviaDriver:default',
      'VPN:openswan:neutron_vpnaas.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default'],
    auth_strategy            => false,
    #
    router_scheduler_driver  => 'neutron.scheduler.l3_agent_scheduler.ChanceScheduler',
    #
    api_workers              => '2',
    rpc_workers              => '2',
    l3_ha                    => true,
    min_l3_agents_per_router => '2',
    max_l3_agents_per_router => '2',
    #
    sync_db                  => $sync_db,
    #
    manage_service           => false,
    enabled                  => false,
  }

  class { '::neutron::server::notifications':
    auth_url          => "http://${host}:35357/",
    auth_type         => 'password',
    project_domain_id => 'default',
    user_domain_id    => 'default',
    region_name       => 'RegionOne',
    project_name      => 'service',
    username          => 'nova',
    password          => $nova_password,
    #
    notify_nova_on_port_status_changes => true,
    notify_nova_on_port_data_changes   => true,
  }

  class { '::neutron::plugins::ml2':
    type_drivers          => ['local', 'flat', 'vlan', 'gre', 'vxlan'],
    tenant_network_types  => ['vlan', 'vxlan'],
    mechanism_drivers     => ['openvswitch'],
    flat_networks         => '*',
    network_vlan_ranges   => 'physnet1:1000:1099',
    tunnel_id_ranges      => undef,
    vxlan_group           => '224.0.0.1',
    vni_ranges            => '100:199',
    enable_security_group => true,
    firewall_driver       => 'neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver',
  }

  class { '::neutron::services::fwaas':
    enabled => true,
    driver  => 'openvswitch',
  }

  class { '::neutron::services::lbaas':
  }

  class { '::neutron::services::vpnaas':
  }

  class { '::neutron::agents::ml2::ovs':
    tunnel_types       => ['vxlan'],
    vxlan_udp_port     => '4789',
    local_ip           => $::ipaddress_eth3,
    integration_bridge => 'br-int',
    tunnel_bridge      => 'br-tun',
    bridge_mappings    => ['physnet1:br-eth2', 'extnet:br-ex'],
    firewall_driver    => 'neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver',
    l2_population      => false,
    #
    manage_service     => false,
    enabled            => false,
  }

  class { '::neutron::agents::metadata':
    shared_secret     => 'metadata1234',
    metadata_ip       => $host,
    metadata_port     => '8775',
    metadata_protocol => 'http',
    metadata_workers  => '4',
    metadata_backlog  => '4096',
    #
    manage_service    => false,
    enabled           => false,
  }

  class { '::neutron::agents::dhcp':
    resync_interval          => '30',
    interface_driver         => 'neutron.agent.linux.interface.OVSInterfaceDriver',
    dhcp_driver              => 'neutron.agent.linux.dhcp.Dnsmasq',
    root_helper              => 'sudo neutron-rootwrap /etc/neutron/rootwrap.conf',
    dnsmasq_config_file      => '/etc/neutron/dnsmasq-neutron.conf',
    enable_force_metadata    => true,
    enable_isolated_metadata => true,
    enable_metadata_network  => true,
    #
    manage_service           => false,
    enabled                  => false,
  }

  class { '::neutron::agents::l3':
    interface_driver => 'neutron.agent.linux.interface.OVSInterfaceDriver',
    handle_internal_only_routers => false,
    send_arp_for_ha  => '3',
    #
    manage_service   => false,
    enabled          => false,
  }

  class { '::neutron::agents::vpnaas':
    vpn_device_driver           => 'neutron.services.vpn.device_drivers.ipsec.OpenSwanDriver',
    interface_driver            => 'neutron.agent.linux.interface.OVSInterfaceDriver',
    ipsec_status_check_interval => '30',
    #
    manage_service              => false,
    enabled                     => false,
  }

  file { '/etc/neutron/dnsmasq-neutron.conf':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'neutron',
    content => "dhcp-option-force=26,1400",
    require => Class['::neutron::agents::dhcp'],
  }

  file { '/etc/sysconfig/network-scripts/ifcfg-eth1':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "NAME=eth1
DEVICE=eth1
TYPE=OVSPort
DEVICETYPE=ovs
OVS_BRIDGE=br-ex
BOOTPROTO=none
ONBOOT=yes
",
    require => Class['::neutron::agents::ml2::ovs'],
  } ->
  file { '/etc/sysconfig/network-scripts/ifcfg-br-ex':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "NAME=br-ex
DEVICE=br-ex
DEVICETYPE=ovs
OVSBOOTPROTO=none
TYPE=OVSBridge
BOOTPROTO=none
ONBOOT=yes
",
  } ->
  file { '/etc/sysconfig/network-scripts/ifcfg-eth2':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "NAME=eth2
DEVICE=eth2
TYPE=OVSPort
DEVICETYPE=ovs
OVS_BRIDGE=br-eth2
BOOTPROTO=none
ONBOOT=yes
",
  } ->
  file { '/etc/sysconfig/network-scripts/ifcfg-br-eth2':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "NAME=br-eth2
DEVICE=br-eth2
DEVICETYPE=ovs
OVSBOOTPROTO=none
TYPE=OVSBridge
BOOTPROTO=none
ONBOOT=yes
",
  } ->
  exec { 'ovs-vsctl add-br br-ex':
    timeout   => '3600',
    tries     => '360',
    try_sleep => '10',
    command   => "/usr/bin/ovs-vsctl add-br br-ex",
    unless    => "/usr/bin/ovs-vsctl list-ports br-ex",
  } ->
  exec { 'ovs-vsctl add-port br-ex eth1':
    timeout   => '3600',
    tries     => '360',
    try_sleep => '10',
    command   => "/usr/bin/ovs-vsctl add-port br-ex eth1",
    unless    => "/usr/bin/ovs-vsctl list-ports br-ex | /usr/bin/grep eth1",
  } ->
  exec { 'ovs-vsctl add-br br-eth2':
    timeout   => '3600',
    tries     => '360',
    try_sleep => '10',
    command   => "/usr/bin/ovs-vsctl add-br br-eth2",
    unless    => "/usr/bin/ovs-vsctl list-ports br-eth2",
  } ->
  exec { 'ovs-vsctl add-port br-eth2 eth2':
    timeout   => '3600',
    tries     => '360',
    try_sleep => '10',
    command   => "/usr/bin/ovs-vsctl add-port br-eth2 eth2",
    unless    => "/usr/bin/ovs-vsctl list-ports br-eth2 | /usr/bin/grep eth2",
  }

  if $::hostname == $bootstrap_node {
    class { '::neutron::db::mysql':
      password      => $neutron_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    } ->
    keystone_service { 'neutron':
      ensure      => 'present',
      type        => 'network',
      description => 'OpenStack Networking',
    } ->
    keystone_endpoint { 'neutron':
      ensure       => 'present',
      region       => 'RegionOne',
      admin_url    => "http://${host}:9696",
      public_url   => "http://${host}:9696",
      internal_url => "http://${host}:9696",
    } ->
    keystone_user { 'neutron':
      ensure   => 'present',
      password => $neutron_password,
      # email    => 'neutron@example.org',
      domain   => 'default',
    } ->
    keystone_user_role { 'neutron::default@service::neutron':
      ensure         => 'present',
      user           => 'neutron',
      user_domain    => 'default',
      project        => 'service',
      project_domain => 'default',
      roles          => ['admin'],
    } ->
    pacemaker::resource::service { 'neutron-server': clone_params => 'interleave=true', } ->
    pacemaker::resource::ocf { 'neutron-ovs-cleanup':
      ensure         => 'present',
      ocf_agent_name => 'neutron:OVSCleanup',
      clone_params   => 'interleave=true',
    } ->
    pacemaker::constraint::base { 'order-neutron-server-clone-neutron-ovs-cleanup-clone-Mandatory':
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => 'neutron-server-clone',
      second_action     => 'start',
      second_resource   => 'neutron-ovs-cleanup-clone',
      constraint_params => 'kind=Mandatory',
    } ->
    pacemaker::constraint::colocation { 'colocation-neutron-ovs-cleanup-clone-neutron-server-clone-INFINITY':
      source => 'neutron-ovs-cleanup-clone',
      target => 'neutron-server-clone',
      score  => 'INFINITY',
    } ->
    pacemaker::resource::ocf { 'neutron-netns-cleanup':
      ensure         => 'present',
      ocf_agent_name => 'neutron:NetnsCleanup',
      clone_params   => 'interleave=true',
    } ->
    pacemaker::constraint::base { 'order-neutron-ovs-cleanup-clone-neutron-netns-cleanup-clone-Mandatory':
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => 'neutron-ovs-cleanup-clone',
      second_action     => 'start',
      second_resource   => 'neutron-netns-cleanup-clone',
      constraint_params => 'kind=Mandatory',
    } ->
    pacemaker::constraint::colocation { 'colocation-neutron-netns-cleanup-clone-neutron-ovs-cleanup-clone-INFINITY':
      source => 'neutron-netns-cleanup-clone',
      target => 'neutron-ovs-cleanup-clone',
      score  => 'INFINITY',
    } ->
    pacemaker::resource::service { 'neutron-openvswitch-agent': clone_params => 'interleave=true', } ->
    pacemaker::constraint::base { 'order-neutron-netns-cleanup-clone-neutron-openvswitch-agent-clone-Mandatory':
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => 'neutron-netns-cleanup-clone',
      second_action     => 'start',
      second_resource   => 'neutron-openvswitch-agent-clone',
      constraint_params => 'kind=Mandatory',
    } ->
    pacemaker::constraint::colocation { 'colocation-neutron-openvswitch-agent-clone-neutron-netns-cleanup-clone-INFINITY':
      source => 'neutron-openvswitch-agent-clone',
      target => 'neutron-netns-cleanup-clone',
      score  => 'INFINITY',
    } ->
    pacemaker::resource::service { 'neutron-dhcp-agent': clone_params => 'interleave=true', } ->
    pacemaker::constraint::base { 'order-neutron-openvswitch-agent-clone-neutron-dhcp-agent-clone-Mandatory':
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => 'neutron-openvswitch-agent-clone',
      second_action     => 'start',
      second_resource   => 'neutron-dhcp-agent-clone',
      constraint_params => 'kind=Mandatory',
    } ->
    pacemaker::constraint::colocation { 'colocation-neutron-dhcp-agent-clone-neutron-openvswitch-agent-clone-INFINITY':
      source => 'neutron-dhcp-agent-clone',
      target => 'neutron-openvswitch-agent-clone',
      score  => 'INFINITY',
    } ->
    pacemaker::resource::service { 'neutron-metadata-agent': clone_params => 'interleave=true', } ->
    pacemaker::constraint::base { 'order-neutron-dhcp-agent-clone-neutron-metadata-agent-clone-Mandatory':
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => 'neutron-dhcp-agent-clone',
      second_action     => 'start',
      second_resource   => 'neutron-metadata-agent-clone',
      constraint_params => 'kind=Mandatory',
    } ->
    pacemaker::constraint::colocation { 'colocation-neutron-metadata-agent-clone-neutron-dhcp-agent-clone-INFINITY':
      source => 'neutron-metadata-agent-clone',
      target => 'neutron-dhcp-agent-clone',
      score  => 'INFINITY',
    } ->
    pacemaker::resource::service { 'neutron-l3-agent': clone_params => 'interleave=true', } ->
    pacemaker::constraint::base { 'order-neutron-metadata-agent-clone-neutron-l3-agent-clone-Mandatory':
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => 'neutron-metadata-agent-clone',
      second_action     => 'start',
      second_resource   => 'neutron-l3-agent-clone',
      constraint_params => 'kind=Mandatory',
    } ->
    pacemaker::constraint::colocation { 'colocation-neutron-l3-agent-clone-neutron-metadata-agent-clone-INFINITY':
      source => 'neutron-l3-agent-clone',
      target => 'neutron-metadata-agent-clone',
      score  => 'INFINITY',
    } ->
    pacemaker::resource::service { 'neutron-vpn-agent': clone_params => 'interleave=true', } ->
    pacemaker::constraint::base { 'order-neutron-l3-agent-clone-neutron-vpn-agent-clone-Mandatory':
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => 'neutron-l3-agent-clone',
      second_action     => 'start',
      second_resource   => 'neutron-vpn-agent-clone',
      constraint_params => 'kind=Mandatory',
    } ->
    pacemaker::constraint::colocation { 'colocation-neutron-vpn-agent-clone-neutron-l3-agent-clone-INFINITY':
      source => 'neutron-vpn-agent-clone',
      target => 'neutron-l3-agent-clone',
      score  => 'INFINITY',
    } ->
    exec { 'neutron-ready':
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 network list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 network list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 network list > /dev/null 2>&1",
      unless    => "/usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 network list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 network list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 network list > /dev/null 2>&1",
    }
  }
}
