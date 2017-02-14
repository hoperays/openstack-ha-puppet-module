class openstack::y003_cinder (
  $bootstrap_node  = 'controller-1',
  $cinder_password = 'cinder1234',
  $allowed_hosts   = ['%'],
  $username        = 'cinder',
  $controller_vip  = '192.168.0.130',
  $controller_1    = '192.168.0.131',
  $controller_2    = '192.168.0.132',
  $controller_3    = '192.168.0.133',
  $rbd_secret_uuid = '2ad6a20f-ffdd-460d-afba-04ab286f365f',) {
  if $::hostname == $bootstrap_node {
    class { '::cinder::db::mysql':
      password      => $cinder_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    $sync_db = true
  } else {
    exec { "${username}-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/mysql -e 'select user,host,password from mysql.user where user=\"${username}\";' | /usr/bin/grep \"${username}\"",
      unless    => "/usr/bin/mysql -e 'select user,host,password from mysql.user where user=\"${username}\";' | /usr/bin/grep \"${username}\"",
    }
    $sync_db = false
  }

  class { '::cinder':
    enable_v3_api    => true,
    host             => 'hostgroup',
    storage_availability_zone          => 'nova',
    default_availability_zone          => 'nova',
    log_dir          => '/var/log/cinder',
    rpc_backend      => 'rabbit',
    control_exchange => 'openstack',
    api_paste_config => '/etc/cinder/api-paste.ini',
    database_connection                => "mysql+pymysql://cinder:${cinder_password}@${controller_vip}/cinder",
    database_max_retries               => '-1',
    lock_path        => '/var/lib/cinder/tmp',
    #
    rabbit_hosts     => ["${controller_1}:5672", "${controller_2}:5672", "${controller_3}:5672"],
    rabbit_use_ssl   => false,
    rabbit_password  => 'guest',
    rabbit_userid    => 'guest',
    rabbit_ha_queues => true,
    rabbit_heartbeat_timeout_threshold => '60',
    #
    purge_config     => true,
  }

  class { '::cinder::api':
    bind_host           => $::ipaddress_eth0, # osapi_volume_listen
    # service_workers   => $::processorcount, # osapi_volume_workers
    default_volume_type => 'rbd',
    nova_catalog_info   => 'compute:Compute Service:publicURL',
    nova_catalog_admin_info      => 'compute:Compute Service:adminURL',
    #
    keystone_enabled    => false,
    auth_strategy       => false,
    enable_proxy_headers_parsing => true,
    #
    sync_db             => $sync_db,
  }

  class { '::cinder::keystone::authtoken':
    auth_uri            => "http://${controller_vip}:5000/",
    auth_url            => "http://${controller_vip}:35357/",
    memcached_servers   => ["${controller_1}:11211", "${controller_2}:11211", "${controller_3}:11211"],
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    project_name        => 'services',
    username            => 'cinder',
    password            => $cinder_password,
  }

  class { '::cinder::scheduler':
    scheduler_driver => 'cinder.scheduler.filter_scheduler.FilterScheduler',
  }

  class { '::cinder::glance':
    glance_api_servers => "http://${controller_vip}:9292",
    glance_api_version => '2',
  }

  ::cinder::backend::rbd { 'rbd':
    rbd_pool              => 'volumes',
    backend_host          => 'hostgroup',
    rbd_secret_uuid       => $rbd_secret_uuid,
    volume_backend_name   => 'rbd',
    rbd_user              => 'openstack',
    rbd_ceph_conf         => '/etc/ceph/ceph.conf',
    rbd_flatten_volume_from_snapshot => false,
    rbd_max_clone_depth   => '5',
    rbd_store_chunk_size  => '4',
    rados_connect_timeout => '-1',
  }

  class { '::cinder::volume':
    manage_service => false,
    enabled        => false,
  }

  class { '::cinder::backup':
    manage_service => false,
    enabled        => false,
  }

  class { '::cinder::backup::ceph':
    backup_driver            => 'cinder.backup.drivers.ceph',
    backup_ceph_conf         => '/etc/ceph/ceph.conf',
    backup_ceph_user         => 'cinder-backup',
    backup_ceph_chunk_size   => '134217728',
    backup_ceph_pool         => 'backups',
    backup_ceph_stripe_unit  => '0',
    backup_ceph_stripe_count => '0'
  }

  cinder_config {
    'DEFAULT/auth_strategy':
      value => 'keystone';

    'DEFAULT/restore_discard_excess_bytes':
      value => true;

    'DEFAULT/enabled_backends':
      value => 'rbd';
  }

  if $::hostname == $bootstrap_node {
    class { '::cinder::keystone::auth':
      password               => $cinder_password,
      password_user_v2       => undef,
      password_user_v3       => undef,
      auth_name              => 'cinder',
      auth_name_v2           => 'cinderv2',
      auth_name_v3           => 'cinderv3',
      tenant                 => 'services',
      tenant_user_v2         => 'services',
      tenant_user_v3         => 'services',
      email                  => 'cinder@example.com',
      email_user_v2          => undef,
      email_user_v3          => undef,
      public_url             => "http://${controller_vip}:8776/v1/%(tenant_id)s",
      internal_url           => "http://${controller_vip}:8776/v1/%(tenant_id)s",
      admin_url              => "http://${controller_vip}:8776/v1/%(tenant_id)s",
      public_url_v2          => "http://${controller_vip}:8776/v2/%(tenant_id)s",
      internal_url_v2        => "http://${controller_vip}:8776/v2/%(tenant_id)s",
      admin_url_v2           => "http://${controller_vip}:8776/v2/%(tenant_id)s",
      public_url_v3          => "http://${controller_vip}:8776/v3/%(tenant_id)s",
      internal_url_v3        => "http://${controller_vip}:8776/v3/%(tenant_id)s",
      admin_url_v3           => "http://${controller_vip}:8776/v3/%(tenant_id)s",
      configure_endpoint     => true,
      configure_endpoint_v2  => true,
      configure_endpoint_v3  => true,
      configure_user         => true,
      configure_user_v2      => false,
      configure_user_v3      => false,
      configure_user_role    => true,
      configure_user_role_v2 => false,
      configure_user_role_v3 => false,
      service_name           => 'cinder',
      service_name_v2        => 'cinderv2',
      service_name_v3        => 'cinderv3',
      service_type           => 'volume',
      service_type_v2        => 'volumev2',
      service_type_v3        => 'volumev3',
      service_description    => 'Cinder Service',
      service_description_v2 => 'Cinder Service v2',
      service_description_v3 => 'Cinder Service v3',
      region                 => 'RegionOne',
    } ->
    pacemaker::resource::service { 'openstack-cinder-volume': op_params => 'start timeout=200s stop timeout=200s', } ->
    pacemaker::resource::service { 'openstack-cinder-backup': op_params => 'start timeout=200s stop timeout=200s', } ->
    cinder_type { 'rbd':
      ensure     => present,
      properties => ["volume_backend_name=rbd"],
    }
  }
}
