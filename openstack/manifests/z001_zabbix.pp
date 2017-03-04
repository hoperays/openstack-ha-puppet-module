class openstack::z001_zabbix (
  $bootstrap_node           = hiera('controller_1_hostname'),
  $dbname                   = hiera('zabbix_dbname'),
  $user                     = hiera('zabbix_username'),
  $password                 = hiera('zabbix_password'),
  $public_vip               = hiera('public_vip'),
  $internal_vip             = hiera('internal_vip'),
  $controller_1_internal_ip = hiera('controller_1_internal_ip'),
  $controller_2_internal_ip = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip = hiera('controller_3_internal_ip'),
  $internal_interface       = hiera('internal_interface'),
) {
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
    server => $internal_vip,
  }

  if $::hostname == $bootstrap_node {
  }
}
