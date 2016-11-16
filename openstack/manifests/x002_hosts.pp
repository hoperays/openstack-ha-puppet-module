class openstack::x002_hosts {
  host { 'pxeserver':
    ensure  => present,
    ip      => '192.168.103.200',
    require => Class['x001_firewall']
  } ->
  host { 'controller-vip':
    ensure => present,
    ip     => '192.168.0.130',
  } ->
  host { 'controller-1':
    ensure => present,
    ip     => '192.168.0.131',
  } ->
  host { 'controller-2':
    ensure => present,
    ip     => '192.168.0.132',
  } ->
  host { 'controller-3':
    ensure => present,
    ip     => '192.168.0.133',
  } ->
  host { 'compute-1':
    ensure => present,
    ip     => '192.168.0.134',
  } ->
  host { 'compute-2':
    ensure => present,
    ip     => '192.168.0.135',
  } ->
  host { 'compute-3':
    ensure => present,
    ip     => '192.168.0.136',
  }
}
