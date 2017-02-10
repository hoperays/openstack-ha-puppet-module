class openstack::y004_neutron (
  $bootstrap_node   = 'controller-1',
  $neutron_password = 'neutron1234',
  $nova_password    = 'nova1234',
  $allowed_hosts    = ['%'],
  $controller_vip   = '192.168.0.130',
  $controller_1     = '192.168.0.131',
  $controller_2     = '192.168.0.132',
  $controller_3     = '192.168.0.133',
  $metadata_secret  = 'metadata1234',) {
  if $::hostname == $bootstrap_node {
    class { '::neutron::db::mysql':
      password      => $neutron_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    $sync_db = true
  } else {
    $sync_db = false
  }

  class { '::neutron':
    bind_host               => $::ipaddress_eth0,
    auth_strategy           => 'keystone',
    core_plugin             => 'neutron.plugins.ml2.plugin.Ml2Plugin',
    service_plugins         => [
      'router',
      'qos',
      'trunk',
      'firewall',
      'vpnaas',
      'neutron_lbaas.services.loadbalancer.plugin.LoadBalancerPluginv2'],
    allow_overlapping_ips   => true,
    host                    => $::hostname,
    global_physnet_mtu      => '1450',
    log_dir                 => '/var/log/neutron',
    rpc_backend             => 'rabbit',
    control_exchange        => 'neutron',
    root_helper             => 'sudo neutron-rootwrap /etc/neutron/rootwrap.conf',
    #
    rabbit_hosts            => ["${controller_1}:5672", "${controller_2}:5672", "${controller_3}:5672"],
    rabbit_use_ssl          => false,
    rabbit_user             => 'guest',
    rabbit_password         => 'guest',
    rabbit_ha_queues        => true,
    rabbit_heartbeat_timeout_threshold => '60',
    #
    dhcp_agents_per_network => '3',
    #
    purge_config            => true,
  }

  class { '::neutron::keystone::authtoken':
    auth_uri            => "http://${controller_vip}:5000/",
    auth_url            => "http://${controller_vip}:35357/",
    memcached_servers   => ["${controller_1}:11211", "${controller_2}:11211", "${controller_3}:11211"],
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    region_name         => 'RegionOne',
    project_name        => 'services',
    username            => 'neutron',
    password            => $neutron_password,
  }

  class { '::neutron::server':
    database_connection          => "mysql+pymysql://neutron:${neutron_password}@${controller_vip}/neutron",
    database_max_retries         => '-1',
    # db_max_retries             => '-1',
    service_providers            => [
      'LOADBALANCERV2:Octavia:neutron_lbaas.drivers.octavia.driver.OctaviaDriver:default',
      'LOADBALANCER:Haproxy:neutron_lbaas.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver',
      'VPN:openswan:neutron_vpnaas.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default'],
    auth_strategy => false,
    enable_proxy_headers_parsing => true,
    #
    router_distributed           => false,
    router_scheduler_driver      => 'neutron.scheduler.l3_agent_scheduler.ChanceScheduler',
    #
    api_workers   => '2',
    rpc_workers   => '2',
    l3_ha         => true,
    max_l3_agents_per_router     => '3',
    #
    sync_db       => $sync_db,
  }

  class { '::neutron::server::notifications':
    auth_url          => "http://${controller_vip}:35357/v3",
    auth_type         => 'password',
    project_domain_id => 'default',
    user_domain_id    => 'default',
    region_name       => 'RegionOne',
    project_name      => 'services',
    username          => 'nova',
    password          => $nova_password,
    #
    nova_url          => "http://${controller_vip}:8774/v2.1",
    notify_nova_on_port_status_changes => true,
    notify_nova_on_port_data_changes   => true,
  }

  class { '::neutron::plugins::ml2':
    type_drivers         => ['local', 'flat', 'vlan', 'gre', 'vxlan'],
    tenant_network_types => ['vlan', 'vxlan'],
    mechanism_drivers    => ['openvswitch'],
    extension_drivers    => ['qos', 'port_security'],
    flat_networks        => '*',
    network_vlan_ranges  => 'physnet1:1:4094',
    tunnel_id_ranges     => '1:4094',
    vxlan_group          => '224.0.0.1',
    vni_ranges           => '1:4094',
    #
    purge_config         => true,
  }

  class { '::neutron::services::fwaas':
    enabled              => true,
    driver               => 'openvswitch',
    vpnaas_agent_package => false,
    purge_config         => true,
  }

  class { '::neutron::services::lbaas':
  }

  class { '::neutron::services::vpnaas':
  }

  class { '::neutron::agents::ml2::ovs':
    tunnel_types               => ['vxlan'],
    vxlan_udp_port             => '4789',
    l2_population              => false,
    arp_responder              => false,
    enable_distributed_routing => false,
    drop_flows_on_start        => false,
    extensions                 => ['qos'],
    integration_bridge         => 'br-int',
    tunnel_bridge              => 'br-tun',
    local_ip                   => $::ipaddress_eth3,
    bridge_mappings            => ['physnet1:br-eth2', 'extnet:br-ex'],
    firewall_driver            => 'neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver',
    #
    purge_config               => true,
  }

  class { '::neutron::agents::dhcp':
    resync_interval          => '30',
    interface_driver         => 'neutron.agent.linux.interface.OVSInterfaceDriver',
    dhcp_driver              => 'neutron.agent.linux.dhcp.Dnsmasq',
    root_helper              => 'sudo neutron-rootwrap /etc/neutron/rootwrap.conf',
    # dnsmasq_config_file      => '/etc/neutron/dnsmasq-neutron.conf',
    enable_force_metadata    => true,
    enable_isolated_metadata => true,
    enable_metadata_network  => true,
    #
    purge_config             => true,
  }

  class { '::neutron::agents::l3':
    interface_driver   => 'neutron.agent.linux.interface.OVSInterfaceDriver',
    agent_mode         => 'legacy',
    debug              => false,
    #
    ha_vrrp_advert_int => '3',
    #
    purge_config       => true,
  }

  class { '::neutron::agents::metadata':
    metadata_ip   => $controller_vip,
    shared_secret => $metadata_secret,
    #
    purge_config  => true,
  }

  class { '::neutron::agents::lbaas':
    interface_driver       => 'neutron.agent.linux.interface.OVSInterfaceDriver',
    device_driver          => 'neutron_lbaas.drivers.haproxy.namespace_driver.HaproxyNSDriver',
    manage_haproxy_package => false,
    #
    purge_config           => true,
  }

  class { '::neutron::agents::vpnaas':
    vpn_device_driver           => 'neutron.services.vpn.device_drivers.ipsec.OpenSwanDriver',
    interface_driver            => 'neutron.agent.linux.interface.OVSInterfaceDriver',
    ipsec_status_check_interval => '30',
    #
    purge_config                => true,
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
    class { '::neutron::keystone::auth':
      password            => $neutron_password,
      auth_name           => 'neutron',
      email               => 'neutron@example.com',
      tenant              => 'services',
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
      service_name        => 'neutron',
      service_type        => 'network',
      service_description => 'Neutron Networking Service',
      region              => 'RegionOne',
      public_url          => "http://${controller_vip}:9696",
      admin_url           => "http://${controller_vip}:9696",
      internal_url        => "http://${controller_vip}:9696",
    }
  }
}
