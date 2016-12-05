class openstack::x011_redis ($bootstrap_node = 'controller-1',) {
  if $::hostname == $bootstrap_node {
    $slaveof = undef
  } else {
    $slaveof = "${bootstrap_node} 6379"
  }

  class { '::redis':
    bind    => ['127.0.0.1', $ipaddress_eth0],
    slaveof => $slaveof,
  }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::ocf { 'redis':
      ocf_agent_name  => 'heartbeat:redis',
      master_params   => '',
      meta_params     => 'notify=true ordered=true interleave=true',
      resource_params => 'wait_last_known_master=true',
      op_params       => 'start timeout=200s stop timeout=200s',
      require         => Class['::redis'],
    }
  }
}
