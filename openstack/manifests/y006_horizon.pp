class openstack::y006_horizon (
  $bind_address   = $ipaddress_eth0,
  $servername     = $::hostname,
  $server_aliases = ['*'],
  $allowed_hosts  = ['*'],
  $cluster_nodes  = ['192.168.0.131', '192.168.0.132', '192.168.0.133'],
  $secret_key     = 'd872760ce14ffd0919ad',
  $controller_vip = '192.168.0.130',) {
  class { '::horizon':
    bind_address                 => $bind_address,
    servername                   => $servername,
    server_aliases               => $server_aliases,
    allowed_hosts                => $allowed_hosts,
    listen_ssl                   => false,
    ssl_no_verify                => true,
    ssl_redirect                 => true,
    horizon_cert                 => '/etc/ssl/openstack.example.com.crt',
    horizon_key                  => '/etc/ssl/openstack.example.com.key',
    horizon_ca                   => '/etc/ssl/openstack.example.com.csr',
    cache_server_ip              => $cluster_nodes,
    cache_server_port            => '11211',
    secret_key                   => $secret_key,
    keystone_url                 => "http://${controller_vip}:5000/v3",
    keystone_default_role        => '_member_',
    django_debug                 => false,
    api_result_limit             => '2000',
    compress_offline             => true,
    api_versions                 => {
      identity => '3',
    }
    ,
    keystone_multidomain_support => true,
    keystone_default_domain      => 'default',
    timezone                     => 'Asia/Shanghai',
    session_timeout              => '1800',
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
}
