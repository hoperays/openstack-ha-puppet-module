class openstack::x010_mongodb (
  $bootstrap_node = 'controller-1',
  $controller_1   = '192.168.0.131',
  $controller_2   = '192.168.0.132',
  $controller_3   = '192.168.0.133',) {
  class { '::mongodb::globals': manage_package_repo => false, } ->
  class { '::mongodb::server':
    bind_ip    => ['127.0.0.1', $ipaddress_eth0],
    replset    => 'ceilometer',
    smallfiles => true,
  } ->
  class { '::mongodb::client': }

  if $::hostname == $bootstrap_node {
    mongodb_replset { 'ceilometer':
      members => [
        "${controller_1}:27017",
        "${controller_2}:27017",
        "${controller_3}:27017"],
    }
  }
}
