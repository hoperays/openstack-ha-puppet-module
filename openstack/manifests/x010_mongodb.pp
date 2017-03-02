class openstack::x010_mongodb (
  $bootstrap_node           = hiera('controller_1_hostname'),
  $manage_package_repo      = false,
  $bind_ip                  = hiera('internal_interface'),
  $replset                  = '',
  $smallfiles               = false,
  $controller_1_internal_ip = hiera('controller_1_internal_ip'),
  $controller_2_internal_ip = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip = hiera('controller_3_internal_ip'),
) {
  class { '::mongodb::globals':
    manage_package_repo => $manage_package_repo,
  } ->
  class { '::mongodb::server':
    bind_ip    => $bind_ip,
    replset    => $replset,
    smallfiles => $smallfiles,
  } ->
  class { '::mongodb::client': }

  if $::hostname == $bootstrap_node {
    mongodb_replset { $replset:
      members => [
        "${controller_1_internal_ip}:27017",
        "${controller_2_internal_ip}:27017",
        "${controller_3_internal_ip}:27017"],
    }
  }
}
