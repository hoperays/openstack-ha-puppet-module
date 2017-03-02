node /^*controller-\d*$/ {
  # core non-openstack services
  class { '::openstack::x001_firewall': } ->
  class { '::openstack::x002_hosts': } ->
  class { '::openstack::x003_ntp': } ->
  class { '::openstack::x004_ceph': } ->
  class { '::openstack::x005_pacemaker': } ->
  class { '::openstack::x006_haproxy': } ->
  class { '::openstack::x007_galera': } ->
  class { '::openstack::x008_rabbitmq': } ->
  class { '::openstack::x009_memcached': } ->
  class { '::openstack::x010_mongodb': } ->
  class { '::openstack::x011_redis': } ->
  # core openstack services
  class { '::openstack::y001_keystone': } ->
  class { '::openstack::y002_glance': } ->
  class { '::openstack::y003_cinder': } ->
  class { '::openstack::y004_neutron': } ->
  class { '::openstack::y005_nova': } ->
  class { '::openstack::y006_horizon': } ->
  class { '::openstack::y007_ceilometer': } ->
  class { '::openstack::y008_gnocchi': } ->
  class { '::openstack::y009_aodh': } ->
  # other services
  class { '::openstack::z001_zabbix': }
}

node /^*novacompute-\d*$/ {
  # core non-openstack services
  class { '::openstack::x001_firewall': } ->
  class { '::openstack::x002_hosts': } ->
  class { '::openstack::x003_ntp': } ->
  class { '::openstack::x004_ceph': } ->
  class { '::openstack::x005_pacemaker': } ->
  # core openstack services
  class { '::openstack::y004_neutron': } ->
  class { '::openstack::y005_nova': } ->
  class { '::openstack::y007_ceilometer': } ->
  # other services
  class { '::openstack::z001_zabbix': }
}

node /^*cephstorage-\d*$/ {
  # core non-openstack services
  class { '::openstack::x001_firewall': } ->
  class { '::openstack::x002_hosts': } ->
  class { '::openstack::x003_ntp': } ->
  class { '::openstack::x004_ceph': } ->
  # core openstack services
  #
  # other services
  class { '::openstack::z001_zabbix': }
}

node default {
  # no configuration
  notify { 'There is nothing to do !': }
}
