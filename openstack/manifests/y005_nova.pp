class openstack::y005_nova (
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

  class { '::nova':
    database_connection     => "mysql+pymysql://nova:${nova_password}@${host}/nova",
    api_database_connection => "mysql+pymysql://nova_api:${nova_api_password}@${host}/nova_api",
    database_max_retries    => '-1',
    rabbit_userid           => 'guest',
    rabbit_password         => 'guest',
    rabbit_hosts            => $cluster_nodes,
    rabbit_ha_queues        => true,
    auth_strategy           => 'keystone',
    glance_api_servers      => "http://${host}:9292",
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
    vif_plugging_is_fatal           => false,
    vif_plugging_timeout            => '0',
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

  class { '::nova::conductor':
    enabled        => false,
    manage_service => false,
  }

  class { '::nova::consoleauth':
    enabled        => false,
    manage_service => false,
  }

  class { '::nova::scheduler':
    enabled        => false,
    manage_service => false,
  }

  class { '::nova::vncproxy':
    vncproxy_protocol => 'http',
    host              => $ipaddress_eth0,
    port              => '6080',
    vncproxy_path     => '/vnc_auto.html',
    #
    enabled           => false,
    manage_service    => false,
  }

  if $::hostname == $bootstrap_node {
    class { '::nova::db::mysql':
      user          => 'nova',
      password      => $nova_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    } ->
    class { '::nova::db::mysql_api':
      user          => 'nova_api',
      password      => $nova_api_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    } ->
    keystone_service { 'nova':
      ensure      => 'present',
      type        => 'compute',
      description => 'OpenStack Compute',
    } ->
    keystone_endpoint { 'nova':
      ensure       => 'present',
      region       => 'RegionOne',
      admin_url    => "http://${host}:8774/v2.1/%(tenant_id)s",
      public_url   => "http://${host}:8774/v2.1/%(tenant_id)s",
      internal_url => "http://${host}:8774/v2.1/%(tenant_id)s",
    } ->
    keystone_user { 'nova':
      ensure   => 'present',
      password => $nova_password,
      # email    => 'nova@example.org',
      domain   => 'default',
    } ->
    keystone_user_role { 'nova::default@service::default':
      ensure         => 'present',
      user           => 'nova',
      user_domain    => 'default',
      project        => 'service',
      project_domain => 'default',
      roles          => ['admin'],
    } ->
    pacemaker::resource::service { 'openstack-nova-api': clone_params => 'interleave=true', } ->
    pacemaker::resource::service { 'openstack-nova-conductor': clone_params => 'interleave=true', } ->
    pacemaker::resource::service { 'openstack-nova-consoleauth': clone_params => 'interleave=true', } ->
    pacemaker::resource::service { 'openstack-nova-novncproxy': clone_params => 'interleave=true', } ->
    pacemaker::resource::service { 'openstack-nova-scheduler': clone_params => 'interleave=true', } ->
    exec { 'nova-ready':
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 server list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 server list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 server list > /dev/null 2>&1",
      unless    => "/usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 server list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 server list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 server list > /dev/null 2>&1",
    }
  }
}
