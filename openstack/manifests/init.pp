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
  class { [
    'openstack::x001_firewall',
    'openstack::x002_hosts',
    'openstack::x003_ntp',
    'openstack::x004_ceph',
    'openstack::x005_pacemaker',
    'openstack::x006_haproxy',
    'openstack::x007_galera']:
  }
  Class['openstack::x001_firewall'] ->
  Class['openstack::x002_hosts'] ->
  Class['openstack::x003_ntp'] ->
  Class['openstack::x004_ceph'] ->
  Class['openstack::x005_pacemaker'] ->
  Class['openstack::x006_haproxy'] ->
  Class['openstack::x007_galera']
}

