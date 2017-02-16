class openstack::y007_ceilometer (
  $bootstrap_node      = 'controller-1',
  $ceilometer_password = 'ceilometer1234',
  $redis_password      = 'redis1234',
  $allowed_hosts       = ['%'],
  $username            = 'ceilometer',
  $controller_vip      = '192.168.0.130',
  $controller_1        = '192.168.0.131',
  $controller_2        = '192.168.0.132',
  $controller_3        = '192.168.0.133',
  $telemetry_secret    = 'ceilometersecret',) {
  if $::hostname == $bootstrap_node {
    Exec['galera-ready'] ->
    class { '::ceilometer::db::mysql':
      password      => $ceilometer_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    $sync_db = true
    Anchor['ceilometer::dbsync::end'] ->
    exec { "${username}-db-ready-echo":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/ssh controller-2 'echo ok > /tmp/${username}-db-ready' && \
                    /usr/bin/ssh controller-3 'echo ok > /tmp/${username}-db-ready'",
      unless    => "/usr/bin/ssh controller-2 'echo ok > /tmp/${username}-db-ready' && \
                    /usr/bin/ssh controller-3 'echo ok > /tmp/${username}-db-ready'",
    }
  } else {
    $sync_db = false
    Anchor['ceilometer::config::end'] ->
    exec { "${username}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/cat /tmp/${username}-db-ready | grep ok",
      unless    => "/usr/bin/cat /tmp/${username}-db-ready | grep ok",
    } ->
    Anchor['ceilometer::service::begin'] ->
    exec { "${username}-db-ready-rm":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/rm -f /tmp/${username}-db-ready",
      unless    => "/usr/bin/rm -f /tmp/${username}-db-ready",
    }
  }

  class { '::ceilometer':
    http_timeout          => '600',
    log_dir               => '/var/log/ceilometer',
    rpc_backend           => 'rabbit',
    metering_time_to_live => '-1',
    event_time_to_live    => '-1',
    notification_topics   => ['notifications'],
    telemetry_secret      => $telemetry_secret,
    #
    rabbit_hosts          => ["${controller_1}:5672", "${controller_2}:5672", "${controller_3}:5672"],
    rabbit_use_ssl        => false,
    rabbit_password       => 'guest',
    rabbit_userid         => 'guest',
    rabbit_ha_queues      => true,
    rabbit_heartbeat_timeout_threshold => '60',
  }

  class { '::ceilometer::db':
    database_connection     => "mongodb://${controller_1}:27017,${controller_2}:27017,${controller_3}:27017/ceilometer?replicaSet=openstack",
    database_max_retries    => '-1',
    database_db_max_retries => '-1',
  }

  class { '::ceilometer::client':
  }

  class { '::ceilometer::expirer':
  }

  class { '::ceilometer::agent::central':
    coordination_url => "redis://:${redis_password}@${controller_vip}:6379",
  }

  class { '::ceilometer::agent::notification':
    ack_on_event_error => true,
    store_events       => false,
  }

  class { '::ceilometer::keystone::authtoken':
    auth_uri            => "http://${controller_vip}:5000/",
    auth_url            => "http://${controller_vip}:35357/",
    memcached_servers   => ["${controller_1}:11211", "${controller_2}:11211", "${controller_3}:11211"],
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    region_name         => 'RegionOne',
    project_name        => 'services',
    username            => 'ceilometer',
    password            => $ceilometer_password,
  }

  class { '::ceilometer::api':
    host         => $ipaddress_eth0,
    port         => '8777',
    enable_proxy_headers_parsing => true,
    #
    service_name => 'httpd',
  }

  class { '::ceilometer::wsgi::apache':
    ssl => false,
  }

  class { '::ceilometer::collector':
    meter_dispatcher  => ['gnocchi'],
    event_dispatchers => ['database'],
    udp_address       => '0.0.0.0',
    udp_port          => '4952',
  }

  class { '::ceilometer::dispatcher::gnocchi':
    filter_project => 'services',
    archive_policy => 'low',
    resources_definition_file => 'gnocchi_resources.yaml',
    url            => "http://${controller_vip}:8041",
  }

  if $::hostname == $bootstrap_node {
    class { '::ceilometer::keystone::auth':
      password            => $ceilometer_password,
      auth_name           => 'ceilometer',
      service_name        => 'ceilometer',
      service_description => 'Openstack Metering Service',
      region              => 'RegionOne',
      tenant              => 'services',
      email               => 'ceilometer@localhost',
      public_url          => "http://${controller_vip}:8777",
      internal_url        => "http://${controller_vip}:8777",
      admin_url           => "http://${controller_vip}:8777",
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
    }
  }
}
