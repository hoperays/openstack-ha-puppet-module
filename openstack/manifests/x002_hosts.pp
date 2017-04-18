class openstack::x002_hosts (
  $hosts      = { },
  $id_rsa     = '',
  $id_rsa_pub = '',
) {
  create_resources('host', $hosts)

  file { '.ssh':
    ensure => 'directory',
    path   => '/root/.ssh/',
    group  => 'root',
    owner  => 'root',
    mode   => '0700',
  } ->
  file { 'authorized_keys':
    ensure  => 'present',
    path    => '/root/.ssh/authorized_keys',
    content => $id_rsa_pub,
    group   => 'root',
    owner   => 'root',
    mode    => '0400',
  }

  if $::hostname =~ /^*controller-\d*$/ {
    file { 'id_rsa':
      ensure  => 'present',
      path    => '/root/.ssh/id_rsa',
      content => $id_rsa,
      group   => 'root',
      owner   => 'root',
      mode    => '0600',
      require => File['.ssh'],
    } ->
    file { 'id_rsa.pub':
      ensure  => 'present',
      path    => '/root/.ssh/id_rsa.pub',
      content => $id_rsa_pub,
      group   => 'root',
      owner   => 'root',
      mode    => '0644',
      require => File['.ssh'],
    }
  }
}
