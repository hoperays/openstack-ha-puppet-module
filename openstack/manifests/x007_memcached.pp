class openstack::x007_memcached ($bootstrap_node = 'controller-1') {
  class { 'memcached': service_manage => false }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::service { 'memcached':
      service_name => 'memcached',
      clone_params => true,
      require      => Class['memcached']
    }
  }
}
