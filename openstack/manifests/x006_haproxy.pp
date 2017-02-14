class openstack::x006_haproxy (
  $admin_password   = 'admin1234',
  $redis_password   = 'redis1234',
  $controller_vip   = '192.168.0.130',
  $controller_1     = '192.168.0.131',
  $controller_2     = '192.168.0.132',
  $controller_3     = '192.168.0.133',
  $bootstrap_node   = 'controller-1',
  $manage_resources = false,) {
  class { 'haproxy':
    service_ensure   => $manage_resources,
    service_manage   => $manage_resources,
    global_options   => {
      daemon  => '',
      user    => 'haproxy',
      group   => 'haproxy',
      log     => "/dev/log local0",
      chroot  => '/var/lib/haproxy',
      pidfile => '/var/run/haproxy.pid',
      maxconn => '20480',
      stats   => 'socket /var/lib/haproxy/stats',
      ssl-default-bind-ciphers => '!SSLv2:kEECDH:kRSA:kEDH:kPSK:+3DES:!aNULL:!eNULL:!MD5:!EXP:!RC4:!SEED:!IDEA:!DES',
      ssl-default-bind-options => 'no-sslv3',
    }
    ,
    defaults_options => {
      log     => 'global',
      stats   => 'enable',
      option  => 'redispatch',
      retries => '3',
      maxconn => '4096',
      mode    => 'tcp',
      timeout => [
        'http-request 10s',
        'queue 2m',
        'connect 10s',
        'client 2m',
        'server 2m',
        'check 10s',
        ],
    }
    ,
  }

  haproxy::listen { 'stats':
    bind    => {
      "${controller_vip}:1993" => ['transparent']
    }
    ,
    mode    => 'http',
    options => {
      monitor-uri => '/status',
      stats       => [
        'enable',
        'uri /',
        'realm Haproxy\ Statistics',
        "auth admin:${admin_password}",
        'refresh 30s',
        ],
    }
  }

  haproxy::listen { 'mysql':
    bind    => {
      "${controller_vip}:3306" => ['transparent']
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
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '3306',
    options           => 'backup check inter 1s on-marked-down shutdown-sessions port 9200',
  }

  haproxy::listen { 'redis':
    bind    => {
      "${controller_vip}:6379" => ['transparent']
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
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '6379',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  haproxy::listen { 'keystone_admin':
    bind    => {
      "${controller_vip}:35357" => ['transparent']
    }
    ,
    mode    => 'http',
    options => {
      http-request => ['set-header X-Forwarded-Proto https if { ssl_fc }', 'set-header X-Forwarded-Proto http if !{ ssl_fc }'],
    }
  }

  haproxy::balancermember { 'keystone_admin':
    listening_service => 'keystone_admin',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '35357',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  haproxy::listen { 'keystone_public':
    bind    => {
      "${controller_vip}:5000" => ['transparent']
    }
    ,
    mode    => 'http',
    options => {
      http-request => ['set-header X-Forwarded-Proto https if { ssl_fc }', 'set-header X-Forwarded-Proto http if !{ ssl_fc }'],
    }
  }

  haproxy::balancermember { 'keystone_public':
    listening_service => 'keystone_public',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '5000',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  haproxy::listen { 'glance_api':
    bind    => {
      "${controller_vip}:9292" => ['transparent']
    }
    ,
    mode    => 'http',
    options => {
      http-request => ['set-header X-Forwarded-Proto https if { ssl_fc }', 'set-header X-Forwarded-Proto http if !{ ssl_fc }'],
    }
  }

  haproxy::balancermember { 'glance_api':
    listening_service => 'glance_api',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '9292',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  haproxy::listen { 'glance_registry':
    bind => {
      "${controller_vip}:9191" => ['transparent']
    }
    ,
  }

  haproxy::balancermember { 'glance_registry':
    listening_service => 'glance_registry',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '9191',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  haproxy::listen { 'cinder':
    bind    => {
      "${controller_vip}:8776" => ['transparent']
    }
    ,
    mode    => 'http',
    options => {
      http-request => ['set-header X-Forwarded-Proto https if { ssl_fc }', 'set-header X-Forwarded-Proto http if !{ ssl_fc }'],
    }
  }

  haproxy::balancermember { 'cinder':
    listening_service => 'cinder',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '8776',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  haproxy::listen { 'neutron':
    bind    => {
      "${controller_vip}:9696" => ['transparent']
    }
    ,
    mode    => 'http',
    options => {
      http-request => ['set-header X-Forwarded-Proto https if { ssl_fc }', 'set-header X-Forwarded-Proto http if !{ ssl_fc }'],
    }
  }

  haproxy::balancermember { 'neutron':
    listening_service => 'neutron',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '9696',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  haproxy::listen { 'nova_metadata':
    bind => {
      "${controller_vip}:8775" => ['transparent']
    }
    ,
  }

  haproxy::balancermember { 'nova_metadata':
    listening_service => 'nova_metadata',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '8775',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  haproxy::listen { 'nova_novncproxy':
    bind    => {
      "${controller_vip}:6080" => ['transparent']
    }
    ,
    options => {
      balance => 'source',
      timeout => 'tunnel 1h',
    }
  }

  haproxy::balancermember { 'nova_novncproxy':
    listening_service => 'nova_novncproxy',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '6080',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  haproxy::listen { 'nova_osapi':
    bind    => {
      "${controller_vip}:8774" => ['transparent']
    }
    ,
    mode    => 'http',
    options => {
      http-request => ['set-header X-Forwarded-Proto https if { ssl_fc }', 'set-header X-Forwarded-Proto http if !{ ssl_fc }'],
    }
  }

  haproxy::balancermember { 'nova_osapi':
    listening_service => 'nova_osapi',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '8774',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  haproxy::listen { 'horizon':
    bind    => {
      "${controller_vip}:80"  => ['transparent'],
      "${controller_vip}:443" => ['transparent'],
    }
    ,
    mode    => 'http',
    options => {
      cookie => 'SERVERID insert indirect nocache',
      option => ['forwardfor'],
    }
  }

  haproxy::balancermember { 'horizon':
    listening_service => 'horizon',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => ['80', '443'],
    options           => "check fall 5 inter 2000 rise 2",
    define_cookies    => true,
  }

  haproxy::listen { 'ceilometer':
    bind    => {
      "${controller_vip}:8777" => ['transparent']
    }
    ,
    mode    => 'http',
    options => {
      http-request => ['set-header X-Forwarded-Proto https if { ssl_fc }', 'set-header X-Forwarded-Proto http if !{ ssl_fc }'],
    }
  }

  haproxy::balancermember { 'ceilometer':
    listening_service => 'ceilometer',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '8777',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  haproxy::listen { 'gnocchi':
    bind    => {
      "${controller_vip}:8041" => ['transparent']
    }
    ,
    mode    => 'http',
    options => {
      http-request => ['set-header X-Forwarded-Proto https if { ssl_fc }', 'set-header X-Forwarded-Proto http if !{ ssl_fc }'],
    }
  }

  haproxy::balancermember { 'gnocchi':
    listening_service => 'gnocchi',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '8041',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  haproxy::listen { 'aodh':
    bind    => {
      "${controller_vip}:8042" => ['transparent']
    }
    ,
    mode    => 'http',
    options => {
      http-request => ['set-header X-Forwarded-Proto https if { ssl_fc }', 'set-header X-Forwarded-Proto http if !{ ssl_fc }'],
    }
  }

  haproxy::balancermember { 'aodh':
    listening_service => 'aodh',
    server_names      => ['controller-1', 'controller-2', 'controller-3'],
    ipaddresses       => [$controller_1, $controller_2, $controller_3],
    ports             => '8042',
    options           => 'check fall 5 inter 2000 rise 2',
  }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::ip { "ip-${controller_vip}":
      ip_address => $controller_vip,
      require    => Class['haproxy'],
    } ->
    pacemaker::resource::service { 'haproxy':
      op_params    => 'start timeout=200s stop timeout=200s',
      clone_params => true,
    } ->
    pacemaker::constraint::base { "order-ip-${controller_vip}-haproxy-clone-Optional":
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => "ip-${controller_vip}",
      second_action     => 'start',
      second_resource   => 'haproxy-clone',
      constraint_params => 'kind=Optional',
    } ->
    pacemaker::constraint::colocation { "colocation-ip-${controller_vip}-haproxy-clone-INFINITY":
      source => "ip-${controller_vip}",
      target => 'haproxy-clone',
      score  => 'INFINITY',
    }
  }
}
