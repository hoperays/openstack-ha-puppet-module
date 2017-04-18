class openstack::x008_rabbitmq (
  $bootstrap_node           = hiera('controller_1_hostname'),
  $manage_resources         = false,
  $config_cluster           = false,
  $cluster_nodes            = [
    hiera('controller_1_hostname'),
    hiera('controller_2_hostname'),
    hiera('controller_3_hostname'),
  ],
  $node_ip_address          = hiera('internal_interface'),
  $cluster_node_type        = '',
  $erlang_cookie            = '',
  $wipe_db_on_cookie_change = false,
  $default_user             = hiera('rabbit_username'),
  $default_pass             = hiera('rabbit_password'),
) {
  class { '::rabbitmq':
    repos_ensure             => $manage_resources,
    admin_enable             => $manage_resources,
    service_manage           => $manage_resources,
    config_cluster           => $config_cluster,
    cluster_nodes            => $cluster_nodes,
    node_ip_address          => $node_ip_address,
    cluster_node_type        => $cluster_node_type,
    erlang_cookie            => $erlang_cookie,
    wipe_db_on_cookie_change => $wipe_db_on_cookie_change,
    default_user             => $default_user,
    default_pass             => $default_pass,
  }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::ocf { 'rabbitmq':
      ocf_agent_name  => 'heartbeat:rabbitmq-cluster',
      resource_params => "set_policy='ha-all ^(?!amq\\.).* {\"ha-mode\":\"all\"}'",
      meta_params     => 'notify=true',
      clone_params    => 'ordered=true interleave=true',
      op_params       => 'start timeout=200s stop timeout=200s',
      require         => Class['::rabbitmq'],
    }
  }
}
