class openstack::x008_rabbitmq (
  $cluster_nodes  = ['controller-1', 'controller-2', 'controller-3'],
  $bootstrap_node = 'controller-1') {
  class { 'rabbitmq':
    config_cluster           => false,
    cluster_nodes            => $cluster_nodes,
    node_ip_address          => $ipaddress_eth0,
    cluster_node_type        => 'ram',
    erlang_cookie            => 'CECDFFCEFEDBFAAECDFA',
    wipe_db_on_cookie_change => true,
  }

  class { 'rabbitmq::service':
    service_ensure => 'stopped',
    service_manage => false,
    require        => Class['rabbitmq'],
  }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::ocf { 'rabbitmq':
      ocf_agent_name  => 'heartbeat:rabbitmq-cluster',
      resource_params => "set_policy='ha-all ^(?!amq\\.).* {\"ha-mode\":\"all\"}'",
      meta_params     => 'notify=true',
      clone_params    => 'ordered=true interleave=true',
      # op_params       => 'start timeout=200s stop timeout=200s',
      require         => Class['rabbitmq::service'],
    }
  }
}
