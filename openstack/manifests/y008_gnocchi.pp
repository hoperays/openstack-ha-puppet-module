class openstack::y008_gnocchi (
  $bootstrap_node   = 'controller-1',
  $gnocchi_password = 'gnocchi1234',
  $redis_password   = 'redis1234',
  $allowed_hosts    = ['%'],
  $username         = 'gnocchi',
  $api_public_vip   = '172.17.52.100',
  $api_internal_vip = '172.17.53.100',
  $controller_1     = '172.17.53.101',
  $controller_2     = '172.17.53.102',
  $controller_3     = '172.17.53.103',) {
  if $::hostname == $bootstrap_node {
    Exec['galera-ready'] ->
    class { '::gnocchi::db::mysql':
      password      => $gnocchi_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    $sync_db = true
  } else {
    $sync_db = false
  }

  class { '::gnocchi':
    log_dir             => '/var/log/gnocchi',
    database_connection => "mysql+pymysql://gnocchi:${gnocchi_password}@${api_internal_vip}/gnocchi",
    #
    purge_config        => true,
  }

  class { '::gnocchi::keystone::authtoken':
    auth_uri            => "http://${api_internal_vip}:5000",
    auth_url            => "http://${api_internal_vip}:35357",
    memcached_servers   => ["${controller_1}:11211", "${controller_2}:11211", "${controller_3}:11211"],
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    project_name        => 'services',
    username            => 'gnocchi',
    password            => $gnocchi_password,
  }

  class { '::gnocchi::api':
    max_limit     => '1000',
    host          => $::ipaddress_vlan53,
    port          => '8041',
    enable_proxy_headers_parsing => true,
    #
    service_name  => 'httpd',
    auth_strategy => 'keystone',
    sync_db       => $sync_db,
  }

  class { '::gnocchi::wsgi::apache':
    ssl       => false,
    bind_host => $::ipaddress_vlan53,
  }

  class { '::gnocchi::metricd':
  }

  class { '::gnocchi::statsd':
    resource_id         => '694470c3-11a3-4e34-a3d2-e3f85b7b96f4',
    user_id             => 'ad938629-e7d6-466b-a96b-e2c3d8024d19',
    project_id          => '77e10849-0e36-466a-9396-50d39fa200b1',
    archive_policy_name => 'low',
    flush_delay         => '10',
  }

  class { '::gnocchi::storage':
    coordination_url => "redis://:${redis_password}@${api_internal_vip}:6379",
    #
    require          => Package['python-redis'],
  }

  class { '::gnocchi::storage::ceph':
    ceph_pool     => 'metrics',
    ceph_username => 'openstack',
    ceph_keyring  => '/etc/ceph/ceph.client.openstack.keyring',
    ceph_conffile => '/etc/ceph/ceph.conf',
  }

  class { '::gnocchi::client':
  }

  if $::hostname == $bootstrap_node {
    class { '::gnocchi::keystone::auth':
      password            => $gnocchi_password,
      auth_name           => 'gnocchi',
      email               => 'gnocchi@localhost',
      tenant              => 'services',
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
      service_name        => 'gnocchi',
      service_type        => 'metric',
      region              => 'RegionOne',
      public_url          => "http://${api_public_vip}:8041",
      internal_url        => "http://${api_internal_vip}:8041",
      admin_url           => "http://${api_internal_vip}:8041",
      service_description => 'Openstack Metric Service',
    }
  }
}
