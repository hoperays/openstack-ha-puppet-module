class openstack::x009_memcached ($bootstrap_node = 'controller-1', $manage_resources = false,) {
  class { 'memcached':
    service_manage => $manage_resources,
    listen_ip      => $::ipaddress_eth0,
  }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::service { 'memcached':
      clone_params => 'interleave=true',
      require      => Class['memcached']
    }
  }
}
