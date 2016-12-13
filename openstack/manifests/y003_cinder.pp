class openstack::y003_cinder (
  $bootstrap_node  = 'controller-1',
  $cinder_password = 'cinder1234',
  $allowed_hosts   = ['%'],
  $cluster_nodes   = ['controller-1', 'controller-2', 'controller-3'],
  $host            = 'controller-vip',
  $rbd_secret_uuid = '2ad6a20f-ffdd-460d-afba-04ab286f365f',) {
  if $::hostname == $bootstrap_node {
    class { '::cinder::db::mysql':
      password      => $cinder_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    $sync_db = true
  } else {
    $sync_db = false
  }

  class { '::cinder':
    database_connection  => "mysql+pymysql://cinder:${cinder_password}@${host}/cinder",
    database_max_retries => '-1',
    rpc_backend          => 'rabbit',
    rabbit_password      => 'guest',
    rabbit_userid        => 'guest',
    rabbit_hosts         => $cluster_nodes,
    rabbit_ha_queues     => true,
    rabbit_use_ssl       => false,
    control_exchange     => 'cinder',
    host                 => 'openstack-cinder',
  }

  class { '::cinder::api':
    bind_host           => $::hostname,
    default_volume_type => 'rbd',
    keystone_enabled    => false,
    auth_strategy       => false,
    #
    sync_db             => $sync_db,
    #
    manage_service      => false,
    enabled             => false,
  }

  class { '::cinder::keystone::authtoken':
    auth_uri            => "http://${host}:5000/",
    auth_url            => "http://${host}:35357/",
    memcached_servers   => $cluster_nodes,
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    project_name        => 'service',
    username            => 'cinder',
    password            => $cinder_password,
  }

  class { '::cinder::scheduler':
    manage_service => false,
    enabled        => false,
  }

  class { '::cinder::volume':
    manage_service => false,
    enabled        => false,
  }

  class { '::cinder::glance':
    glance_api_servers => $host,
    glance_api_version => '2',
  }

  ::cinder::backend::rbd { 'rbd':
    rbd_pool              => 'volumes',
    rbd_user              => 'cinder',
    rbd_ceph_conf         => '/etc/ceph/ceph.conf',
    rbd_flatten_volume_from_snapshot => false,
    rbd_secret_uuid       => $rbd_secret_uuid,
    rbd_max_clone_depth   => '5',
    rbd_store_chunk_size  => '4',
    rados_connect_timeout => '-1',
    volume_backend_name   => $name,
  # manage_volume_type    => true,
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
    keystone_service { 'cinder':
      ensure      => 'present',
      type        => 'volume',
      description => 'OpenStack Block Storage',
    } ->
    keystone_endpoint { 'cinder':
      ensure       => 'present',
      region       => 'RegionOne',
      admin_url    => "http://${host}:8776/v1/%(tenant_id)s",
      public_url   => "http://${host}:8776/v1/%(tenant_id)s",
      internal_url => "http://${host}:8776/v1/%(tenant_id)s",
    } ->
    keystone_service { 'cinderv2':
      ensure      => 'present',
      type        => 'volumev2',
      description => 'OpenStack Block Storage',
    } ->
    keystone_endpoint { 'cinderv2':
      ensure       => 'present',
      region       => 'RegionOne',
      admin_url    => "http://${host}:8776/v2/%(tenant_id)s",
      public_url   => "http://${host}:8776/v2/%(tenant_id)s",
      internal_url => "http://${host}:8776/v2/%(tenant_id)s",
    } ->
    keystone_service { 'cinderv3':
      ensure      => 'present',
      type        => 'volumev3',
      description => 'OpenStack Block Storage',
    } ->
    keystone_endpoint { 'cinderv3':
      ensure       => 'present',
      region       => 'RegionOne',
      admin_url    => "http://${host}:8776/v3/%(tenant_id)s",
      public_url   => "http://${host}:8776/v3/%(tenant_id)s",
      internal_url => "http://${host}:8776/v3/%(tenant_id)s",
    } ->
    keystone_user { 'cinder':
      ensure   => 'present',
      password => $cinder_password,
      # email    => 'cinder@example.org',
      domain   => 'default',
    } ->
    keystone_user_role { 'cinder::default@service::default':
      ensure         => 'present',
      user           => 'cinder',
      user_domain    => 'default',
      project        => 'service',
      project_domain => 'default',
      roles          => ['admin'],
    } ->
    pacemaker::resource::service { 'openstack-cinder-api': clone_params => 'interleave=true', } ->
    pacemaker::resource::service { 'openstack-cinder-scheduler': clone_params => 'interleave=true', } ->
    pacemaker::resource::service { 'openstack-cinder-volume': } ->
    pacemaker::resource::service { 'openstack-cinder-backup': clone_params => 'interleave=true', } ->
    pacemaker::constraint::base { 'order-openstack-cinder-api-clone-openstack-cinder-scheduler-clone-Mandatory':
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => 'openstack-cinder-api-clone',
      second_action     => 'start',
      second_resource   => 'openstack-cinder-scheduler-clone',
      constraint_params => 'kind=Mandatory',
    } ->
    pacemaker::constraint::colocation { 'colocation-openstack-cinder-scheduler-clone-openstack-cinder-api-clone-INFINITY':
      source => 'openstack-cinder-scheduler-clone',
      target => 'openstack-cinder-api-clone',
      score  => 'INFINITY',
    } ->
    pacemaker::constraint::base { 'order-openstack-cinder-scheduler-clone-openstack-cinder-volume-Mandatory':
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => 'openstack-cinder-scheduler-clone',
      second_action     => 'start',
      second_resource   => 'openstack-cinder-volume',
      constraint_params => 'kind=Mandatory',
    } ->
    pacemaker::constraint::colocation { 'colocation-openstack-cinder-volume-openstack-cinder-scheduler-clone-INFINITY':
      source => 'openstack-cinder-volume',
      target => 'openstack-cinder-scheduler-clone',
      score  => 'INFINITY',
    } ->
    pacemaker::constraint::base { 'order-openstack-cinder-scheduler-clone-openstack-cinder-backup-clone-Mandatory':
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => 'openstack-cinder-scheduler-clone',
      second_action     => 'start',
      second_resource   => 'openstack-cinder-backup-clone',
      constraint_params => 'kind=Mandatory',
    } ->
    pacemaker::constraint::colocation { 'colocation-openstack-cinder-backup-clone-openstack-cinder-scheduler-clone-INFINITY':
      source => 'openstack-cinder-backup-clone',
      target => 'openstack-cinder-scheduler-clone',
      score  => 'INFINITY',
    } ->
    exec { 'cinder-ready':
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/openstack --os-project-name=admin --os-username=admin --os-password=admin1234 --os-auth-url=http://${host}:35357/v3 volume list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-name=admin --os-username=admin --os-password=admin1234 --os-auth-url=http://${host}:35357/v3 volume list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-name=admin --os-username=admin --os-password=admin1234 --os-auth-url=http://${host}:35357/v3 volume list > /dev/null 2>&1",
      unless    => "/usr/bin/openstack --os-project-name=admin --os-username=admin --os-password=admin1234 --os-auth-url=http://${host}:35357/v3 volume list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-name=admin --os-username=admin --os-password=admin1234 --os-auth-url=http://${host}:35357/v3 volume list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-name=admin --os-username=admin --os-password=admin1234 --os-auth-url=http://${host}:35357/v3 volume list > /dev/null 2>&1",
    } ->
    cinder_type { 'rbd':
      ensure     => present,
      properties => ['volume_backend_name=rbd'],
    }
  }
}
