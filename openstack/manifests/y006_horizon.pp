class openstack::y006_horizon (
  $bind_address                 = hiera('internal_interface'),
  $servername                   = $::hostname, # 'openstack.example.com',
  $server_aliases               = '',
  $allowed_hosts                = '',
  $cluster_nodes                = [
    hiera('controller_1_internal_ip'),
    hiera('controller_2_internal_ip'),
    hiera('controller_3_internal_ip')],
  $secret_key                   = hiera('horizon_secret_key'),
  $internal_identity_fqdn       = join(any2array([
    'internal.identity',
    hiera('domain_name')]), '.'),
  $api_result_limit             = '',
  $keystone_multidomain_support = false,
  $keystone_default_domain      = '',
  $timezone                     = '',
  $session_timeout              = '',
  $neutron_options              = {},
) {
  class { '::horizon':
    bind_address                 => $bind_address,
    servername                   => $servername,
    server_aliases               => $server_aliases,
    allowed_hosts                => $allowed_hosts,
    listen_ssl                   => false, # true
    ssl_no_verify                => true,
    ssl_redirect                 => true,
    horizon_cert                 => '/etc/pki/tls/certs/apache-selfsigned.crt',
    horizon_key                  => '/etc/pki/tls/private/apache-selfsigned.key',
    horizon_ca                   => '/etc/pki/tls/certs/apache-selfsigned.crt',
    cache_server_ip              => $cluster_nodes,
    cache_server_port            => '11211',
    secret_key                   => $secret_key,
    keystone_url                 => "http://${internal_identity_fqdn}:5000",
    keystone_default_role        => '_member_',
    django_debug                 => false,
    api_result_limit             => $api_result_limit,
    compress_offline             => true,
    api_versions                 => {
      identity => '3',
    }
    ,
    keystone_multidomain_support => $keystone_multidomain_support,
    keystone_default_domain      => $keystone_default_domain,
    timezone                     => $timezone,
    session_timeout              => $session_timeout,
    cache_backend                => 'django.core.cache.backends.memcached.MemcachedCache',
    django_session_engine        => 'django.contrib.sessions.backends.cache',
    neutron_options              => $neutron_options,
  }
}
