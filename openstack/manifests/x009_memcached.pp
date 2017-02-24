class openstack::x009_memcached () {
  class { 'memcached':
    listen_ip => $::ipaddress_vlan53,
  }
}
