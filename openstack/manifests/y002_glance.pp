class openstack::y002_glance (
  $bootstrap_node  = 'controller-1',
  $glance_password = 'glance1234',
  $allowed_hosts   = ['%'],
  $username        = 'glance',
  $controller_vip  = '192.168.0.130',
  $controller_1    = '192.168.0.131',
  $controller_2    = '192.168.0.132',
  $controller_3    = '192.168.0.133',) {
  if $::hostname == $bootstrap_node {
    Exec['galera-ready'] ->
    class { '::glance::db::mysql':
      password      => $glance_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    $sync_db = true
    Anchor['glance::dbsync::end'] ->
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
    Anchor['glance::config::end'] ->
    exec { "${username}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/cat /tmp/${username}-db-ready | grep ok",
      unless    => "/usr/bin/cat /tmp/${username}-db-ready | grep ok",
    } ->
    Anchor['glance::service::begin'] ->
    exec { "${username}-db-ready-rm":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/rm -f /tmp/${username}-db-ready",
      unless    => "/usr/bin/rm -f /tmp/${username}-db-ready",
    }
  }

  class { '::glance::api::authtoken':
    auth_uri            => "http://${controller_vip}:5000/v2.0",
    auth_url            => "http://${controller_vip}:35357",
    memcached_servers   => ["${controller_1}:11211", "${controller_2}:11211", "${controller_3}:11211"],
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    project_name        => 'services',
    username            => 'glance',
    password            => $glance_password,
  }

  class { '::glance::api':
    show_image_direct_url        => true,
    show_multiple_locations      => true,
    bind_host       => $::ipaddress_eth0,
    bind_port       => '9292',
    # workers       => $::processorcount,
    image_cache_dir => '/var/lib/glance/image-cache',
    registry_host   => $controller_vip,
    registry_client_protocol     => 'http',
    log_file        => '/var/log/glance/api.log',
    log_dir         => '/var/log/glance',
    # rpc_backend   => 'rabbit',
    database_connection          => "mysql+pymysql://glance:${glance_password}@${controller_vip}/glance",
    #
    stores          => ['glance.store.http.Store', 'glance.store.rbd.Store'],
    default_store   => 'rbd',
    os_region_name  => 'RegionOne',
    #
    enable_proxy_headers_parsing => true,
    pipeline        => 'keystone',
    auth_strategy   => 'keystone',
    #
    multi_store     => true,
    #
    purge_config    => true,
  }

  class { '::glance::notify::rabbitmq':
    rabbit_hosts        => ["${controller_1}:5672", "${controller_2}:5672", "${controller_3}:5672"],
    rabbit_use_ssl      => false,
    rabbit_password     => 'guest',
    rabbit_userid       => 'guest',
    rabbit_ha_queues    => true,
    notification_driver => 'messagingv2',
  }

  class { '::glance::backend::rbd':
    rbd_store_pool       => 'images',
    rbd_store_user       => 'openstack',
    rbd_store_ceph_conf  => '/etc/ceph/ceph.conf',
    rbd_store_chunk_size => '8',
    multi_store          => true,
    glare_enabled        => false,
  }

  class { '::glance::registry::authtoken':
    auth_uri            => "http://${controller_vip}:5000/v2.0",
    auth_url            => "http://${controller_vip}:35357",
    memcached_servers   => ["${controller_1}:11211", "${controller_2}:11211", "${controller_3}:11211"],
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    project_name        => 'services',
    username            => 'glance',
    password            => $glance_password,
  }

  class { '::glance::registry::db':
    database_max_retries    => '-1',
    database_db_max_retries => '-1',
    database_connection     => "mysql+pymysql://glance:${glance_password}@${controller_vip}/glance",
  }

  class { '::glance::registry':
    bind_host     => $::ipaddress_eth0,
    bind_port     => '9191',
    # workers            => $::processorcount,
    log_file      => '/var/log/glance/registry.log',
    log_dir       => '/var/log/glance',
    # rpc_backend        => 'rabbit',
    #
    pipeline      => 'keystone',
    auth_strategy => 'keystone',
    #
    sync_db       => $sync_db,
    #
    purge_config  => true,
  }

  if $::hostname == $bootstrap_node {
    class { '::glance::keystone::auth':
      email               => 'glance@localhost',
      password            => $glance_password,
      auth_name           => 'glance',
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
      service_name        => 'glance',
      service_type        => 'image',
      region              => 'RegionOne',
      tenant              => 'services',
      service_description => 'OpenStack Image Service',
      public_url          => "http://${controller_vip}:9292",
      admin_url           => "http://${controller_vip}:9292",
      internal_url        => "http://${controller_vip}:9292",
    }
  }
}
