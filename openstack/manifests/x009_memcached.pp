class openstack::x009_memcached ($bootstrap_node = 'controller-1') {
  class { 'memcached': }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::service { 'memcached':
      service_name => 'memcached',
      clone_params => true,
      meta_params  => 'interleave=true',
      require      => Class['memcached'],
    }
  }
}
