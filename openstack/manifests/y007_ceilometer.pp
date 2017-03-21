class openstack::y007_ceilometer (
  $bootstrap_node            = hiera('controller_1_hostname'),
  $rabbit_userid             = hiera('rabbit_username'),
  $rabbit_password           = hiera('rabbit_password'),
  $email                     = hiera('ceilometer_email'),
  $dbname                    = hiera('ceilometer_dbname'),
  $user                      = hiera('ceilometer_username'),
  $password                  = hiera('ceilometer_password'),
  $admin_identity_fqdn      = join(any2array([
    hiera('admin_identity'),
    hiera('domain_name')]), '.'),
  $public_identity_fqdn     = join(any2array([
    hiera('public_identity'),
    hiera('domain_name')]), '.'),
  $internal_identity_fqdn   = join(any2array([
    hiera('internal_identity'),
    hiera('domain_name')]), '.'),
  $admin_api_fqdn           = join(any2array([
    hiera('admin_api'),
    hiera('region_name'),
    hiera('domain_name')]), '.'),
  $public_api_fqdn          = join(any2array([
    hiera('public_api'),
    hiera('region_name'),
    hiera('domain_name')]), '.'),
  $internal_api_fqdn        = join(any2array([
    hiera('internal_api'),
    hiera('region_name'),
    hiera('domain_name')]), '.'),
  $controller_1_internal_ip  = hiera('controller_1_internal_ip'),
  $controller_2_internal_ip  = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip  = hiera('controller_3_internal_ip'),
  $internal_interface        = hiera('internal_interface'),
  $redis_password            = hiera('redis_password'),
  $telemetry_secret          = hiera('telemetry_secret'),
  $replicaset                = join(any2array([
    hiera('cloud_name'),
    hiera('region_name')]), '-'),
  $controller_as_novacompute = hiera('controller_as_novacompute'),
  $region                    = hiera('region_name'),
) {
  if $::hostname == $bootstrap_node {
    $sync_db = true

    class { '::ceilometer::keystone::auth':
      password            => $password,
      email               => $email,
      auth_name           => $user,
      configure_user      => true,
      configure_user_role => true,
      service_name        => 'ceilometer',
      service_type        => 'metering',
      service_description => 'Openstack Metering Service',
      region              => $region,
      tenant              => 'services',
      configure_endpoint  => true,
      admin_url           => "http://${admin_api_fqdn}:8777",
      public_url          => "http://${public_api_fqdn}:8777",
      internal_url        => "http://${internal_api_fqdn}:8777",
    }
  } elsif $::hostname =~ /^*controller-\d*$/ {
    $sync_db = false
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
    rabbit_hosts          => [
      "${controller_1_internal_ip}:5672",
      "${controller_2_internal_ip}:5672",
      "${controller_3_internal_ip}:5672"],
    rabbit_use_ssl        => false,
    rabbit_password       => $rabbit_password,
    rabbit_userid         => $rabbit_userid,
    rabbit_ha_queues      => true,
    rabbit_heartbeat_timeout_threshold => '60',
    #
    purge_config          => true,
  }

  class { '::ceilometer::agent::auth':
    auth_url                 => "http://${internal_identity_fqdn}:5000",
    auth_endpoint_type       => 'internalURL',
    auth_type                => 'password',
    auth_user_domain_name    => 'default',
    auth_project_domain_name => 'default',
    auth_region              => $region,
    auth_tenant_name         => 'services',
    auth_user                => $user,
    auth_password            => $password,
  }

  if $::hostname =~ /^*controller-\d*$/ {
    class { '::ceilometer::db':
      database_max_retries    => '-1',
      database_db_max_retries => '-1',
      database_connection     => "mongodb://${controller_1_internal_ip}:27017,${controller_2_internal_ip}:27017,${controller_3_internal_ip}:27017/${dbname}?replicaSet=${replicaset}",
      sync_db                 => $sync_db,
    }

    class { '::ceilometer::client':
    }

    class { '::ceilometer::agent::central':
      coordination_url => "redis://:${redis_password}@${internal_api_fqdn}:6379",
    }

    class { '::ceilometer::agent::notification':
      ack_on_event_error => true,
      store_events       => false,
    }

    class { '::ceilometer::keystone::authtoken':
      auth_uri            => "http://${internal_identity_fqdn}:5000",
      auth_url            => "http://${admin_identity_fqdn}:35357",
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
      region_name         => $region,
    }

    class { '::ceilometer::api':
      host          => $internal_interface,
      port          => '8777',
      enable_proxy_headers_parsing => true,
      #
      service_name  => 'httpd',
      auth_strategy => 'keystone',
    }

    class { '::ceilometer::wsgi::apache':
      bind_host => $internal_interface,
      ssl       => false,
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
      url            => "http://${internal_api_fqdn}:8041",
    }

    exec { "disable-metering-panel":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/echo -e '\n# Disable metering panel when using gnocchi\nREMOVE_PANEL = True' >> \
                    /usr/share/openstack-dashboard/openstack_dashboard/enabled/_2030_admin_metering_panel.py",
      unless    => "/bin/cat /usr/share/openstack-dashboard/openstack_dashboard/enabled/_2030_admin_metering_panel.py | \
                    grep 'REMOVE_PANEL = True'",
    }
  }

  if $::hostname =~ /^*novacompute-\d*$/ or $controller_as_novacompute {
    class { '::ceilometer::agent::compute': }
  }
}
