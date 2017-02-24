class openstack::z001_zabbix (
  $bootstrap_node   = 'controller-1',
  $zabbix_password  = 'zabbix1234',
  $allowed_hosts    = ['%'],
  $username         = 'zabbix',
  $api_public_vip   = '172.17.52.100',
  $api_internal_vip = '172.17.53.100',
  $controller_1     = '172.17.53.101',
  $controller_2     = '172.17.53.102',
  $controller_3     = '172.17.53.103',) {
  if $::hostname == $bootstrap_node {
    $manage_database = true
  } else {
    $manage_database = false
  }

  class { 'apache':
    mpm_module => 'prefork',
  }
  include apache::mod::php

  class { 'mysql::server': }

  class { 'zabbix':
    zabbix_url    => 'zabbix.example.com',
    database_type => 'mysql',
  }

  class { 'zabbix::agent':
    server => $api_internal_vip,
  }

  if $::hostname == $bootstrap_node {
  }
}
