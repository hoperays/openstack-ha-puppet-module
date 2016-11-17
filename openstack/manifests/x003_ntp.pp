class openstack::x003_ntp {
  class { 'ntp':
    servers           => $hostname ? {
      'controller-1' => ['time.pool.aliyun.com', '127.127.1.0'],
      'controller-2' => ['controller-1', '127.127.1.0'],
      'controller-3' => ['controller-1', 'controller-2', '127.127.1.0'],
      default        => ['controller-1', 'controller-2', 'controller-3'],
    },
    preferred_servers => $hostname ? {
      'controller-1' => ['time.pool.aliyun.com'],
      'controller-2' => ['controller-1'],
      'controller-3' => ['controller-1', 'controller-2'],
      default        => ['controller-1', 'controller-2', 'controller-3'],
    },
    iburst_enable     => true,
    interfaces        => [$ipaddress_eth0],
  }
}
