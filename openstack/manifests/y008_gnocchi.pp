class openstack::y008_gnocchi (
  $bootstrap_node           = hiera('controller_1_hostname'),
  $email                    = hiera('gnocchi_email'),
  $dbname                   = hiera('gnocchi_dbname'),
  $user                     = hiera('gnocchi_username'),
  $password                 = hiera('gnocchi_password'),
  $admin_identity_fqdn      = hiera('admin_identity_fqdn'),
  $public_identity_fqdn     = hiera('public_identity_fqdn'),
  $internal_identity_fqdn   = hiera('internal_identity_fqdn'),
  $admin_metric_fqdn        = hiera('admin_metric_fqdn'),
  $public_metric_fqdn       = hiera('public_metric_fqdn'),
  $internal_metric_fqdn     = hiera('internal_metric_fqdn'),
  $internal_fqdn            = hiera('internal_fqdn'),
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
  $region                   = hiera('region_name'),
) {
  if $::hostname == $bootstrap_node {
    class { '::gnocchi::db::mysql':
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
    Pacemaker::Resource::Ocf['redis'] -> Exec['gnocchi-db-sync']

    Exec['gnocchi-db-sync'] -> Exec["${dbname}-db-ready"]

    exec { "${dbname}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/ssh ${controller_2_internal_ip} 'touch /tmp/.${dbname}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'touch /tmp/.${dbname}-db-ready'",
      unless    => "/bin/ssh ${controller_2_internal_ip} 'touch /tmp/.${dbname}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'touch /tmp/.${dbname}-db-ready'",
    }

    class { '::gnocchi::keystone::auth':
      password            => $password,
      auth_name           => $user,
      email               => $email,
      tenant              => 'services',
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
      service_name        => 'gnocchi',
      service_type        => 'metric',
      region              => $region,
      admin_url           => "http://${admin_metric_fqdn}:8041",
      public_url          => "http://${public_metric_fqdn}:8041",
      internal_url        => "http://${internal_metric_fqdn}:8041",
      service_description => 'Openstack Metric Service',
    }
  } elsif $::hostname =~ /^*controller-\d*$/ {
    $sync_db = false

    Exec["${dbname}-db-ready"] -> Service <| tag == 'gnocchi-service' |>

    exec { "${dbname}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/ls /tmp/.${dbname}-db-ready",
      unless    => "/bin/ls /tmp/.${dbname}-db-ready",
    }
  }

  class { '::gnocchi':
    log_dir             => '/var/log/gnocchi',
    database_connection => "mysql+pymysql://${user}:${password}@${internal_fqdn}/${dbname}",
    #
    purge_config        => true,
  }

  class { '::gnocchi::keystone::authtoken':
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

  class { '::gnocchi::api':
    max_limit                    => '1000',
    host                         => $internal_interface,
    port                         => '8041',
    enable_proxy_headers_parsing => true,
    #
    service_name                 => 'httpd',
    auth_strategy                => 'keystone',
    sync_db                      => $sync_db,
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
    coordination_url => "redis://:${redis_password}@${internal_fqdn}:6379",
  }

  class { '::gnocchi::storage::ceph':
    ceph_pool     => 'metrics',
    ceph_username => 'openstack',
    ceph_keyring  => '/etc/ceph/ceph.client.openstack.keyring',
    ceph_conffile => '/etc/ceph/ceph.conf',
  }

  class { '::gnocchi::client':
  }
}
