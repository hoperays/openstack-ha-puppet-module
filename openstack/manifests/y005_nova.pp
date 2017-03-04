class openstack::y005_nova (
  $bootstrap_node             = hiera('controller_1_hostname'),
  $rabbit_userid              = hiera('rabbit_username'),
  $rabbit_password            = hiera('rabbit_password'),
  $email_1                    = hiera('nova_email'),
  $dbname_1                   = hiera('nova_dbname'),
  $user_1                     = hiera('nova_username'),
  $password_1                 = hiera('nova_password'),
  $dbname_2                   = hiera('nova_api_dbname'),
  $user_2                     = hiera('nova_api_username'),
  $password_2                 = hiera('nova_api_password'),
  $public_vip                 = hiera('public_vip'),
  $internal_vip               = hiera('internal_vip'),
  $controller_1_internal_ip   = hiera('controller_1_internal_ip'),
  $controller_2_internal_ip   = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip   = hiera('controller_3_internal_ip'),
  $internal_interface         = hiera('internal_interface'),
  $metadata_secret            = hiera('metadata_secret'),
  $neutron_username           = hiera('neutron_username'),
  $neutron_password           = hiera('neutron_password'),
  $remote_authkey             = hiera('remote_authkey'),
  $rbd_secret_uuid            = hiera('rbd_secret_uuid'),
  $cpu_allocation_ratio       = '',
  $ram_allocation_ratio       = '',
  $disk_allocation_ratio      = '',
  $openstack_key              = '',
  $reserved_host_memory       = '',
  $controller_as_novacompute  = hiera('controller_as_novacompute'),
) {
  if $::hostname == $bootstrap_node {
    class { '::nova::db::mysql':
      dbname        => $dbname_1,
      user          => $user_1,
      password      => $password_1,
      host          => 'localhost',
      allowed_hosts => [$controller_1_internal_ip, $controller_2_internal_ip, $controller_3_internal_ip],
    } ->
    class { '::nova::db::mysql_api':
      dbname        => $dbname_2,
      user          => $user_2,
      password      => $password_2,
      host          => 'localhost',
      allowed_hosts => [$controller_1_internal_ip, $controller_2_internal_ip, $controller_3_internal_ip],
    }
    $sync_db = true
    $sync_db_api = true
    Anchor['nova::dbsync::end'] ->
    exec { "${dbname_1}-db-ready-echo":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/ssh ${controller_2_internal_ip} 'echo ok > /tmp/${dbname_1}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'echo ok > /tmp/${dbname_1}-db-ready'",
      unless    => "/bin/ssh ${controller_2_internal_ip} 'echo ok > /tmp/${dbname_1}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'echo ok > /tmp/${dbname_1}-db-ready'",
    }
    Anchor['nova::dbsync_api::end'] ->
    exec { "${dbname_2}-db-ready-echo":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/ssh ${controller_2_internal_ip} 'echo ok > /tmp/${dbname_2}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'echo ok > /tmp/${dbname_2}-db-ready'",
      unless    => "/bin/ssh ${controller_2_internal_ip} 'echo ok > /tmp/${dbname_2}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'echo ok > /tmp/${dbname_2}-db-ready'",
    }
  } elsif $::hostname =~ /^*controller-\d*$/ {
    $sync_db = false
    $sync_db_api = false
    Anchor['nova::config::end'] ->
    exec { "${dbname_1}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/cat /tmp/${dbname_1}-db-ready | grep ok",
      unless    => "/bin/cat /tmp/${dbname_1}-db-ready | grep ok",
    } ->
    exec { "${dbname_2}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/cat /tmp/${dbname_2}-db-ready | grep ok",
      unless    => "/bin/cat /tmp/${dbname_2}-db-ready | grep ok",
    } ->
    Anchor['nova::service::begin'] ->
    exec { "${dbname_1}-db-ready-rm":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/rm -f /tmp/${dbname_1}-db-ready",
      unless    => "/bin/rm -f /tmp/${dbname_1}-db-ready",
    } ->
    exec { "${dbname_2}-db-ready-rm":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/rm -f /tmp/${dbname_2}-db-ready",
      unless    => "/bin/rm -f /tmp/${dbname_2}-db-ready",
    }
  }

  class { '::nova::db':
    database_max_retries    => '-1',
    database_db_max_retries => '-1',
    database_connection     => "mysql+pymysql://${user_1}:${password_1}@${internal_vip}/${dbname_1}",
    api_database_connection => "mysql+pymysql://${user_2}:${password_2}@${internal_vip}/${dbname_2}",
  }

  class { '::nova':
    rabbit_userid          => $rabbit_userid,
    rabbit_password        => $rabbit_password,
    rabbit_ha_queues       => true,
    rabbit_use_ssl         => false,
    rabbit_heartbeat_timeout_threshold => '60',
    rabbit_hosts           => [
      "${controller_1_internal_ip}:5672",
      "${controller_2_internal_ip}:5672",
      "${controller_3_internal_ip}:5672"],
    auth_strategy          => 'keystone',
    #
    glance_api_servers     => "http://${internal_vip}:9292",
    cinder_catalog_info    => 'volumev2:cinderv2:publicURL',
    log_dir                => '/var/log/nova',
    notify_api_faults      => false,
    state_path             => '/var/lib/nova',
    report_interval        => '10',
    image_service          => 'nova.image.glance.GlanceImageService',
    notify_on_state_change => 'vm_and_task_state',
    use_ipv6               => false,
    cpu_allocation_ratio   => $cpu_allocation_ratio,
    ram_allocation_ratio   => $ram_allocation_ratio,
    disk_allocation_ratio  => $disk_allocation_ratio,
    service_down_time      => '60',
    host                   => $::hostname,
    rootwrap_config        => '/etc/nova/rootwrap.conf',
    rpc_backend            => 'rabbit',
    notification_driver    => 'messagingv2',
    #
    purge_config           => true,
  }

  class { '::nova::cache':
    enabled          => true,
    backend          => 'oslo_cache.memcache_pool',
    memcache_servers => [
      "${controller_1_internal_ip}:11211",
      "${controller_2_internal_ip}:11211",
      "${controller_3_internal_ip}:11211"],
  }

  class { '::nova::network::neutron':
    neutron_auth_url                => "http://${internal_vip}:35357/v3",
    neutron_url                     => "http://${internal_vip}:9696",
    #
    neutron_auth_type               => 'v3password',
    neutron_project_domain_name     => 'default',
    neutron_user_domain_name        => 'default',
    neutron_region_name             => 'RegionOne',
    neutron_project_name            => 'services',
    neutron_username                => $neutron_username,
    neutron_password                => $neutron_password,
    #
    neutron_url_timeout             => '30',
    neutron_ovs_bridge              => 'br-int',
    neutron_extension_sync_interval => '600',
    firewall_driver                 => 'nova.virt.firewall.NoopFirewallDriver',
    vif_plugging_is_fatal           => true, # false
    vif_plugging_timeout            => '300', # 0
    dhcp_domain                     => 'novalocal',
  }

  if $::hostname =~ /^*controller-\d*$/ {
    class { '::nova::keystone::authtoken':
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
      username            => $user_1,
      password            => $password_1,
    }

    class { '::nova::api':
      api_bind_address       => $internal_interface,
      osapi_compute_listen_port            => '8774',
      metadata_listen        => $internal_interface,
      metadata_listen_port   => '8775',
      enabled_apis           => ['osapi_compute', 'metadata'],
      neutron_metadata_proxy_shared_secret => $metadata_secret,
      instance_name_template => 'instance-%08x',
      default_floating_pool  => 'public',
      use_forwarded_for      => 'false',
      allow_resize_to_same_host            => true,
      fping_path             => '/usr/sbin/fping',
      enable_proxy_headers_parsing         => true,
      #
      sync_db                => $sync_db,
      sync_db_api            => $sync_db_api,
    }

    class { '::nova::conductor':
    }

    class { '::nova::consoleauth':
    }

    class { '::nova::scheduler::filter':
      scheduler_host_manager          => 'host_manager',
      scheduler_max_attempts          => '3',
      scheduler_host_subset_size      => '1',
      max_io_ops_per_host             => '8',
      max_instances_per_host          => '50',
      scheduler_weight_classes        => 'nova.scheduler.weights.all_weighers',
      scheduler_use_baremetal_filters => false,
    }

    class { '::nova::scheduler':
    }

    class { '::nova::vncproxy::common':
      vncproxy_host     => $public_vip,
      vncproxy_protocol => 'https',
      vncproxy_port     => '13080',
      vncproxy_path     => '/vnc_auto.html',
    }

    class { '::nova::vncproxy':
      host => $internal_interface,
      port => '6080',
    }
  }

  if $::hostname =~ /^*novacompute-\d*$/ or $controller_as_novacompute {
    class { '::nova::compute':
      vnc_enabled                       => true,
      vncserver_proxyclient_address     => $internal_interface,
      vncproxy_host                     => $public_vip,
      vncproxy_protocol                 => 'https',
      vncproxy_port                     => '13080',
      vncproxy_path                     => '/vnc_auto.html',
      vnc_keymap                        => 'en-us',
      reserved_host_memory              => $reserved_host_memory, # MB
      heal_instance_info_cache_interval => '60',
      allow_resize_to_same_host         => true,
      resume_guests_state_on_host_boot  => true,
      #
      instance_usage_audit              => true,
      instance_usage_audit_period       => 'hour',
    }

    class { '::nova::compute::libvirt':
      libvirt_virt_type        => 'kvm',
      vncserver_listen         => '0.0.0.0',
      migration_support        => true,
      libvirt_cpu_mode         => 'host-model', # 'custom'
      libvirt_cpu_model        => undef, # 'core2duo'
      libvirt_disk_cachemodes  => ['network=writeback'],
      libvirt_hw_disk_discard  => 'unmap',
      libvirt_inject_password  => false,
      libvirt_inject_key       => false,
      libvirt_inject_partition => -2,
      #
      manage_libvirt_services  => true,
    }

    class { '::nova::compute::rbd':
      libvirt_rbd_user             => 'openstack',
      libvirt_rbd_secret_uuid      => $rbd_secret_uuid,
      libvirt_rbd_secret_key       => $openstack_key,
      libvirt_images_rbd_pool      => 'vms',
      libvirt_images_rbd_ceph_conf => '/etc/ceph/ceph.conf',
      rbd_keyring                  => 'client.openstack',
      ephemeral_storage            => true,
      manage_ceph_client           => false,
    }
  }

  if $::hostname == $bootstrap_node {
    class { '::nova::keystone::auth':
      password            => $password_1,
      auth_name           => $user_1,
      service_name        => 'nova',
      service_description => 'Openstack Compute Service',
      region              => 'RegionOne',
      tenant              => 'services',
      email               => $email_1,
      public_url          => "http://${public_vip}:8774/v2.1",
      internal_url        => "http://${internal_vip}:8774/v2.1",
      admin_url           => "http://${internal_vip}:8774/v2.1",
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
    }
  }
}
