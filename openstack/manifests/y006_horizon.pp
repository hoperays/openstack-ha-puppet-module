class openstack::y006_horizon (
  $bind_address   = $ipaddress_eth0,
  $servername     = $::hostname,
  $server_aliases = [$::hostname, 'controller-vip', $ipaddress_eth0, '192.168.0.130'],
  $allowed_hosts  = [$::hostname, 'controller-vip', $ipaddress_eth0, '192.168.0.130'],
  $cluster_nodes  = ['controller-1', 'controller-2', 'controller-3'],
  $secret_key     = 'd872760ce14ffd0919ad',
  $host           = 'controller-vip',
  $bootstrap_node = 'controller-1',) {
  class { '::horizon':
    bind_address                 => $bind_address,
    servername                   => $servername,
    server_aliases               => $server_aliases,
    allowed_hosts                => $allowed_hosts,
    # listen_ssl                   => true,
    # horizon_cert                 => undef,
    # horizon_key                  => undef,
    # horizon_ca                   => undef,
    cache_server_ip              => $cluster_nodes,
    cache_server_port            => '11211',
    secret_key                   => $secret_key,
    keystone_url                 => "http://${host}:5000/v3",
    keystone_default_role        => '_member_',
    django_debug                 => false,
    api_result_limit             => '2000',
    compress_offline             => true,
    api_versions                 => {
      identity => '3',
      image    => '2', # GlanceV2 doesn't support copy-from feature
      volume   => '2',
    }
    ,
    keystone_multidomain_support => true,
    keystone_default_domain      => 'default',
    timezone                     => 'Asia/Shanghai',
    cache_backend                => 'django.core.cache.backends.memcached.MemcachedCache',
    django_session_engine        => 'django.contrib.sessions.backends.cache',
    neutron_options              => {
      enable_lb        => true,
      enable_firewall  => true,
      enable_vpn       => true,
      enable_ha_router => true,
    }
    ,
  }

  if $::hostname == $bootstrap_node {
    exec { 'apache-restart':
      command     => "/usr/sbin/pcs resource restart apache-clone",
      refreshonly => true,
      subscribe   => Class['::horizon'],
    }
  }
}
