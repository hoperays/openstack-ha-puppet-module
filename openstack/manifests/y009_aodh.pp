class openstack::y009_aodh (
  $bootstrap_node           = hiera('controller_1_hostname'),
  $rabbit_userid            = hiera('rabbit_username'),
  $rabbit_password          = hiera('rabbit_password'),
  $email                    = hiera('aodh_email'),
  $dbname                   = hiera('aodh_dbname'),
  $user                     = hiera('aodh_username'),
  $password                 = hiera('aodh_password'),
  $admin_identity_fqdn      = hiera('admin_identity_fqdn'),
  $public_identity_fqdn     = hiera('public_identity_fqdn'),
  $internal_identity_fqdn   = hiera('internal_identity_fqdn'),
  $admin_alarming_fqdn      = hiera('admin_alarming_fqdn'),
  $public_alarming_fqdn     = hiera('public_alarming_fqdn'),
  $internal_alarming_fqdn   = hiera('internal_alarming_fqdn'),
  $internal_fqdn            = hiera('internal_fqdn'),
  $controller_1_internal_ip = hiera('controller_1_internal_ip'),
  $controller_2_internal_ip = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip = hiera('controller_3_internal_ip'),
  $internal_interface       = hiera('internal_interface'),
  $redis_password           = hiera('redis_password'),
  $region                   = hiera('region_name'),
) {
  if $::hostname == $bootstrap_node {
    class { '::aodh::db::mysql':
      dbname        => $dbname,
      user          => $user,
      password      => $password,
      host          => 'localhost',
      allowed_hosts => [
        $controller_1_internal_ip,
        $controller_2_internal_ip,
        $controller_3_internal_ip,
      ],
    }
    $sync_db = true
    Pacemaker::Resource::Ocf['redis'] -> Service <| tag == 'aodh-service' |>
    Pacemaker::Resource::Ocf['rabbitmq'] -> Service <| tag == 'aodh-service' |>

    Exec['aodh-db-sync'] -> Exec["${dbname}-db-ready"]
    Pacemaker::Resource::Ocf['redis'] -> Exec["${dbname}-db-ready"]
    Pacemaker::Resource::Ocf['rabbitmq'] -> Exec["${dbname}-db-ready"]

    exec { "${dbname}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/ssh ${controller_2_internal_ip} 'touch /tmp/.${dbname}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'touch /tmp/.${dbname}-db-ready'",
      unless    => "/bin/ssh ${controller_2_internal_ip} 'touch /tmp/.${dbname}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'touch /tmp/.${dbname}-db-ready'",
    }

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
      region              => $region,
      admin_url           => "http://${admin_alarming_fqdn}:8042",
      public_url          => "http://${public_alarming_fqdn}:8042",
      internal_url        => "http://${internal_alarming_fqdn}:8042",
    }
  } elsif $::hostname =~ /^*controller-\d*$/ {
    $sync_db = false

    Exec["${dbname}-db-ready"] -> Service <| tag == 'aodh-service' |>

    exec { "${dbname}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/ls /tmp/.${dbname}-db-ready",
      unless    => "/bin/ls /tmp/.${dbname}-db-ready",
    }
  }

  class { '::aodh::db':
    database_max_retries    => '-1',
    database_db_max_retries => '-1',
    database_connection     => "mysql+pymysql://${user}:${password}@${internal_fqdn}/${dbname}",
  }

  class { '::aodh':
    log_dir                            => '/var/log/aodh',
    rpc_backend                        => 'rabbit',
    #
    rabbit_hosts                       => [
      "${controller_1_internal_ip}:5672",
      "${controller_2_internal_ip}:5672",
      "${controller_3_internal_ip}:5672",
    ],
    rabbit_use_ssl                     => false,
    rabbit_password                    => $rabbit_password,
    rabbit_userid                      => $rabbit_userid,
    rabbit_ha_queues                   => true,
    rabbit_heartbeat_timeout_threshold => '60',
    #
    purge_config                       => true,
  }

  class { '::aodh::keystone::authtoken':
    auth_uri            => "http://${internal_identity_fqdn}:5000",
    auth_url            => "http://${admin_identity_fqdn}:35357",
    memcached_servers   => [
      "${controller_1_internal_ip}:11211",
      "${controller_2_internal_ip}:11211",
      "${controller_3_internal_ip}:11211",
    ],
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    project_name        => 'services',
    username            => $user,
    password            => $password,
    region_name         => $region,
  }

  class { '::aodh::api':
    # enable_combination_alarms = False
    host                         => $internal_interface,
    port                         => '8042',
    enable_proxy_headers_parsing => true,
    #
    service_name                 => 'httpd',
    auth_strategy                => 'keystone',
    sync_db                      => $sync_db,
  }

  # aodh_config { 'api/enable_combination_alarms': value => false; }

  class { '::aodh::wsgi::apache':
    bind_host => $internal_interface,
    ssl       => false,
  }

  class { '::aodh::auth':
    auth_user         => $user,
    auth_password     => $password,
    auth_url          => "http://${internal_identity_fqdn}:5000",
    auth_region       => $region,
    auth_tenant_name  => 'services',
    project_domain_id => 'default',
    user_domain_id    => 'default',
    auth_type         => 'password',
  }

  class { '::aodh::evaluator':
    coordination_url => "redis://:${redis_password}@${internal_fqdn}:6379",
  }

  class { '::aodh::notifier':
  }

  class { '::aodh::listener':
  }

  class { '::aodh::client':
  }
}
