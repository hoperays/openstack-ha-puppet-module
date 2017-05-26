class openstack::x003_ntp (
  $controller_1_hostname = hiera('controller_1_hostname'),
  $controller_2_hostname = hiera('controller_2_hostname'),
  $controller_3_hostname = hiera('controller_3_hostname'),
  $ntp_servers           = [],
  $iburst_enable         = false,
  $ntp_interfaces        = [
    hiera('admin_interface'),
    hiera('public_interface'),
    hiera('internal_interface'),
  ],
) {
  Host <||> -> Class['::ntp']

  class { '::ntp':
    servers           => $hostname ? {
      $controller_1_hostname => union($ntp_servers, ['127.127.1.0']),
      $controller_2_hostname => [
        $controller_1_hostname,
        '127.127.1.0',
      ],
      $controller_3_hostname => [
        $controller_1_hostname,
        $controller_2_hostname,
        '127.127.1.0',
      ],
      default                => [
        $controller_1_hostname,
        $controller_2_hostname,
        $controller_3_hostname,
      ],
    },
    preferred_servers => $hostname ? {
      $controller_1_hostname => $ntp_servers,
      default                => [$controller_1_hostname],
    },
    iburst_enable     => $iburst_enable,
    interfaces        => $ntp_interfaces,
  }
}
