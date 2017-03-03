class openstack::y008_gnocchi (
  $bootstrap_node           = hiera('controller_1_hostname'),
  $dbname                   = hiera('gnocchi_dbname'),
  $user                     = hiera('gnocchi_username'),
  $password                 = hiera('gnocchi_password'),
  $public_vip               = hiera('public_vip'),
  $internal_vip             = hiera('internal_vip'),
  $controller_1_internal_ip = hiera('controller_1_internal_ip'),
  $controller_2_internal_ip = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip = hiera('controller_3_internal_ip'),
  $internal_interface       = hiera('internal_interface'),
  $redis_password           = hiera('redis_password'),
  $resource_id              = '',
  $user_id                  = '',
  $project_id               = '',
  $archive_policy_name      = '',
  $flush_delay              = '',
) {
  if $::hostname == $bootstrap_node {
    class { '::gnocchi::db::mysql':
      dbname        => $dbname,
      user          => $user,
      password      => $password,
      host          => 'localhost',
      allowed_hosts => [$controller_1_internal_ip, $controller_2_internal_ip, $controller_3_internal_ip],
    }
    $sync_db = true
  } else {
    $sync_db = false
  }

  class { '::gnocchi':
    log_dir             => '/var/log/gnocchi',
    database_connection => "mysql+pymysql://${user}:${password}@${internal_vip}/${dbname}",
    #
    purge_config        => true,
  }

  class { '::gnocchi::keystone::authtoken':
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

  class { '::gnocchi::api':
    max_limit     => '1000',
    host          => $internal_interface,
    port          => '8041',
    enable_proxy_headers_parsing => true,
    #
    service_name  => 'httpd',
    auth_strategy => 'keystone',
    sync_db       => $sync_db,
  }

  class { '::gnocchi::wsgi::apache':
    bind_host => $internal_interface,
    ssl       => false,
  }

  class { '::gnocchi::metricd':
  }

  class { '::gnocchi::statsd':
    resource_id         => $resource_id,
    user_id             => $user_id,
    project_id          => $project_id,
    archive_policy_name => $archive_policy_name,
    flush_delay         => $flush_delay,
  }

  class { '::gnocchi::storage':
    coordination_url => "redis://:${redis_password}@${internal_vip}:6379",
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
      password            => $password,
      auth_name           => $user,
      email               => "$user@localhost",
      tenant              => 'services',
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
      service_name        => 'gnocchi',
      service_type        => 'metric',
      region              => 'RegionOne',
      public_url          => "http://${public_vip}:8041",
      internal_url        => "http://${internal_vip}:8041",
      admin_url           => "http://${internal_vip}:8041",
      service_description => 'Openstack Metric Service',
    }
  }
}
