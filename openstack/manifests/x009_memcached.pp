class openstack::x009_memcached (
  $listen_ip = hiera('internal_interface'),
) {
  class { '::memcached':
    listen_ip => $listen_ip,
  }
}
