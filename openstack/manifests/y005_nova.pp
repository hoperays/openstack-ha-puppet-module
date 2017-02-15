class openstack::y005_nova (
  $bootstrap_node    = 'controller-1',
  $nova_password     = 'nova1234',
  $nova_api_password = 'nova_api1234',
  $neutron_password  = 'neutron1234',
  $allowed_hosts     = ['%'],
  $username1         = 'nova',
  $username2         = 'nova_api',
  $controller_vip    = '192.168.0.130',
  $controller_1      = '192.168.0.131',
  $controller_2      = '192.168.0.132',
  $controller_3      = '192.168.0.133',
  $metadata_secret   = 'metadata1234',
  $remote_authkey    = 'remote1234',
  $rbd_secret_uuid   = '2ad6a20f-ffdd-460d-afba-04ab286f365f',
  $openstack_key     = 'AQB+RUpYfv+aIRAA4AbRb+XICXx+x+shF5AeZQ==',) {
  if $::hostname == $bootstrap_node {
    Exec['galera-ready'] ->
    class { '::nova::db::mysql':
      password      => $nova_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    } ->
    class { '::nova::db::mysql_api':
      password      => $nova_api_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    $sync_db = true
    $sync_db_api = true
  } elsif $::hostname =~ /^controller-\d+$/ {
    Anchor['nova::config::end'] ->
    exec { "${username1}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/mysql -e 'show tables from ${username1}'",
      unless    => "/usr/bin/mysql -e 'show tables from ${username1}'",
    } ->
    exec { "${username2}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/mysql -e 'show tables from ${username2}'",
      unless    => "/usr/bin/mysql -e 'show tables from ${username2}'",
    } ->
    Anchor['nova::service::begin']
    $sync_db = false
    $sync_db_api = false
  }

  class { '::nova':
    database_connection                => "mysql+pymysql://nova:${nova_password}@${controller_vip}/nova",
    api_database_connection            => "mysql+pymysql://nova_api:${nova_api_password}@${controller_vip}/nova_api",
    database_max_retries               => '-1',
    rabbit_userid     => 'guest',
    rabbit_password   => 'guest',
    rabbit_ha_queues  => true,
    rabbit_use_ssl    => false,
    rabbit_heartbeat_timeout_threshold => '60',
    rabbit_hosts      => ["${controller_1}:5672", "${controller_2}:5672", "${controller_3}:5672"],
    auth_strategy     => 'keystone',
    #
    glance_api_servers                 => "http://${controller_vip}:9292",
    cinder_catalog_info                => 'volumev2:cinderv2:publicURL',
    log_dir           => '/var/log/nova',
    notify_api_faults => false,
    state_path        => '/var/lib/nova',
    report_interval   => '10',
    image_service     => 'nova.image.glance.GlanceImageService',
    notify_on_state_change             => 'vm_and_task_state',
    use_ipv6          => false,
    cpu_allocation_ratio               => '4.0',
    ram_allocation_ratio               => '1.0',
    disk_allocation_ratio              => '0.8',
    service_down_time => '60',
    host              => $::hostname,
    rootwrap_config   => '/etc/nova/rootwrap.conf',
    rpc_backend       => 'rabbit',
    notification_driver                => 'messagingv2',
    #
    purge_config      => true,
  }

  class { '::nova::cache':
    enabled          => true,
    backend          => 'oslo_cache.memcache_pool',
    memcache_servers => ["${controller_1}:11211", "${controller_2}:11211", "${controller_3}:11211"],
  }

  class { '::nova::network::neutron':
    neutron_auth_url                => "http://${controller_vip}:35357/v3",
    neutron_url                     => "http://${controller_vip}:9696",
    #
    neutron_auth_type               => 'v3password',
    neutron_project_domain_name     => 'default',
    neutron_user_domain_name        => 'default',
    neutron_region_name             => 'RegionOne',
    neutron_project_name            => 'services',
    neutron_username                => 'neutron',
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

  if $::hostname =~ /^controller-\d+$/ {
    class { '::nova::keystone::authtoken':
      auth_uri            => "http://${controller_vip}:5000/",
      auth_url            => "http://${controller_vip}:35357/",
      memcached_servers   => ["${controller_1}:11211", "${controller_2}:11211", "${controller_3}:11211"],
      auth_type           => 'password',
      project_domain_name => 'default',
      user_domain_name    => 'default',
      region_name         => 'RegionOne',
      project_name        => 'services',
      username            => 'nova',
      password            => $nova_password,
    }

    class { '::nova::api':
      api_bind_address       => $ipaddress_eth0,
      osapi_compute_listen_port            => '8774',
      metadata_listen        => $ipaddress_eth0,
      metadata_listen_port   => '8775',
      enabled_apis           => ['osapi_compute', 'metadata'],
      neutron_metadata_proxy_shared_secret => $metadata_secret,
      instance_name_template => 'instance-%08x',
      default_floating_pool  => 'public',
      use_forwarded_for      => 'false',
      # osapi_compute_workers              => $::processorcount,
      # metadata_workers                   => $::processorcount,
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

    class { '::nova::scheduler':
    }

    class { '::nova::vncproxy':
      host => $::ipaddress_eth0,
      port => '6080',
    }
  } elsif $::hostname =~ /^compute-\d+$/ {
    class { '::nova::compute':
      vnc_enabled          => true,
      vncserver_proxyclient_address     => $ipaddress_eth0,
      vncproxy_host        => $controller_vip,
      vncproxy_protocol    => 'http',
      vncproxy_port        => '6080',
      vncproxy_path        => '/vnc_auto.html',
      vnc_keymap           => 'en-us',
      reserved_host_memory => '2048', # MB
      heal_instance_info_cache_interval => '60',
      allow_resize_to_same_host         => true,
      resume_guests_state_on_host_boot  => true,
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
      password            => $nova_password,
      auth_name           => 'nova',
      service_name        => 'nova',
      service_description => 'Openstack Compute Service',
      region              => 'RegionOne',
      tenant              => 'services',
      email               => 'nova@localhost',
      public_url          => "http://${controller_vip}:8774/v2.1",
      internal_url        => "http://${controller_vip}:8774/v2.1",
      admin_url           => "http://${controller_vip}:8774/v2.1",
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
    }
  }
}
