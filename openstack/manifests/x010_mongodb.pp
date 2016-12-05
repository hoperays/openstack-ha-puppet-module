class openstack::x010_mongodb (
  $cluster_nodes  = ['controller-1', 'controller-2', 'controller-3'],
  $bootstrap_node = 'controller-1',) {
  class { '::mongodb::globals':
    bind_ip             => ['127.0.0.1', $ipaddress_eth0],
    manage_package_repo => false,
    manage_package      => true,
  } ->
  class { '::mongodb::server': } ->
  class { '::mongodb::client': }

  mongodb_replset { 'ceilometer': members => $cluster_nodes, }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::service { 'mongod':
      service_name => 'mongod',
      clone_params => true,
      require      => Mongodb_replset['ceilometer']
    }
  }
}
