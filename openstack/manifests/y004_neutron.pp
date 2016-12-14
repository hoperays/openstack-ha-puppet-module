class openstack::y004_neutron (
  $bootstrap_node   = 'controller-1',
  $neutron_password = 'neutron1234',
  $nova_password    = 'nova1234',
  $allowed_hosts    = ['%'],
  $cluster_nodes    = ['controller-1', 'controller-2', 'controller-3'],
  $host             = 'controller-vip',
  $rbd_secret_uuid  = '2ad6a20f-ffdd-460d-afba-04ab286f365f',) {
  if $::hostname == $bootstrap_node {
    $sync_db = true
  } else {
    $sync_db = false
  }

  class { '::neutron':
    host                    => $::hostname,
    bind_host               => $::hostname,
    auth_strategy           => 'keystone',
    notification_driver     => 'neutron.openstack.common.notifier.rpc_notifier',
    rabbit_hosts            => $cluster_nodes,
    rabbit_ha_queues        => true,
    #
    core_plugin             => 'neutron.plugins.ml2.plugin.Ml2Plugin',
    service_plugins         => 'router',
    #
    dhcp_agents_per_network => '2',
  }

  class { '::neutron::server':
    database_connection      => "mysql+pymysql://neutron:${neutron_password}@${host}/neutron",
    database_max_retries     => '-1',
    auth_strategy            => false,
    #
    router_scheduler_driver  => 'neutron.scheduler.l3_agent_scheduler.ChanceScheduler',
    #
    api_workers              => '2',
    rpc_workers              => '2',
    l3_ha                    => true,
    min_l3_agents_per_router => '2',
    max_l3_agents_per_router => '2',
    #
    sync_db                  => $sync_db,
    #
    manage_service           => false,
    enabled                  => false,
  }

  class { '::neutron::keystone::authtoken':
    auth_uri            => "http://${host}:5000/",
    auth_url            => "http://${host}:35357/",
    memcached_servers   => $cluster_nodes,
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    region_name         => 'RegionOne',
    project_name        => 'service',
    username            => 'neutron',
    password            => $neutron_password,
  }

  class { '::neutron::server::notifications':
    notify_nova_on_port_status_changes => true,
    notify_nova_on_port_data_changes   => true,
    auth_url          => "http://${host}:35357/",
    auth_type         => 'password',
    project_domain_id => 'default',
    user_domain_id    => 'default',
    region_name       => 'RegionOne',
    project_name      => 'service',
    username          => 'nova',
    password          => $nova_password,
  }

  class { '::neutron::agents::dhcp':
    manage_service => false,
    enabled        => false,
  }

  class { '::neutron::agents::l3':
    manage_service => false,
    enabled        => false,
  }

  if $::hostname == $bootstrap_node {
    class { '::neutron::db::mysql':
      password      => $neutron_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    } ->
    keystone_service { 'neutron':
      ensure      => 'present',
      type        => 'network',
      description => 'OpenStack Networking',
    } ->
    keystone_endpoint { 'neutron':
      ensure       => 'present',
      region       => 'RegionOne',
      admin_url    => "http://${host}:9696",
      public_url   => "http://${host}:9696",
      internal_url => "http://${host}:9696",
    } ->
    keystone_user { 'neutron':
      ensure   => 'present',
      password => $neutron_password,
      # email    => 'neutron@example.org',
      domain   => 'default',
    } ->
    keystone_user_role { 'neutron::default@service::neutron':
      ensure         => 'present',
      user           => 'neutron',
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
      command   => "/usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 volume list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 volume list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 volume list > /dev/null 2>&1",
      unless    => "/usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 volume list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 volume list > /dev/null 2>&1 && \
                    /usr/bin/openstack --os-project-domain-name default --os-user-domain-name default --os-project-name admin --os-username admin --os-password admin1234 --os-auth-url http://${host}:35357/v3 --os-identity-api-version 3 volume list > /dev/null 2>&1",
    }
  }
}
