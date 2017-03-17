class openstack::y009_aodh (
  $bootstrap_node           = hiera('controller_1_hostname'),
  $rabbit_userid            = hiera('rabbit_username'),
  $rabbit_password          = hiera('rabbit_password'),
  $email                    = hiera('aodh_email'),
  $dbname                   = hiera('aodh_dbname'),
  $user                     = hiera('aodh_username'),
  $password                 = hiera('aodh_password'),
  $public_vip               = hiera('public_vip'),
  $internal_vip             = hiera('internal_vip'),
  $controller_1_internal_ip = hiera('controller_1_internal_ip'),
  $controller_2_internal_ip = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip = hiera('controller_3_internal_ip'),
  $internal_interface       = hiera('internal_interface'),
  $redis_password           = hiera('redis_password'),
) {
  if $::hostname == $bootstrap_node {
    class { '::aodh::db::mysql':
      dbname        => $dbname,
      user          => $user,
      password      => $password,
      host          => 'localhost',
      allowed_hosts => [$controller_1_internal_ip, $controller_2_internal_ip, $controller_3_internal_ip],
    }
    $sync_db = true

    class { '::aodh::keystone::auth':
      password            => $password,
      auth_name           => $user,
      email               => $email,
      tenant              => 'services',
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
      service_name        => 'aodh',
      service_type        => 'alarming',
      region              => 'RegionOne',
      public_url          => "http://${public_vip}:8042",
      internal_url        => "http://${internal_vip}:8042",
      admin_url           => "http://${internal_vip}:8042",
    }
  } elsif $::hostname =~ /^*controller-\d*$/ {
    $sync_db = false
  }

  class { '::aodh::db':
    database_max_retries    => '-1',
    database_db_max_retries => '-1',
    database_connection     => "mysql+pymysql://${user}:${password}@${internal_vip}/${dbname}",
  }

  class { '::aodh':
    log_dir          => '/var/log/aodh',
    rpc_backend      => 'rabbit',
    #
    rabbit_hosts     => [
      "${controller_1_internal_ip}:5672",
      "${controller_2_internal_ip}:5672",
      "${controller_3_internal_ip}:5672"],
    rabbit_use_ssl   => false,
    rabbit_password  => $rabbit_password,
    rabbit_userid    => $rabbit_userid,
    rabbit_ha_queues => true,
    rabbit_heartbeat_timeout_threshold => '60',
    #
    purge_config     => true,
  }

  class { '::aodh::keystone::authtoken':
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

  class { '::aodh::api':
    # enable_combination_alarms = False
    host          => $internal_interface,
    port          => '8042',
    enable_proxy_headers_parsing => true,
    #
    service_name  => 'httpd',
    auth_strategy => 'keystone',
    sync_db       => $sync_db,
  }

  # aodh_config { 'api/enable_combination_alarms': value => false; }

  class { '::aodh::wsgi::apache':
    bind_host => $internal_interface,
    ssl       => false,
  }

  class { '::aodh::auth':
    auth_user         => $user,
    auth_password     => $password,
    auth_url          => "http://${internal_vip}:5000",
    auth_region       => 'RegionOne',
    auth_tenant_name  => 'services',
    project_domain_id => 'default',
    user_domain_id    => 'default',
    auth_type         => 'password',
  }

  class { '::aodh::evaluator':
    coordination_url => "redis://:${redis_password}@${internal_vip}:6379",
  }

  class { '::aodh::notifier':
  }

  class { '::aodh::listener':
  }

  class { '::aodh::client':
  }
}
