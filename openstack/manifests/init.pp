# Class: openstack
#
# This module manages openstack
#
# Parameters: none
#
# Actions:
#
# Requires: see Modulefile
#
# Sample Usage:
#
class openstack {
  # core non-openstack services
  class { 'openstack::x001_firewall': } ->
  class { 'openstack::x002_hosts': } ->
  class { 'openstack::x003_ntp': } ->
  class { 'openstack::x004_ceph': } ->
  class { 'openstack::x005_pacemaker': } ->
  class { 'openstack::x006_haproxy': } ->
  class { 'openstack::x007_galera': } ->
  class { 'openstack::x008_rabbitmq': } ->
  class { 'openstack::x009_memcached': } ->
  # core openstack services
  class { 'openstack::y001_keystone': } ->
  class { 'openstack::y002_glance': } ->
  class { 'openstack::y003_cinder': } ->
  class { 'openstack::y004_neutron': } ->
  class { 'openstack::y005_nova': } ->
  class { 'openstack::y006_horizon': }
  # other services
  # class { 'openstack::z001_zabbix': }
}
