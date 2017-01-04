class openstack::z001_zabbix (
  $bootstrap_node    = 'controller-1',
  $nova_password     = 'nova1234',
  $nova_api_password = 'nova_api1234',
  $neutron_password  = 'neutron1234',
  $allowed_hosts     = ['%'],
  $cluster_nodes     = ['controller-1', 'controller-2', 'controller-3'],
  $host              = 'controller-vip',) {
  if $::hostname == $bootstrap_node {
    $sync_db = true
    $sync_db_api = true
  } else {
    $sync_db = false
    $sync_db_api = false
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
    server => '192.168.20.11',
  }
}
