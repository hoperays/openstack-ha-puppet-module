class openstack::x010_mongodb (
  $bootstrap_node = 'controller-1',
  $controller_1   = '172.17.53.101',
  $controller_2   = '172.17.53.102',
  $controller_3   = '172.17.53.103',) {
  class { '::mongodb::globals': manage_package_repo => false, } ->
  class { '::mongodb::server':
    bind_ip    => ['127.0.0.1', $ipaddress_vlan53],
    replset    => 'openstack',
    smallfiles => true,
  } ->
  class { '::mongodb::client': }

  if $::hostname == $bootstrap_node {
    mongodb_replset { 'openstack':
      members => [
        "${controller_1}:27017",
        "${controller_2}:27017",
        "${controller_3}:27017"],
    }
  }
}
