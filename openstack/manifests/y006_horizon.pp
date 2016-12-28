class openstack::y006_horizon (
  $bootstrap_node = 'controller-1',
  $cluster_nodes  = ['controller-1', 'controller-2', 'controller-3'],
  $secret_key     = 'd872760ce14ffd0919ad',
  $host           = 'controller-vip',) {
  class { '::horizon':
    servername        => $::hostname,
    server_aliases    => $::hostname,
    allowed_hosts     => $::hostname,
    cache_server_ip   => $cluster_nodes,
    cache_server_port => '11211',
    secret_key        => $secret_key,
    keystone_url      => "http://${host}:5000",
    django_debug      => 'True',
    api_result_limit  => '2000',
  }

  if $::hostname == $bootstrap_node {
    exec { 'apache-restart':
      timeout   => '3600',
      tries     => '180',
      try_sleep => '20',
      command   => "/usr/sbin/pcs resource restart apache-clone",
      unless    => "/usr/sbin/pcs resource restart apache-clone",
    }
  }
}
