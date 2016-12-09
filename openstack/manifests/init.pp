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

  class { 'openstack::x007_memcached': require => Class['openstack::x005_pacemaker'] }

  class { 'openstack::x008_rabbitmq': require => Class['openstack::x005_pacemaker'] }

  class { 'openstack::x009_galera': require => Class['openstack::x006_haproxy'] }

  class { 'openstack::y001_keystone':
    require => [
      Class['openstack::x007_memcached'],
      Class['openstack::x008_rabbitmq'],
      Class['openstack::x009_galera']]
  }

  class { 'openstack::y002_glance':
    require => [Class['openstack::x004_ceph'], Class['openstack::y001_keystone']]
  }

  # class { 'openstack::x010_mongodb': require => Class['openstack::x005_pacemaker'] }
  # class { 'openstack::x011_redis': require => Class['openstack::x005_pacemaker'] }
}
