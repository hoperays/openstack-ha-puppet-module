class openstack::y002_glance (
  $bootstrap_node           = hiera('controller_1_hostname'),
  $rabbit_userid            = hiera('rabbit_username'),
  $rabbit_password          = hiera('rabbit_password'),
  $email                    = hiera('glance_email'),
  $dbname                   = hiera('glance_dbname'),
  $user                     = hiera('glance_username'),
  $password                 = hiera('glance_password'),
  $public_vip               = hiera('public_vip'),
  $internal_vip             = hiera('internal_vip'),
  $controller_1_internal_ip = hiera('controller_1_internal_ip'),
  $controller_2_internal_ip = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip = hiera('controller_3_internal_ip'),
  $internal_interface       = hiera('internal_interface'),
) {
  if $::hostname == $bootstrap_node {
    class { '::glance::db::mysql':
      dbname        => $dbname,
      user          => $user,
      password      => $password,
      host          => 'localhost',
      allowed_hosts => [$controller_1_internal_ip, $controller_2_internal_ip, $controller_3_internal_ip],
    }
    $sync_db = true

    Anchor['glance::dbsync::end'] ->
    exec { "${dbname}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/ssh ${controller_2_internal_ip} 'touch /tmp/.${dbname}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'touch /tmp/.${dbname}-db-ready'",
      unless    => "/bin/ssh ${controller_2_internal_ip} 'touch /tmp/.${dbname}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'touch /tmp/.${dbname}-db-ready'",
    }

    class { '::glance::keystone::auth':
      email               => $email,
      password            => $password,
      auth_name           => $user,
      configure_endpoint  => true,
      configure_user      => true,
      configure_user_role => true,
      service_name        => 'glance',
      service_type        => 'image',
      region              => 'RegionOne',
      tenant              => 'services',
      service_description => 'OpenStack Image Service',
      public_url          => "http://${public_vip}:9292",
      admin_url           => "http://${internal_vip}:9292",
      internal_url        => "http://${internal_vip}:9292",
    }
  } elsif $::hostname =~ /^*controller-\d*$/ {
    $sync_db = false

    Anchor['glance::config::end'] ->
    exec { "${dbname}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/ls /tmp/.${dbname}-db-ready",
      unless    => "/bin/ls /tmp/.${dbname}-db-ready",
    } ->
    Anchor['glance::service::begin']
  }

  class { '::glance::api::authtoken':
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
    username            => $user,
    password            => $password,
  }

  class { '::glance::api':
    show_image_direct_url        => true,
    show_multiple_locations      => true,
    bind_host                    => $internal_interface,
    bind_port                    => '9292',
    image_cache_dir              => '/var/lib/glance/image-cache',
    registry_host                => $internal_vip,
    registry_client_protocol     => 'http',
    log_file                     => '/var/log/glance/api.log',
    log_dir                      => '/var/log/glance',
    database_connection          => "mysql+pymysql://${user}:${password}@${internal_vip}/${dbname}",
    stores                       => ['glance.store.http.Store', 'glance.store.rbd.Store'],
    default_store                => 'rbd',
    os_region_name               => 'RegionOne',
    enable_proxy_headers_parsing => true,
    pipeline                     => 'keystone',
    auth_strategy                => 'keystone',
    multi_store                  => true,
    #
    purge_config                 => true,
  }

  class { '::glance::notify::rabbitmq':
    rabbit_hosts        => [
      "${controller_1_internal_ip}:5672",
      "${controller_2_internal_ip}:5672",
      "${controller_3_internal_ip}:5672"],
    rabbit_use_ssl      => false,
    rabbit_password     => $rabbit_password,
    rabbit_userid       => $rabbit_userid,
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
    username            => $user,
    password            => $password,
  }

  class { '::glance::registry::db':
    database_max_retries    => '-1',
    database_db_max_retries => '-1',
    database_connection     => "mysql+pymysql://${user}:${password}@${internal_vip}/${dbname}",
  }

  class { '::glance::registry':
    bind_host     => $internal_interface,
    bind_port     => '9191',
    log_file      => '/var/log/glance/registry.log',
    log_dir       => '/var/log/glance',
    pipeline      => 'keystone',
    auth_strategy => 'keystone',
    sync_db       => $sync_db,
    #
    purge_config  => true,
  }
}
