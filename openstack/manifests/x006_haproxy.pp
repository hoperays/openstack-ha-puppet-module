class openstack::x006_haproxy (
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
      log     => "/dev/log local0",
      chroot  => '/var/lib/haproxy',
      pidfile => '/var/run/haproxy.pid',
      maxconn => '20480',
      user    => 'haproxy',
      group   => 'haproxy',
      daemon  => '',
      stats   => 'socket /var/lib/haproxy/stats'
    }
    ,
    defaults_options => {
      log     => 'global',
      stats   => 'enable',
      option  => ['redispatch'],
      retries => '3',
      timeout => [
        'http-request 10s',
        'queue 2m',
        'connect 10s',
        'client 2m',
        'server 2m',
        'check 10s',
        ],
      maxconn => '4096',
      mode    => 'tcp',
    }
    ,
  }

  haproxy::listen { 'monitor':
    bind    => "${controller_vip}:9300 transparent",
    mode    => 'http',
    options => {
      monitor-uri => '/status',
      stats       => [
        'enable',
        'uri /admin',
        'realm Haproxy\ Statistics',
        'auth admin:admin1234',
        'refresh 10s',
        ],
    }
  }

  haproxy::frontend { 'vip-db':
    bind    => "${controller_vip}:3306 transparent",
    options => {
      timeout         => 'client 90m',
      default_backend => 'db-vms-galera',
    }
  }

  haproxy::backend { 'db-vms-galera':
    options => {
      'option'      => 'httpchk',
      'stick-table' => 'type ip size 1000',
      'stick'       => 'on dst',
      'timeout'     => 'client 90m',
      'timeout'     => 'server 90m',
    }
  }

  haproxy::balancermember { 'controller-1-db':
    listening_service => 'db-vms-galera',
    server_names      => 'controller-1',
    ipaddresses       => "$controller_1",
    ports             => '3306',
    options           => 'check inter 1s port 9200 backup on-marked-down shutdown-sessions',
  }

  haproxy::balancermember { 'controller-2-db':
    listening_service => 'db-vms-galera',
    server_names      => 'controller-2',
    ipaddresses       => "$controller_2",
    ports             => '3306',
    options           => 'check inter 1s port 9200 backup on-marked-down shutdown-sessions',
  }

  haproxy::balancermember { 'controller-3-db':
    listening_service => 'db-vms-galera',
    server_names      => 'controller-3',
    ipaddresses       => "$controller_3",
    ports             => '3306',
    options           => 'check inter 1s port 9200 backup on-marked-down shutdown-sessions',
  }

  haproxy::frontend { 'vip-keystone-admin':
    bind    => "${controller_vip}:35357 transparent",
    options => {
      timeout         => 'client 600s',
      default_backend => 'keystone-admin-vms',
    }
  }

  haproxy::backend { 'keystone-admin-vms':
    options => {
      'balance' => 'roundrobin',
      'timeout' => 'server 600s',
    }
  }

  haproxy::balancermember { 'controller-1-keystone-admin':
    listening_service => 'keystone-admin-vms',
    server_names      => 'controller-1',
    ipaddresses       => "$controller_1",
    ports             => '35357',
    options           => 'check inter 1s on-marked-down shutdown-sessions',
  }

  haproxy::balancermember { 'controller-2-keystone-admin':
    listening_service => 'keystone-admin-vms',
    server_names      => 'controller-2',
    ipaddresses       => "$controller_2",
    ports             => '35357',
    options           => 'check inter 1s on-marked-down shutdown-sessions',
  }

  haproxy::balancermember { 'controller-3-keystone-admin':
    listening_service => 'keystone-admin-vms',
    server_names      => 'controller-3',
    ipaddresses       => "$controller_3",
    ports             => '35357',
    options           => 'check inter 1s on-marked-down shutdown-sessions',
  }

  haproxy::frontend { 'vip-keystone-public':
    bind    => "${controller_vip}:5000 transparent",
    options => {
      timeout         => 'client 600s',
      default_backend => 'keystone-public-vms',
    }
  }

  haproxy::backend { 'keystone-public-vms':
    options => {
      'balance' => 'roundrobin',
      'timeout' => 'server 600s',
    }
  }

  haproxy::balancermember { 'controller-1-keystone-public':
    listening_service => 'keystone-public-vms',
    server_names      => 'controller-1',
    ipaddresses       => "$controller_1",
    ports             => '5000',
    options           => 'check inter 1s on-marked-down shutdown-sessions',
  }

  haproxy::balancermember { 'controller-2-keystone-public':
    listening_service => 'keystone-public-vms',
    server_names      => 'controller-2',
    ipaddresses       => "$controller_2",
    ports             => '5000',
    options           => 'check inter 1s on-marked-down shutdown-sessions',
  }

  haproxy::balancermember { 'controller-3-keystone-public':
    listening_service => 'keystone-public-vms',
    server_names      => 'controller-3',
    ipaddresses       => "$controller_3",
    ports             => '5000',
    options           => 'check inter 1s on-marked-down shutdown-sessions',
  }

  haproxy::frontend { 'vip-glance-api':
    bind    => "${controller_vip}:9191 transparent",
    options => {
      default_backend => 'glance-api-vms',
    }
  }

  haproxy::backend { 'glance-api-vms':
    options => {
      'balance' => 'roundrobin',
    }
  }

  haproxy::balancermember { 'controller-1-glance-api':
    listening_service => 'glance-api-vms',
    server_names      => 'controller-1',
    ipaddresses       => "$controller_1",
    ports             => '9191',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-2-glance-api':
    listening_service => 'glance-api-vms',
    server_names      => 'controller-2',
    ipaddresses       => "$controller_2",
    ports             => '9191',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-3-glance-api':
    listening_service => 'glance-api-vms',
    server_names      => 'controller-3',
    ipaddresses       => "$controller_3",
    ports             => '9191',
    options           => 'check inter 1s',
  }

  haproxy::frontend { 'vip-glance-registry':
    bind    => "${controller_vip}:9292 transparent",
    options => {
      default_backend => 'glance-registry-vms',
    }
  }

  haproxy::backend { 'glance-registry-vms':
    options => {
      'balance' => 'roundrobin',
    }
  }

  haproxy::balancermember { 'controller-1-glance-registry':
    listening_service => 'glance-registry-vms',
    server_names      => 'controller-1',
    ipaddresses       => "$controller_1",
    ports             => '9292',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-2-glance-registry':
    listening_service => 'glance-registry-vms',
    server_names      => 'controller-2',
    ipaddresses       => "$controller_2",
    ports             => '9292',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-3-glance-registry':
    listening_service => 'glance-registry-vms',
    server_names      => 'controller-3',
    ipaddresses       => "$controller_3",
    ports             => '9292',
    options           => 'check inter 1s',
  }

  haproxy::frontend { 'vip-cinder':
    bind    => "${controller_vip}:8776 transparent",
    options => {
      default_backend => 'cinder-vms',
    }
  }

  haproxy::backend { 'cinder-vms':
    options => {
      'balance' => 'roundrobin',
    }
  }

  haproxy::balancermember { 'controller-1-cinder':
    listening_service => 'cinder-vms',
    server_names      => 'controller-1',
    ipaddresses       => "$controller_1",
    ports             => '8776',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-2-cinder':
    listening_service => 'cinder-vms',
    server_names      => 'controller-2',
    ipaddresses       => "$controller_2",
    ports             => '8776',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-3-cinder':
    listening_service => 'cinder-vms',
    server_names      => 'controller-3',
    ipaddresses       => "$controller_3",
    ports             => '8776',
    options           => 'check inter 1s',
  }

  haproxy::frontend { 'vip-neutron':
    bind    => "${controller_vip}:9696 transparent",
    options => {
      default_backend => 'neutron-vms',
    }
  }

  haproxy::backend { 'neutron-vms':
    options => {
      'balance' => 'roundrobin',
    }
  }

  haproxy::balancermember { 'controller-1-neutron':
    listening_service => 'neutron-vms',
    server_names      => 'controller-1',
    ipaddresses       => "$controller_1",
    ports             => '9696',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-2-neutron':
    listening_service => 'neutron-vms',
    server_names      => 'controller-2',
    ipaddresses       => "$controller_2",
    ports             => '9696',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-3-neutron':
    listening_service => 'neutron-vms',
    server_names      => 'controller-3',
    ipaddresses       => "$controller_3",
    ports             => '9696',
    options           => 'check inter 1s',
  }

  haproxy::frontend { 'vip-nova-vnc-novncproxy':
    bind    => "${controller_vip}:6080 transparent",
    options => {
      default_backend => 'nova-vnc-novncproxy-vms',
    }
  }

  haproxy::backend { 'nova-vnc-novncproxy-vms':
    options => {
      'balance' => 'roundrobin',
      'timeout' => 'tunnel 1h',
    }
  }

  haproxy::balancermember { 'controller-1-nova-vnc-novncproxy':
    listening_service => 'nova-vnc-novncproxy-vms',
    server_names      => 'controller-1',
    ipaddresses       => "$controller_1",
    ports             => '6080',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-2-nova-vnc-novncproxy':
    listening_service => 'nova-vnc-novncproxy-vms',
    server_names      => 'controller-2',
    ipaddresses       => "$controller_2",
    ports             => '6080',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-3-nova-vnc-novncproxy':
    listening_service => 'nova-vnc-novncproxy-vms',
    server_names      => 'controller-3',
    ipaddresses       => "$controller_3",
    ports             => '6080',
    options           => 'check inter 1s',
  }

  haproxy::frontend { 'vip-nova-metadata':
    bind    => "${controller_vip}:8775 transparent",
    options => {
      default_backend => 'nova-metadata-vms',
    }
  }

  haproxy::backend { 'nova-metadata-vms':
    options => {
      'balance' => 'roundrobin',
    }
  }

  haproxy::balancermember { 'controller-1-nova-metadata':
    listening_service => 'nova-metadata-vms',
    server_names      => 'controller-1',
    ipaddresses       => "$controller_1",
    ports             => '8775',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-2-nova-metadata':
    listening_service => 'nova-metadata-vms',
    server_names      => 'controller-2',
    ipaddresses       => "$controller_2",
    ports             => '8775',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-3-nova-metadata':
    listening_service => 'nova-metadata-vms',
    server_names      => 'controller-3',
    ipaddresses       => "$controller_3",
    ports             => '8775',
    options           => 'check inter 1s',
  }

  haproxy::frontend { 'vip-nova-api':
    bind    => "${controller_vip}:8774 transparent",
    options => {
      default_backend => 'nova-api-vms',
    }
  }

  haproxy::backend { 'nova-api-vms':
    options => {
      'balance' => 'roundrobin',
    }
  }

  haproxy::balancermember { 'controller-1-nova-api':
    listening_service => 'nova-api-vms',
    server_names      => 'controller-1',
    ipaddresses       => "$controller_1",
    ports             => '8774',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-2-nova-api':
    listening_service => 'nova-api-vms',
    server_names      => 'controller-2',
    ipaddresses       => "$controller_2",
    ports             => '8774',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-3-nova-api':
    listening_service => 'nova-api-vms',
    server_names      => 'controller-3',
    ipaddresses       => "$controller_3",
    ports             => '8774',
    options           => 'check inter 1s',
  }

  haproxy::frontend { 'vip-horizon':
    bind    => ["${controller_vip}:80 transparent", "${controller_vip}:443 transparent"],
    options => {
      timeout         => 'client 180s',
      default_backend => 'horizon-vms',
    }
  }

  haproxy::backend { 'horizon-vms':
    options => {
      'balance' => 'roundrobin',
      'timeout' => 'server 180s',
      'mode'    => 'http',
      'cookie'  => 'SERVERID insert indirect nocache',
    }
  }

  haproxy::balancermember { 'controller-1-horizon':
    listening_service => 'horizon-vms',
    server_names      => 'controller-1',
    ipaddresses       => "$controller_1",
    ports             => ['80', '443'],
    options           => 'check inter 1s cookie controller-1 on-marked-down shutdown-sessions',
  }

  haproxy::balancermember { 'controller-2-horizon':
    listening_service => 'horizon-vms',
    server_names      => 'controller-2',
    ipaddresses       => "$controller_2",
    ports             => ['80', '443'],
    options           => 'check inter 1s cookie controller-2 on-marked-down shutdown-sessions',
  }

  haproxy::balancermember { 'controller-3-horizon':
    listening_service => 'horizon-vms',
    server_names      => 'controller-3',
    ipaddresses       => "$controller_3",
    ports             => ['80', '443'],
    options           => 'check inter 1s cookie controller-3 on-marked-down shutdown-sessions',
  }

  haproxy::frontend { 'vip-ceilometer':
    bind    => "${controller_vip}:8777 transparent",
    options => {
      default_backend => 'ceilometer-vms',
    }
  }

  haproxy::backend { 'ceilometer-vms':
    options => {
      'balance' => 'roundrobin',
    }
  }

  haproxy::balancermember { 'controller-1-ceilometer':
    listening_service => 'ceilometer-vms',
    server_names      => 'controller-1',
    ipaddresses       => "$controller_1",
    ports             => '8777',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-2-ceilometer':
    listening_service => 'ceilometer-vms',
    server_names      => 'controller-2',
    ipaddresses       => "$controller_2",
    ports             => '8777',
    options           => 'check inter 1s',
  }

  haproxy::balancermember { 'controller-3-ceilometer':
    listening_service => 'ceilometer-vms',
    server_names      => 'controller-3',
    ipaddresses       => "$controller_3",
    ports             => '8777',
    options           => 'check inter 1s',
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
