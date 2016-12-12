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
  class { 'openstack::x001_firewall': } ->
  class { 'openstack::x002_hosts': } ->
  class { 'openstack::x003_ntp': } ->
  class { 'openstack::x004_ceph': } ->
  class { 'openstack::x005_pacemaker': } ->
  class { 'openstack::x006_haproxy': } ->
  class { 'openstack::x007_galera': } ->
  class { 'openstack::x008_rabbitmq': } ->
  class { 'openstack::x009_memcached': } ->
  class { 'openstack::y001_keystone': } ->
  class { 'openstack::y002_glance': }
}
