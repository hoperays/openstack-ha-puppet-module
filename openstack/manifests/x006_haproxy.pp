class openstack::x006_haproxy (
  $bootstrap_node            = hiera('controller_1_hostname'),
  $admin_vip                 = hiera('admin_vip'),
  $public_vip                = hiera('public_vip'),
  $internal_vip              = hiera('internal_vip'),
  $server_names              = [
    hiera('controller_1_hostname'),
    hiera('controller_2_hostname'),
    hiera('controller_3_hostname')],
  $ipaddresses               = [
    hiera('controller_1_internal_ip'),
    hiera('controller_2_internal_ip'),
    hiera('controller_3_internal_ip')],
  $controller_2_hostname     = hiera('controller_2_hostname'),
  $controller_3_hostname     = hiera('controller_3_hostname'),
  $haproxy_stats_user        = hiera('haproxy_stats_username'),
  $haproxy_stats_password    = hiera('haproxy_stats_password'),
  $redis_password            = hiera('redis_password'),
  $manage_resources          = false,
  $haproxy_log_address       = '',
  $haproxy_global_maxconn    = '',
  $haproxy_ssl_cipher_suite  = '',
  $haproxy_ssl_options       = '',
  $haproxy_default_maxconn   = '',
  $haproxy_default_timeout   = [],
  $haproxy_listen_bind_param = [],
  $haproxy_listen_options    = {},
  $haproxy_member_options    = [],
  $service_certificate       = '',
  $refresh          = '',
  $mysql            = false,
  $redis            = false,
  $keystone         = false,
  $glance           = false,
  $cinder           = false,
  $neutron          = false,
  $nova             = false,
  $horizon          = false,
  $ceilometer       = false,
  $gnocchi          = false,
  $aodh             = false,
) {
  class { '::haproxy':
    service_ensure   => $manage_resources,
    service_manage   => $manage_resources,
    global_options   => {
      daemon  => '',
      user    => 'haproxy',
      group   => 'haproxy',
      log     => "$haproxy_log_address local0",
      chroot  => '/var/lib/haproxy',
      pidfile => '/var/run/haproxy.pid',
      maxconn => "$haproxy_global_maxconn",
      stats   => 'socket /var/lib/haproxy/stats',
      ssl-default-bind-ciphers => "$haproxy_ssl_cipher_suite",
      ssl-default-bind-options => "$haproxy_ssl_options",
    }
    ,
    defaults_options => {
      log     => 'global',
      stats   => 'enable',
      option  => 'redispatch',
      retries => '3',
      maxconn => $haproxy_default_maxconn,
      mode    => 'tcp',
      timeout => $haproxy_default_timeout,
    }
    ,
  }

  haproxy::listen { 'stats':
    bind    => {
      "$public_vip:1993"  => $haproxy_listen_bind_param,
      "$public_vip:13993" => union($haproxy_listen_bind_param, [
        'ssl',
        'crt',
        $service_certificate])
    }
    ,
    mode    => 'http',
    options => {
      monitor-uri  => '/status',
      stats        => [
        'enable',
        'uri /',
        'realm Haproxy\ Statistics',
        "auth ${haproxy_stats_user}:${haproxy_stats_password}",
        "refresh ${refresh}",
        ],
      acl          => ["clear dst_port 1993", "secure dst_port 13993"],
      http-request => ["redirect prefix https://$public_vip:13993 unless { ssl_fc } secure"],
    }
  }

  Haproxy::Balancermember {
    server_names => $server_names,
    ipaddresses  => $ipaddresses,
    options      => $haproxy_member_options
  }

  if $mysql {
    haproxy::listen { 'mysql':
      bind    => {
        "$internal_vip:3306" => $haproxy_listen_bind_param
      }
      ,
      options => {
        option      => ['tcpka', 'httpchk'],
        stick       => 'on dst',
        stick-table => 'type ip size 1000',
        timeout     => [
          'client 90m',
          'server 90m'],
      }
    }

    haproxy::balancermember { 'mysql':
      listening_service => 'mysql',
      ports             => '3306',
      options           => 'backup check inter 1s on-marked-down shutdown-sessions port 9200',
    }
  }

  if $redis {
    haproxy::listen { 'redis':
      bind    => {
        "$internal_vip:6379" => $haproxy_listen_bind_param
      }
      ,
      options => {
        balance   => 'first',
        option    => 'tcp-check',
        tcp-check => [
          "send AUTH\ ${redis_password}\\r\\n",
          'send PING\r\n',
          'expect string +PONG',
          'send info\ replication\r\n',
          'expect string role:master',
          'send QUIT\r\n',
          'expect string +OK'],
      }
    }

    haproxy::balancermember { 'redis':
      listening_service => 'redis',
      ports             => '6379',
    }
  }

  if $keystone {
    haproxy::listen { 'keystone_admin':
      bind    => {
        "$admin_vip:35357"    => $haproxy_listen_bind_param,
        "$internal_vip:35357" => $haproxy_listen_bind_param
      }
      ,
      mode    => 'http',
      options => $haproxy_listen_options,
    }

    haproxy::balancermember { 'keystone_admin':
      listening_service => 'keystone_admin',
      ports             => '35357',
    }

    haproxy::listen { 'keystone_public':
      bind    => {
        "$public_vip:5000"   => $haproxy_listen_bind_param,
        "$internal_vip:5000" => $haproxy_listen_bind_param
      }
      ,
      mode    => 'http',
      options => $haproxy_listen_options,
    }

    haproxy::balancermember { 'keystone_public':
      listening_service => 'keystone_public',
      ports             => '5000',
    }
  }

  if $glance {
    haproxy::listen { 'glance_registry':
      bind => {
        "$public_vip:9191"   => $haproxy_listen_bind_param,
        "$internal_vip:9191" => $haproxy_listen_bind_param
      }
      ,
    }

    haproxy::balancermember { 'glance_registry':
      listening_service => 'glance_registry',
      ports             => '9191',
    }

    haproxy::listen { 'glance_api':
      bind    => {
        "$public_vip:9292"   => $haproxy_listen_bind_param,
        "$internal_vip:9292" => $haproxy_listen_bind_param
      }
      ,
      mode    => 'http',
      options => $haproxy_listen_options,
    }

    haproxy::balancermember { 'glance_api':
      listening_service => 'glance_api',
      ports             => '9292',
    }
  }

  if $cinder {
    haproxy::listen { 'cinder':
      bind    => {
        "$public_vip:8776"   => $haproxy_listen_bind_param,
        "$internal_vip:8776" => $haproxy_listen_bind_param
      }
      ,
      mode    => 'http',
      options => $haproxy_listen_options,
    }

    haproxy::balancermember { 'cinder':
      listening_service => 'cinder_api',
      ports             => '8776',
    }
  }

  if $neutron {
    haproxy::listen { 'neutron':
      bind    => {
        "$public_vip:9696"   => $haproxy_listen_bind_param,
        "$internal_vip:9696" => $haproxy_listen_bind_param
      }
      ,
      mode    => 'http',
      options => $haproxy_listen_options,
    }

    haproxy::balancermember { 'neutron':
      listening_service => 'neutron',
      ports             => '9696',
    }
  }

  if $nova {
    haproxy::listen { 'nova_metadata':
      bind => {
        "$internal_vip:8775" => $haproxy_listen_bind_param
      }
      ,
    }

    haproxy::balancermember { 'nova_metadata':
      listening_service => 'nova_metadata',
      ports             => '8775',
    }

    haproxy::listen { 'nova_novncproxy':
      bind    => {
        "$public_vip:6080"  => $haproxy_listen_bind_param,
        "$public_vip:13080" => union($haproxy_listen_bind_param, [
          'ssl',
          'crt',
          $service_certificate])
      }
      ,
      options => {
        balance => 'source',
        timeout => 'tunnel 1h',
      }
    }

    haproxy::balancermember { 'nova_novncproxy':
      listening_service => 'nova_novncproxy',
      ports             => '6080',
    }

    haproxy::listen { 'nova_osapi':
      bind    => {
        "$public_vip:8774"   => $haproxy_listen_bind_param,
        "$internal_vip:8774" => $haproxy_listen_bind_param
      }
      ,
      mode    => 'http',
      options => $haproxy_listen_options,
    }

    haproxy::balancermember { 'nova_osapi':
      listening_service => 'nova_osapi',
      ports             => '8774',
    }
  }

  if $horizon {
    haproxy::listen { 'horizon':
      bind    => {
        "$public_vip:80"  => $haproxy_listen_bind_param,
        "$public_vip:443" => union($haproxy_listen_bind_param, [
          'ssl',
          'crt',
          $service_certificate])
      }
      ,
      mode    => 'http',
      options => {
        cookie       => 'SERVERID insert indirect nocache',
        option       => ['forwardfor', 'httpclose'],
        http-request => [
          'set-header X-Forwarded-Proto https if { ssl_fc }',
          'set-header X-Forwarded-Proto http if !{ ssl_fc }',
          'redirect scheme https if !{ ssl_fc }'],
      }
    }

    haproxy::balancermember { 'horizon':
      listening_service => 'horizon',
      ports             => '80',
      define_cookies    => true,
    }
  }

  if $ceilometer {
    haproxy::listen { 'ceilometer':
      bind    => {
        "$public_vip:8777"   => $haproxy_listen_bind_param,
        "$internal_vip:8777" => $haproxy_listen_bind_param
      }
      ,
      mode    => 'http',
      options => $haproxy_listen_options,
    }

    haproxy::balancermember { 'ceilometer':
      listening_service => 'ceilometer',
      ports             => '8777',
    }
  }

  if $gnocchi {
    haproxy::listen { 'gnocchi':
      bind    => {
        "$public_vip:8041"   => $haproxy_listen_bind_param,
        "$internal_vip:8041" => $haproxy_listen_bind_param
      }
      ,
      mode    => 'http',
      options => $haproxy_listen_options,
    }

    haproxy::balancermember { 'gnocchi':
      listening_service => 'gnocchi',
      ports             => '8041',
    }
  }

  if $aodh {
    haproxy::listen { 'aodh':
      bind    => {
        "$public_vip:8042"   => $haproxy_listen_bind_param,
        "$internal_vip:8042" => $haproxy_listen_bind_param
      }
      ,
      mode    => 'http',
      options => $haproxy_listen_options,
    }

    haproxy::balancermember { 'aodh':
      listening_service => 'aodh',
      ports             => '8042',
    }
  }

  if $::hostname == $bootstrap_node {
    Class['::haproxy'] ->
    pacemaker::resource::ip { "ip-$admin_vip": ip_address => $admin_vip, } ->
    pacemaker::resource::ip { "ip-$public_vip": ip_address => $public_vip, } ->
    pacemaker::resource::ip { "ip-$internal_vip": ip_address => $internal_vip, } ->
    exec { 'haproxy-ready':
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/scp ${controller_2_hostname}:/etc/haproxy/haproxy.cfg /tmp/haproxy.cfg2 && diff /etc/haproxy/haproxy.cfg /tmp/haproxy.cfg2 && \
                    /bin/scp ${controller_3_hostname}:/etc/haproxy/haproxy.cfg /tmp/haproxy.cfg3 && diff /etc/haproxy/haproxy.cfg /tmp/haproxy.cfg3",
      unless    => "/bin/scp ${controller_2_hostname}:/etc/haproxy/haproxy.cfg /tmp/haproxy.cfg2 && diff /etc/haproxy/haproxy.cfg /tmp/haproxy.cfg2 && \
                    /bin/scp ${controller_3_hostname}:/etc/haproxy/haproxy.cfg /tmp/haproxy.cfg3 && diff /etc/haproxy/haproxy.cfg /tmp/haproxy.cfg3",
    } ->
    pacemaker::resource::service { 'haproxy':
      op_params    => 'start timeout=200s stop timeout=200s',
      clone_params => true,
    } ->
    pacemaker::constraint::base { "order-ip-$admin_vip-haproxy-clone-Optional":
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => "ip-$admin_vip",
      second_action     => 'start',
      second_resource   => 'haproxy-clone',
      constraint_params => 'kind=Optional',
    } ->
    pacemaker::constraint::colocation { "colocation-ip-$admin_vip-haproxy-clone-INFINITY":
      source => "ip-$admin_vip",
      target => 'haproxy-clone',
      score  => 'INFINITY',
    } ->
    pacemaker::constraint::base { "order-ip-$public_vip-haproxy-clone-Optional":
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => "ip-$public_vip",
      second_action     => 'start',
      second_resource   => 'haproxy-clone',
      constraint_params => 'kind=Optional',
    } ->
    pacemaker::constraint::colocation { "colocation-ip-$public_vip-haproxy-clone-INFINITY":
      source => "ip-$public_vip",
      target => 'haproxy-clone',
      score  => 'INFINITY',
    } ->
    pacemaker::constraint::base { "order-ip-$internal_vip-haproxy-clone-Optional":
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => "ip-$internal_vip",
      second_action     => 'start',
      second_resource   => 'haproxy-clone',
      constraint_params => 'kind=Optional',
    } ->
    pacemaker::constraint::colocation { "colocation-ip-$internal_vip-haproxy-clone-INFINITY":
      source => "ip-$internal_vip",
      target => 'haproxy-clone',
      score  => 'INFINITY',
    } ->
    exec { 'haproxy-ready-rm':
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/rm -f /tmp/haproxy.cfg2 && \
                    /bin/rm -f /tmp/haproxy.cfg3",
      unless    => "/bin/rm -f /tmp/haproxy.cfg2 && \
                    /bin/rm -f /tmp/haproxy.cfg3",
    }
  }
}
