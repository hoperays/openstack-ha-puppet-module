class openstack::y007_ceilometer (
  $bootstrap_node      = 'controller-1',
  $ceilometer_password = 'ceilometer1234',
  $redis_password      = 'redis1234',
  $api_public_vip      = '172.17.52.100',
  $api_internal_vip    = '172.17.53.100',
  $controller_1        = '172.17.53.101',
  $controller_2        = '172.17.53.102',
  $controller_3        = '172.17.53.103',
  $telemetry_secret    = 'ceilometersecret',) {
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
    #
    purge_config          => true,
  }

  class { '::ceilometer::agent::auth':
    auth_url                 => "http://${api_internal_vip}:5000",
    auth_endpoint_type       => 'internalURL',
    auth_type                => 'password',
    auth_user_domain_name    => 'default',
    auth_project_domain_name => 'default',
    auth_region              => 'RegionOne',
    auth_tenant_name         => 'services',
    auth_user                => 'ceilometer',
    auth_password            => $ceilometer_password,
  }

  if $::hostname =~ /^controller-\d+$/ {
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
      coordination_url => "redis://:${redis_password}@${api_internal_vip}:6379",
      #
      require          => Package['python-redis'],
    }

    class { '::ceilometer::agent::notification':
      ack_on_event_error => true,
      store_events       => false,
    }

    class { '::ceilometer::keystone::authtoken':
      auth_uri            => "http://${api_internal_vip}:5000",
      auth_url            => "http://${api_internal_vip}:35357",
      memcached_servers   => ["${controller_1}:11211", "${controller_2}:11211", "${controller_3}:11211"],
      auth_type           => 'password',
      project_domain_name => 'default',
      user_domain_name    => 'default',
      project_name        => 'services',
      username            => 'ceilometer',
      password            => $ceilometer_password,
    }

    class { '::ceilometer::api':
      host          => $ipaddress_vlan53,
      port          => '8777',
      enable_proxy_headers_parsing => true,
      #
      service_name  => 'httpd',
      auth_strategy => 'keystone',
    }

    class { '::ceilometer::wsgi::apache':
      ssl       => false,
      bind_host => $::ipaddress_vlan53,
    }

    class { '::ceilometer::collector':
      meter_dispatcher => ['gnocchi'],
      event_dispatcher => ['database'],
      udp_address      => '0.0.0.0',
      udp_port         => '4952',
    }

    class { '::ceilometer::dispatcher::gnocchi':
      filter_project => 'services',
      archive_policy => 'low',
      resources_definition_file => 'gnocchi_resources.yaml',
      url            => "http://${api_internal_vip}:8041",
    }
  } elsif $::hostname =~ /^compute-\d+$/ {
    class { '::ceilometer::agent::compute': }
  }

  if $::hostname == $bootstrap_node {
    class { '::ceilometer::keystone::auth':
      password            => $ceilometer_password,
      email               => 'ceilometer@localhost',
      auth_name           => 'ceilometer',
      configure_user      => true,
      configure_user_role => true,
      service_name        => 'ceilometer',
      service_type        => 'metering',
      service_description => 'Openstack Metering Service',
      region              => 'RegionOne',
      tenant              => 'services',
      configure_endpoint  => true,
      public_url          => "http://${api_public_vip}:8777",
      admin_url           => "http://${api_internal_vip}:8777",
      internal_url        => "http://${api_internal_vip}:8777",
    }
  }
}
