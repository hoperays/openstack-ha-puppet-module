class openstack::y002_glance (
  $bootstrap_node  = 'controller-1',
  $glance_password = 'glance1234',
  $allowed_hosts   = ['%'],
  $cluster_nodes   = ['controller-1', 'controller-2', 'controller-3'],
  $host            = 'controller-vip',) {
  if $::hostname == $bootstrap_node {
    $sync_db = true
  } else {
    $sync_db = false
  }

  class { '::glance::api':
    database_connection     => "mysql+pymysql://glance:${glance_password}@${host}/glance",
    database_max_retries    => '-1',
    bind_host               => $::hostname,
    registry_host           => $host,
    #
    pipeline                => 'keystone',
    auth_strategy           => '::glance::api::authtoken',
    #
    show_image_direct_url   => true,
    show_multiple_locations => true,
    stores                  => ['rbd', 'http'],
    default_store           => 'rbd',
    multi_store             => true,
    #
    manage_service          => false,
    enabled                 => false,
  }

  class { '::glance::api::authtoken':
    auth_uri            => "http://${host}:5000/",
    auth_url            => "http://${host}:35357/",
    memcached_servers   => $cluster_nodes,
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    project_name        => 'service',
    username            => 'glance',
    password            => $glance_password,
  }

  class { '::glance::notify::rabbitmq':
    rabbit_password  => 'guest',
    rabbit_userid    => 'guest',
    rabbit_hosts     => $cluster_nodes,
    rabbit_ha_queues => true,
    rabbit_use_ssl   => false,
  }

  class { '::glance::backend::rbd':
    rbd_store_pool       => 'images',
    rbd_store_user       => 'glance',
    rbd_store_ceph_conf  => '/etc/ceph/ceph.conf',
    rbd_store_chunk_size => '8',
    multi_store          => true,
    glare_enabled        => false,
  }

  class { '::glance::registry':
    database_connection  => "mysql+pymysql://glance:${glance_password}@${host}/glance",
    database_max_retries => '-1',
    bind_host            => $::hostname,
    #
    pipeline             => 'keystone',
    auth_strategy        => '::glance::registry::authtoken',
    #
    sync_db              => $sync_db,
    #
    manage_service       => false,
    enabled              => false,
  }

  class { '::glance::registry::authtoken':
    auth_uri            => "http://${host}:5000/",
    auth_url            => "http://${host}:35357/",
    memcached_servers   => $cluster_nodes,
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    project_name        => 'service',
    username            => 'glance',
    password            => $glance_password,
  }

  if $::hostname == $bootstrap_node {
    class { '::glance::db::mysql':
      password      => $glance_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    } ->
    keystone_service { 'glance':
      ensure      => 'present',
      type        => 'image',
      description => 'OpenStack Image',
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
      password => $glance_password,
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
    pacemaker::constraint::base { 'order-httpd-clone-openstack-glance-registry-clone-Mandatory':
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => 'httpd-clone',
      second_action     => 'start',
      second_resource   => 'openstack-glance-registry-clone',
      constraint_params => 'kind=Mandatory',
    } ->
    pacemaker::resource::service { 'openstack-glance-api': clone_params => 'interleave=true', } ->
    pacemaker::constraint::base { 'order-openstack-glance-registry-clone-openstack-glance-api-clone-Mandatory':
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
