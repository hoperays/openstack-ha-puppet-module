class openstack::y002_glance (
  $bootstrap_node  = 'controller-1',
  $glance_password = 'glance1234',
  $allowed_hosts   = ['%'],
  $admin_token     = 'e38f3dd7116ee3bc3dba',
  $cluster_nodes   = ['controller-1', 'controller-2', 'controller-3'],
  $host            = 'controller-vip',) {
  if $::hostname == $bootstrap_node {
    class { '::glance::db::mysql':
      password      => $glance_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    $sync_db = true
  } else {
    $sync_db = false
  }

  class { '::glance::api':
    database_connection   => "mysql+pymysql://glance:${glance_password}@${host}/glance",
    database_max_retries  => '-1',
    bind_host             => $::hostname,
    registry_host         => $host,
    auth_uri              => "http://${host}:5000/",
    identity_uri          => "http://${host}:35357/",
    memcached_servers     => $cluster_nodes,
    auth_type             => 'keystone',
    keystone_tenant       => 'service',
    keystone_user         => 'glance',
    keystone_password     => $glance_password,
    pipeline              => 'keystone',
    #
    show_image_direct_url => true,
    stores                => ['rbd', 'http'],
    default_store         => 'rbd',
    multi_store           => true,
    #
    manage_service        => false,
    enabled               => false,
  }

  class { '::glance::notify::rabbitmq':
    rabbit_password  => 'guest',
    rabbit_userid    => 'guest',
    rabbit_hosts     => $cluster_nodes,
    rabbit_ha_queues => true,
    rabbit_use_ssl   => false,
  }

  class { '::glance::backend::rbd':
    rbd_store_chunk_size => '8',
    rbd_store_pool       => 'images',
    rbd_store_user       => 'glance',
    rbd_store_ceph_conf  => '/etc/ceph/ceph.conf',
    multi_store          => true,
    glare_enabled        => false,
  }

  class { '::glance::registry':
    database_connection  => "mysql+pymysql://glance:${glance_password}@${host}/glance",
    database_max_retries => '-1',
    bind_host            => $::hostname,
    auth_uri             => "http://${host}:5000/",
    identity_uri         => "http://${host}:35357/",
    memcached_servers    => $cluster_nodes,
    auth_type            => 'keystone',
    keystone_tenant      => 'service',
    keystone_user        => 'glance',
    keystone_password    => $glance_password,
    pipeline             => 'keystone',
    sync_db              => $sync_db,
    manage_service       => false,
    enabled              => false,
  }

  if $::hostname == $bootstrap_node {
    keystone_service { 'glance':
      ensure      => 'present',
      type        => 'image',
      description => 'OpenStack Image Service',
    } ->
    keystone_endpoint { 'glance':
      ensure       => 'present',
      region       => 'RegionOne',
      admin_url    => "http://${host}:9292",
      public_url   => "http://${host}:9292",
      internal_url => "http://${host}:9292",
    } ->
    keystone_user { 'glance':
      ensure   => 'present',
      password => 'glance1234',
      # email    => 'glance@example.org',
      domain   => 'default',
    } ->
    keystone_user_role { 'glance::default@service::default':
      ensure         => 'present',
      user           => 'glance',
      user_domain    => 'default',
      project        => 'service',
      project_domain => 'default',
      roles          => ['admin'],
    } ->
    pacemaker::resource::service { 'openstack-glance-registry': clone_params => 'interleave=true', } ->
    pacemaker::resource::service { 'openstack-glance-api': clone_params => 'interleave=true', } ->
    pacemaker::constraint::base { 'order-openstack-glance-registry-clone-openstack-glance-api-clone-Optional':
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => 'openstack-glance-registry-clone',
      second_action     => 'start',
      second_resource   => 'openstack-glance-api-clone',
      constraint_params => 'kind=Mandatory',
    } ->
    pacemaker::constraint::colocation { 'colocation-openstack-glance-api-clone-openstack-glance-registry-clone-INFINITY':
      source => 'openstack-glance-api-clone',
      target => 'openstack-glance-registry-clone',
      score  => 'INFINITY',
    }
  }
}
