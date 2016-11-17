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
  class { 'openstack::x001_firewall': }

  class { 'openstack::x002_hosts': require => Class['openstack::x001_firewall'] }

  class { 'openstack::x003_ntp': require => Class['openstack::x002_hosts'] }

  class { 'openstack::x004_ceph': require => Class['openstack::x003_ntp'] }

  class { 'openstack::x005_pacemaker': require => Class['openstack::x003_ntp'] }

  class { 'openstack::x006_haproxy': require => Class['openstack::x005_pacemaker'] }

  class { 'openstack::x007_galera': require => Class['openstack::x005_pacemaker'] }
}
