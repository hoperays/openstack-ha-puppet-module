class openstack::y009_aodh (
  $bootstrap_node   = 'controller-1',
  $aodh_password    = 'aodh1234',
  $redis_password   = 'redis1234',
  $allowed_hosts    = ['%'],
  $username         = 'aodh',
  $api_public_vip   = '172.17.52.100',
  $api_internal_vip = '172.17.53.100',
  $controller_1     = '172.17.53.101',
  $controller_2     = '172.17.53.102',
  $controller_3     = '172.17.53.103',) {
  if $::hostname == $bootstrap_node {
    Exec['galera-ready'] ->
    class { '::aodh::db::mysql':
      password      => $aodh_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    $sync_db = true
  } else {
    $sync_db = false
  }

  class { '::aodh::db':
    database_max_retries    => '-1',
    database_db_max_retries => '-1',
    database_connection     => "mysql+pymysql://aodh:${aodh_password}@${api_internal_vip}/aodh",
  }

  class { '::aodh':
    log_dir          => '/var/log/aodh',
    rpc_backend      => 'rabbit',
    #
    rabbit_hosts     => ["${controller_1}:5672", "${controller_2}:5672", "${controller_3}:5672"],
    rabbit_use_ssl   => false,
    rabbit_password  => 'guest',
    rabbit_userid    => 'guest',
    rabbit_ha_queues => true,
    rabbit_heartbeat_timeout_threshold => '60',
    #
    purge_config     => true,
  }

  class { '::aodh::keystone::authtoken':
    auth_uri            => "http://${api_internal_vip}:5000",
    auth_url            => "http://${api_internal_vip}:35357",
    memcached_servers   => ["${controller_1}:11211", "${controller_2}:11211", "${controller_3}:11211"],
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    project_name        => 'services',
    username            => 'aodh',
    password            => $aodh_password,
  }

  class { '::aodh::api':
    # enable_combination_alarms = False
    host          => $::ipaddress_vlan53,
    port          => '8042',
    enable_proxy_headers_parsing => true,
    #
    service_name  => 'httpd',
    auth_strategy => 'keystone',
    sync_db       => $sync_db,
  }

  # aodh_config { 'api/enable_combination_alarms': value => false; }

  class { '::aodh::wsgi::apache':
    ssl       => false,
    bind_host => $::ipaddress_vlan53,
  }

  class { '::aodh::auth':
    auth_password     => $aodh_password,
    auth_url          => "http://${api_internal_vip}:5000",
    auth_region       => 'RegionOne',
    auth_user         => 'aodh',
    auth_tenant_name  => 'services',
    project_domain_id => 'default',
    user_domain_id    => 'default',
    auth_type         => 'password',
  }

  class { '::aodh::evaluator':
    coordination_url => "redis://:${redis_password}@${api_internal_vip}:6379",
    #
    require          => Package['python-redis'],
  }

  class { '::aodh::notifier':
  }

  class { '::aodh::listener':
  }

  class { '::aodh::client':
  }

  if $::hostname == $bootstrap_node {
    class { '::aodh::keystone::auth':
      password            => $aodh_password,
      auth_name           => 'aodh',
      email               => 'aodh@localhost',
      tenant              => 'services',
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
      service_name        => 'aodh',
      service_type        => 'alarming',
      region              => 'RegionOne',
      public_url          => "http://${api_public_vip}:8042",
      internal_url        => "http://${api_internal_vip}:8042",
      admin_url           => "http://${api_internal_vip}:8042",
    }
  }
}
