class openstack::y007_compute (
  $bootstrap_node    = 'controller-1',
  $nova_password     = 'nova1234',
  $nova_api_password = 'nova_api1234',
  $neutron_password  = 'neutron1234',
  $allowed_hosts     = ['%'],
  $cluster_nodes     = ['controller-1', 'controller-2', 'controller-3'],
  $host              = 'controller-vip',) {
  if $::hostname == $bootstrap_node {
    $sync_db = true
    $sync_db_api = true
  } else {
    $sync_db = false
    $sync_db_api = false
  }

  class { '::nova::compute':
    enabled     => true,
    vnc_enabled => true,
  }

  class { '::nova::compute::libvirt':
    migration_support => true,
  }

  class { '::nova':
    database_connection     => "mysql+pymysql://nova:${nova_password}@${host}/nova",
    api_database_connection => "mysql+pymysql://nova_api:${nova_api_password}@${host}/nova_api",
    database_max_retries    => '-1',
    rabbit_userid           => 'guest',
    rabbit_password         => 'guest',
    rabbit_hosts            => $cluster_nodes,
    rabbit_ha_queues        => true,
    auth_strategy           => 'keystone',
    cinder_catalog_info     => 'volumev2:cinderv2:publicURL',
  }

  class { '::nova::keystone::authtoken':
    auth_uri            => "http://${host}:5000/",
    auth_url            => "http://${host}:35357/",
    memcached_servers   => $cluster_nodes,
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    region_name         => 'RegionOne',
    project_name        => 'service',
    username            => 'nova',
    password            => $nova_password,
  }

  class { '::nova::network::neutron':
    neutron_auth_url                => "http://${host}:35357/v3",
    neutron_url                     => "http://${host}:9696",
    #
    neutron_auth_type               => 'v3password',
    neutron_project_domain_name     => 'default',
    neutron_user_domain_name        => 'default',
    neutron_region_name             => 'RegionOne',
    neutron_project_name            => 'service',
    neutron_username                => 'neutron',
    neutron_password                => $neutron_password,
    #
    neutron_url_timeout             => '30',
    neutron_ovs_bridge              => 'br-int',
    neutron_extension_sync_interval => '600',
    firewall_driver                 => 'nova.virt.firewall.NoopFirewallDriver',
    vif_plugging_is_fatal           => true,
    vif_plugging_timeout            => '300',
    dhcp_domain                     => 'novalocal',
  }

  class { '::nova::api':
    api_bind_address => $ipaddress_eth0,
    osapi_compute_listen_port            => '8774',
    metadata_listen  => $ipaddress_eth0,
    metadata_listen_port                 => '8775',
    enabled_apis     => ['osapi_compute', 'metadata'],
    sync_db          => $sync_db,
    sync_db_api      => $sync_db_api,
    neutron_metadata_proxy_shared_secret => 'metadata1234',
    #
    enabled          => false,
    manage_service   => false,
  }

  class { '::nova::vncproxy':
    vncproxy_protocol => 'http',
    host              => $::hostname,
    port              => '6080',
    vncproxy_path     => '/vnc_auto.html',
    #
    enabled           => false,
    manage_service    => false,
  }
}
