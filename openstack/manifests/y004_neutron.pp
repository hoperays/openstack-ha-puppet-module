class openstack::y004_neutron (
  $bootstrap_node   = 'controller-1',
  $neutron_password = 'neutron1234',
  $nova_password    = 'nova1234',
  $allowed_hosts    = ['%'],
  $username         = 'neutron',
  $api_public_vip   = '172.17.52.100',
  $api_internal_vip = '172.17.53.100',
  $controller_1     = '172.17.53.101',
  $controller_2     = '172.17.53.102',
  $controller_3     = '172.17.53.103',
  $metadata_secret  = 'metadata1234',
  $bridge_mappings  = ['cloud:br-bond0']) {
  if $::hostname == $bootstrap_node {
    Exec['galera-ready'] ->
    class { '::neutron::db::mysql':
      password      => $neutron_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    $sync_db = true
    Anchor['neutron::dbsync::end'] ->
    exec { "${username}-db-ready-echo":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/ssh controller-2 'echo ok > /tmp/${username}-db-ready' && \
                    /usr/bin/ssh controller-3 'echo ok > /tmp/${username}-db-ready'",
      unless    => "/usr/bin/ssh controller-2 'echo ok > /tmp/${username}-db-ready' && \
                    /usr/bin/ssh controller-3 'echo ok > /tmp/${username}-db-ready'",
    }
  } elsif $::hostname =~ /^controller-\d+$/ {
    $sync_db = false
    Anchor['neutron::config::end'] ->
    exec { "${username}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/cat /tmp/${username}-db-ready | grep ok",
      unless    => "/usr/bin/cat /tmp/${username}-db-ready | grep ok",
    } ->
    Anchor['neutron::service::begin'] ->
    exec { "${username}-db-ready-rm":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/rm -f /tmp/${username}-db-ready",
      unless    => "/usr/bin/rm -f /tmp/${username}-db-ready",
    }
  }

  class { '::neutron':
    bind_host               => $::ipaddress_vlan53,
    auth_strategy           => 'keystone',
    core_plugin             => 'neutron.plugins.ml2.plugin.Ml2Plugin',
    service_plugins         => [
      'router',
      'qos',
      'trunk',
      'firewall',
      'vpnaas',
      'neutron_lbaas.services.loadbalancer.plugin.LoadBalancerPluginv2',
      'metering'],
    allow_overlapping_ips   => true,
    host                    => $::hostname,
    global_physnet_mtu      => '1500',
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
    local_ip                   => $::ipaddress_vlan54,
    bridge_mappings            => $bridge_mappings,
    firewall_driver            => 'neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver',
    #
    purge_config               => true,
  }

  if $::hostname =~ /^controller-\d+$/ {
    class { '::neutron::keystone::authtoken':
      auth_uri            => "http://${api_internal_vip}:5000",
      auth_url            => "http://${api_internal_vip}:35357",
      memcached_servers   => ["${controller_1}:11211", "${controller_2}:11211", "${controller_3}:11211"],
      auth_type           => 'password',
      project_domain_name => 'default',
      user_domain_name    => 'default',
      project_name        => 'services',
      username            => 'neutron',
      password            => $neutron_password,
    }

    class { '::neutron::db':
      database_max_retries    => '-1',
      database_db_max_retries => '-1',
      database_connection     => "mysql+pymysql://neutron:${neutron_password}@${api_internal_vip}/neutron",
    }

    class { '::neutron::server':
      service_providers  => [
        'FIREWALL:Iptables:neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver:default',
        'LOADBALANCERV2:Haproxy:neutron_lbaas.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default',
        'VPN:openswan:neutron_vpnaas.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default'],
      auth_strategy      => 'keystone',
      enable_proxy_headers_parsing => true,
      #
      router_distributed => false,
      router_scheduler_driver      => 'neutron.scheduler.l3_agent_scheduler.ChanceScheduler',
      #
      l3_ha              => true,
      max_l3_agents_per_router     => '3',
      #
      sync_db            => $sync_db,
    }

    class { '::neutron::server::notifications':
      auth_url          => "http://${api_internal_vip}:35357/v3",
      auth_type         => 'password',
      project_domain_id => 'default',
      user_domain_id    => 'default',
      project_name      => 'services',
      username          => 'nova',
      password          => $nova_password,
      #
      nova_url          => "http://${api_internal_vip}:8774/v2.1",
      notify_nova_on_port_status_changes => true,
      notify_nova_on_port_data_changes   => true,
    }

    class { '::neutron::plugins::ml2':
      type_drivers         => ['local', 'flat', 'vlan', 'gre', 'vxlan'],
      tenant_network_types => ['vlan', 'vxlan'],
      mechanism_drivers    => ['openvswitch'],
      extension_drivers    => ['port_security', 'qos'],
      flat_networks        => '*',
      network_vlan_ranges  => ['cloud:1:1', 'cloud:100:599'],
      tunnel_id_ranges     => ['100:599'],
      vxlan_group          => '224.0.0.1',
      vni_ranges           => ['100:599'],
      #
      purge_config         => true,
    }

    neutron_fwaas_service_config { 'fwaas/agent_version': value => 'v1'; }

    class { '::neutron::services::fwaas':
      driver               => 'neutron_fwaas.services.firewall.drivers.linux.iptables_fwaas.IptablesFwaasDriver',
      enabled              => true,
      vpnaas_agent_package => false,
      #
      purge_config         => true,
    }

    class { '::neutron::services::lbaas':
    }

    class { '::neutron::services::vpnaas':
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

    neutron_l3_agent_config { 'AGENT/extensions': value => join(any2array(['fwaas']), ','); }

    class { '::neutron::agents::metadata':
      metadata_ip   => $api_internal_vip,
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

    class { 'neutron::agents::metering':
      interface_driver => 'neutron.agent.linux.interface.OVSInterfaceDriver',
      driver           => 'neutron.services.metering.drivers.noop.noop_driver.NoopMeteringDriver',
      measure_interval => '30',
      report_interval  => '300',
      #
      purge_config     => true,
    }
  }

  if $::hostname == $bootstrap_node {
    class { '::neutron::keystone::auth':
      password            => $neutron_password,
      auth_name           => 'neutron',
      email               => 'neutron@localhost',
      tenant              => 'services',
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
      service_name        => 'neutron',
      service_type        => 'network',
      service_description => 'Neutron Networking Service',
      region              => 'RegionOne',
      public_url          => "http://${api_public_vip}:9696",
      admin_url           => "http://${api_internal_vip}:9696",
      internal_url        => "http://${api_internal_vip}:9696",
    }
  }
}
