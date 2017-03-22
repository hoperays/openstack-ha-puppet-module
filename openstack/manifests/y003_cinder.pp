class openstack::y003_cinder (
  $bootstrap_node           = hiera('controller_1_hostname'),
  $rabbit_userid            = hiera('rabbit_username'),
  $rabbit_password          = hiera('rabbit_password'),
  $email                    = hiera('cinder_email'),
  $dbname                   = hiera('cinder_dbname'),
  $user                     = hiera('cinder_username'),
  $password                 = hiera('cinder_password'),
  $admin_identity_fqdn      = join(any2array([
    'admin.identity',
    hiera('domain_name')]), '.'),
  $public_identity_fqdn     = join(any2array([
    'public.identity',
    hiera('domain_name')]), '.'),
  $internal_identity_fqdn   = join(any2array([
    'internal.identity',
    hiera('domain_name')]), '.'),
  $admin_volume_fqdn        = join(any2array([
    'admin.volume',
    hiera('region_name'),
    hiera('domain_name')]), '.'),
  $public_volume_fqdn       = join(any2array([
    'public.volume',
    hiera('region_name'),
    hiera('domain_name')]), '.'),
  $internal_volume_fqdn     = join(any2array([
    'internal.volume',
    hiera('region_name'),
    hiera('domain_name')]), '.'),
  $internal_fqdn            = join(any2array([
    'internal',
    hiera('region_name'),
    hiera('domain_name')]), '.'),
  $internal_image_fqdn      = join(any2array([
    'internal.image',
    hiera('region_name'),
    hiera('domain_name')]), '.'),
  $controller_1_internal_ip = hiera('controller_1_internal_ip'),
  $controller_2_internal_ip = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip = hiera('controller_3_internal_ip'),
  $internal_interface       = hiera('internal_interface'),
  $rbd_secret_uuid          = hiera('rbd_secret_uuid'),
  $backend_host             = join(any2array([
    hiera('cloud_name'),
    hiera('region_name')]), '-'),
  $region                   = hiera('region_name'),
) {
  if $::hostname == $bootstrap_node {
    class { '::cinder::db::mysql':
      dbname        => $dbname,
      user          => $user,
      password      => $password,
      host          => 'localhost',
      allowed_hosts => [$controller_1_internal_ip, $controller_2_internal_ip, $controller_3_internal_ip],
    }
    $sync_db = true

    Anchor['cinder::dbsync::end'] ->
    exec { "${dbname}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/ssh ${controller_2_internal_ip} 'touch /tmp/.${dbname}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'touch /tmp/.${dbname}-db-ready'",
      unless    => "/bin/ssh ${controller_2_internal_ip} 'touch /tmp/.${dbname}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'touch /tmp/.${dbname}-db-ready'",
    }

    class { '::cinder::keystone::auth':
      password               => $password,
      password_user_v2       => undef,
      password_user_v3       => undef,
      auth_name              => $user,
      auth_name_v2           => 'cinderv2',
      auth_name_v3           => 'cinderv3',
      tenant                 => 'services',
      tenant_user_v2         => 'services',
      tenant_user_v3         => 'services',
      email                  => $email,
      email_user_v2          => undef,
      email_user_v3          => undef,
      admin_url              => "http://${admin_volume_fqdn}:8776/v1/%(tenant_id)s",
      public_url             => "http://${public_volume_fqdn}:8776/v1/%(tenant_id)s",
      internal_url           => "http://${internal_volume_fqdn}:8776/v1/%(tenant_id)s",
      admin_url_v2           => "http://${admin_volume_fqdn}:8776/v2/%(tenant_id)s",
      public_url_v2          => "http://${public_volume_fqdn}:8776/v2/%(tenant_id)s",
      internal_url_v2        => "http://${internal_volume_fqdn}:8776/v2/%(tenant_id)s",
      admin_url_v3           => "http://${admin_volume_fqdn}:8776/v3/%(tenant_id)s",
      public_url_v3          => "http://${public_volume_fqdn}:8776/v3/%(tenant_id)s",
      internal_url_v3        => "http://${internal_volume_fqdn}:8776/v3/%(tenant_id)s",
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
      region                 => $region,
    }

    Anchor['cinder::dbsync::end'] ->
    pacemaker::resource::service { 'openstack-cinder-volume':
      op_params => 'start timeout=200s stop timeout=200s',
    } ->
    pacemaker::resource::service { 'openstack-cinder-backup':
      op_params => 'start timeout=200s stop timeout=200s',
    } ->
    cinder_type { 'rbd':
      ensure     => present,
      properties => ["volume_backend_name=rbd"],
    }
  } elsif $::hostname =~ /^*controller-\d*$/ {
    $sync_db = false

    Anchor['cinder::config::end'] ->
    exec { "${dbname}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/ls /tmp/.${dbname}-db-ready",
      unless    => "/bin/ls /tmp/.${dbname}-db-ready",
    } ->
    Anchor['cinder::service::begin']
  }

  class { '::cinder::db':
    database_max_retries    => '-1',
    database_db_max_retries => '-1',
    database_connection     => "mysql+pymysql://${user}:${password}@${internal_fqdn}/${dbname}",
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
    lock_path        => '/var/lib/cinder/tmp',
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

  class { '::cinder::keystone::authtoken':
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

  class { '::cinder::api':
    bind_host                    => $internal_interface, # osapi_volume_listen
    default_volume_type          => 'rbd',
    nova_catalog_info            => 'compute:Compute Service:publicURL',
    nova_catalog_admin_info      => 'compute:Compute Service:adminURL',
    keystone_enabled             => false,
    auth_strategy                => 'keystone',
    enable_proxy_headers_parsing => true,
    #
    sync_db                      => $sync_db,
    os_region_name               => $region,
  }

  class { '::cinder::scheduler':
    scheduler_driver => 'cinder.scheduler.filter_scheduler.FilterScheduler',
  }

  class { '::cinder::glance':
    glance_api_servers => "http://${internal_image_fqdn}:9292",
    glance_api_version => '2',
  }

  cinder::backend::rbd { 'rbd':
    rbd_pool              => 'volumes',
    backend_host          => $backend_host,
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

  class { '::cinder::backends':
    enabled_backends => ['rbd'],
  }

  class { '::cinder::ceilometer':
    notification_transport_url => undef,
    notification_driver        => 'messagingv2',
  }
}
