# == Class keystone::python
#
# installs client python libraries for keystone
#
# === Parameters:
#
# [*client_package_name*]
#   (optional) The name of python keystone client package
#   Defaults to $keystone::params::client_package_name
#
# [*ensure*]
#   (optional) The state for the keystone client package
#   Defaults to 'present'
#
class keystone::python (
  $client_package_name = $keystone::params::client_package_name,
  $ensure = 'present'
) inherits keystone::params {

  warning('This class is deprecated, has no effect, and will be removed in Newton')
}
