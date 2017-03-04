class openstack::y004_neutron (
  $bootstrap_node           = hiera('controller_1_hostname'),
  $rabbit_user              = hiera('rabbit_username'),
  $rabbit_password          = hiera('rabbit_password'),
  $email                    = hiera('neutron_email'),
  $dbname                   = hiera('neutron_dbname'),
  $user                     = hiera('neutron_username'),
  $password                 = hiera('neutron_password'),
  $public_vip               = hiera('public_vip'),
  $internal_vip             = hiera('internal_vip'),
  $controller_1_internal_ip = hiera('controller_1_internal_ip'),
  $controller_2_internal_ip = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip = hiera('controller_3_internal_ip'),
  $internal_interface       = hiera('internal_interface'),
  $metadata_secret          = hiera('metadata_secret'),
  $nova_username            = hiera('nova_username'),
  $nova_password            = hiera('nova_password'),
  $service_plugins          = [],
  $service_providers        = [],
  $global_physnet_mtu       = '',
  $dhcp_agents_per_network  = '',
  $bridge_mappings          = [],
  $l3_ha                    = false,
  $max_l3_agents_per_router = '',
  $type_drivers             = [],
  $tenant_network_types     = [],
  $mechanism_drivers        = [],
  $extension_drivers        = [],
  $flat_networks            = '',
  $network_vlan_ranges      = [],
  $tunnel_id_ranges         = [],
  $vxlan_group              = '',
  $vni_ranges               = '',
) {
  if $::hostname == $bootstrap_node {
    class { '::neutron::db::mysql':
      dbname        => $dbname,
      user          => $user,
      password      => $password,
      host          => 'localhost',
      allowed_hosts => [$controller_1_internal_ip, $controller_2_internal_ip, $controller_3_internal_ip],
    }
    $sync_db = true
    Anchor['neutron::dbsync::end'] ->
    exec { "${dbname}-db-ready-echo":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/ssh ${controller_2_internal_ip} 'echo ok > /tmp/${dbname}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'echo ok > /tmp/${dbname}-db-ready'",
      unless    => "/bin/ssh ${controller_2_internal_ip} 'echo ok > /tmp/${dbname}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'echo ok > /tmp/${dbname}-db-ready'",
    }
  } elsif $::hostname =~ /^*controller-\d*$/ {
    $sync_db = false
    Anchor['neutron::config::end'] ->
    exec { "${dbname}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/cat /tmp/${dbname}-db-ready | grep ok",
      unless    => "/bin/cat /tmp/${dbname}-db-ready | grep ok",
    } ->
    Anchor['neutron::service::begin'] ->
    exec { "${dbname}-db-ready-rm":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/rm -f /tmp/${dbname}-db-ready",
      unless    => "/bin/rm -f /tmp/${dbname}-db-ready",
    }
  }

  class { '::neutron':
    bind_host               => $internal_interface,
    auth_strategy           => 'keystone',
    core_plugin             => 'neutron.plugins.ml2.plugin.Ml2Plugin',
    service_plugins         => $service_plugins,
    allow_overlapping_ips   => true,
    host                    => $::hostname,
    global_physnet_mtu      => $global_physnet_mtu,
    log_dir                 => '/var/log/neutron',
    rpc_backend             => 'rabbit',
    control_exchange        => 'neutron',
    root_helper             => 'sudo neutron-rootwrap /etc/neutron/rootwrap.conf',
    #
    rabbit_hosts            => [
      "${controller_1_internal_ip}:5672",
      "${controller_2_internal_ip}:5672",
      "${controller_3_internal_ip}:5672"],
    rabbit_use_ssl          => false,
    rabbit_user             => $rabbit_user,
    rabbit_password         => $rabbit_password,
    rabbit_ha_queues        => true,
    rabbit_heartbeat_timeout_threshold => '60',
    #
    dhcp_agents_per_network => $dhcp_agents_per_network,
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
    local_ip                   => hiera('tenant_interface'),
    bridge_mappings            => $bridge_mappings,
    firewall_driver            => 'neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver',
    #
    purge_config               => true,
  }

  if $::hostname =~ /^*controller-\d*$/ {
    class { '::neutron::keystone::authtoken':
      auth_uri            => "http://${internal_vip}:5000",
      auth_url            => "http://${internal_vip}:35357",
      memcached_servers   => [
        "${controller_1_internal_ip}:11211",
        "${controller_2_internal_ip}:11211",
        "${controller_3_internal_ip}:11211"],
      auth_type           => 'password',
      project_domain_name => 'default',
      user_domain_name    => 'default',
      project_name        => 'services',
      username            => $user,
      password            => $password,
    }

    class { '::neutron::db':
      database_max_retries    => '-1',
      database_db_max_retries => '-1',
      database_connection     => "mysql+pymysql://${user}:${password}@${internal_vip}/${dbname}",
    }

    class { '::neutron::server':
      service_providers            => $service_providers,
      auth_strategy                => 'keystone',
      enable_proxy_headers_parsing => true,
      #
      router_distributed           => false,
      router_scheduler_driver      => 'neutron.scheduler.l3_agent_scheduler.ChanceScheduler',
      #
      l3_ha                        => $l3_ha,
      max_l3_agents_per_router     => $max_l3_agents_per_router,
      #
      sync_db                      => $sync_db,
    }

    class { '::neutron::server::notifications':
      auth_url          => "http://${internal_vip}:35357/v3",
      auth_type         => 'password',
      project_domain_id => 'default',
      user_domain_id    => 'default',
      project_name      => 'services',
      username          => $nova_username,
      password          => $nova_password,
      #
      nova_url          => "http://${internal_vip}:8774/v2.1",
      notify_nova_on_port_status_changes => true,
      notify_nova_on_port_data_changes   => true,
    }

    class { '::neutron::plugins::ml2':
      type_drivers         => $type_drivers,
      tenant_network_types => $tenant_network_types,
      mechanism_drivers    => $mechanism_drivers,
      extension_drivers    => $extension_drivers,
      flat_networks        => $flat_networks,
      network_vlan_ranges  => $network_vlan_ranges,
      tunnel_id_ranges     => $tunnel_id_ranges,
      vxlan_group          => $vxlan_group,
      vni_ranges           => $vni_ranges,
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
      # dnsmasq_config_file    => '/etc/neutron/dnsmasq-neutron.conf',
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
      metadata_ip   => $internal_vip,
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
      password            => $password,
      auth_name           => $user,
      email               => $email,
      tenant              => 'services',
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
      service_name        => 'neutron',
      service_type        => 'network',
      service_description => 'Neutron Networking Service',
      region              => 'RegionOne',
      public_url          => "http://${public_vip}:9696",
      admin_url           => "http://${internal_vip}:9696",
      internal_url        => "http://${internal_vip}:9696",
    }
  }
}
