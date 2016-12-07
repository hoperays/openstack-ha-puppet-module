class openstack::x002_hosts {
  host { 'pxeserver':
    ensure => present,
    ip     => '192.168.103.200',
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
  } ->
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
    content => 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDP4XkPBLjwgZ69L4TZND0813BW4OMUg3IutgcpS667sUzpbHkyMiRYBrIkM+7CXnllznadBIOk/sxVbC3ZJaKhVr4F8wbxYL63sWWPliaXVfomtRBETlezfLdupmqOye3+OFxuXVyxd3678A6f2nGoYM5FUghE65lTst/u3ZgqQneyrL3ajHFI1aNYyFh+0gZACeUY9f3NEQocIMgmCU5v60SZ6H3/6+SP3dqgOOl1WdKWzXtf1lDfP++vDy9wBHE0xUgwBB1OPZAc+oed9mnwlHSxZ2Vg6uxquCHpb96qTcuVRxIv/1rcnBfYb7k7HM4ZRAmgbg0MQy+5IyV9IF6b root@controller-1
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDP4XkPBLjwgZ69L4TZND0813BW4OMUg3IutgcpS667sUzpbHkyMiRYBrIkM+7CXnllznadBIOk/sxVbC3ZJaKhVr4F8wbxYL63sWWPliaXVfomtRBETlezfLdupmqOye3+OFxuXVyxd3678A6f2nGoYM5FUghE65lTst/u3ZgqQneyrL3ajHFI1aNYyFh+0gZACeUY9f3NEQocIMgmCU5v60SZ6H3/6+SP3dqgOOl1WdKWzXtf1lDfP++vDy9wBHE0xUgwBB1OPZAc+oed9mnwlHSxZ2Vg6uxquCHpb96qTcuVRxIv/1rcnBfYb7k7HM4ZRAmgbg0MQy+5IyV9IF6b root@controller-2
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDP4XkPBLjwgZ69L4TZND0813BW4OMUg3IutgcpS667sUzpbHkyMiRYBrIkM+7CXnllznadBIOk/sxVbC3ZJaKhVr4F8wbxYL63sWWPliaXVfomtRBETlezfLdupmqOye3+OFxuXVyxd3678A6f2nGoYM5FUghE65lTst/u3ZgqQneyrL3ajHFI1aNYyFh+0gZACeUY9f3NEQocIMgmCU5v60SZ6H3/6+SP3dqgOOl1WdKWzXtf1lDfP++vDy9wBHE0xUgwBB1OPZAc+oed9mnwlHSxZ2Vg6uxquCHpb96qTcuVRxIv/1rcnBfYb7k7HM4ZRAmgbg0MQy+5IyV9IF6b root@controller-3
',
    group   => 'root',
    owner   => 'root',
    mode    => '0400',
  }

  if $::hostname =~ /^controller-\d+$/ {
    file { 'id_rsa':
      ensure  => 'present',
      path    => '/root/.ssh/id_rsa',
      content => '-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAz+F5DwS48IGevS+E2TQ9PNdwVuDjFINyLrYHKUuuu7FM6Wx5
MjIkWAayJDPuwl55Zc52nQSDpP7MVWwt2SWioVa+BfMG8WC+t7Flj5Yml1X6JrUQ
RE5Xs3y3bqZqjsnt/jhcbl1csXd+u/AOn9pxqGDORVIIROuZU7Lf7t2YKkJ3sqy9
2oxxSNWjWMhYftIGQAnlGPX9zREKHCDIJglOb+tEmeh9/+vkj93aoDjpdVnSls17
X9ZQ3z/vrw8vcARxNMVIMAQdTj2QHPqHnfZp8JR0sWdlYOrsargh6W/eqk3LlUcS
L/9a3JwX2G+5OxzOGUQJoG4NDEMvuSMlfSBemwIDAQABAoIBAQC/vEgrOQDXG8bs
2cpfiBY/aro795qazg5f1RbP2PVmOsckuR8j1Cm/YxWl3JyIfBjedMrkUkiVw0l2
NJwpH9RbmSUVWa16ru/Zf+6bvDMF/JAIaZKCXfv4Gb0aerXn04oGo7dlOAmJyhyD
fYwPlqykT/2Q5HOqFd/K2j4/E/YIarJIW6E81NnmgCsLzp3ALS5ZnROO+/1HmG5z
zcP0Dc8Is7+VWJlnrMN1peGUbGrzmYe0c3FKEXAUkXYyhagBhASAiWjxW6nCk9yX
iGgBur0JBseymj4FKQOVOXIYDsgo8jocHuA3y8UrPvib9KblmA4aiMESIK86NFvS
CCLON6cRAoGBAOzILE1TlxiT3PWpLUkzIMXvZ/axzA4xyieC3sAFfzoAjz09jLXW
gYktIE7SEymcwGh4AR18HydxQpnNV68GBUfW/2MTjXaF6jtQ0Cw+x8iXFnk9YvRa
H/di0zs+e2JYJ77MT1QF1OYuzcZ5FMIbjNfsl13cMlM+3lPWh5mvWCc5AoGBAODA
y2/K5Lu48H1a3Mt6ypieNJExLBhBxwXIcuswd/luA34SFidF2FaOUXx24gdAA7by
A/zUysYmafIsqXoXHYxoBtAho/VQMIn/U14T1QH8yDDrfpNKiIfMOKQALtlMvR7Y
qK4mHfvHbpit7ru8yowYV6Grp1sCGgumwdP3/MBzAoGAULLoZnJWzMmYRSGjjY8f
XFZ72FhAc5YEj/LKeCdndR07tGOF0XOKMnZuzG5MmaIS8Yf02Ve0Rn0TddfGSqCC
rDlaUSoYzIxXiF/Ck1HSRUs5HZkOYLlWq7nCxC5HXv0sjpqTbs+N/+VzvHEH4iAB
oJXCAPtLK5QBshErpfVc1gECgYBy7uSZ1J3HyblhwVdrzu1PwoeLQCQWe3y1Xl42
G2Ee8r1ieQlPKA6LpNfS2FCZ+Ihtw7F6V68iSX6gU2qPfsajiIcDZFCeIFXSG/mc
AHRLQeN18NeXpuPO3gaRB27tvKpx3cXU2LU4jjHmbfvJka/amJAnospAZgC/uJUi
OozMNQKBgQCs1uzkc/UrWeh0yHqPlRQrfGi7jP0jJzHQ1zR9m+Ee41LQJA6PPdof
Ns8m8JdlBgKTlTI4y1rlIRgB1bZOYmyEjR4g5cMkn/xd4jO2eDRVcTRYY9Vt0DJz
fHiAV2iSID4k7AO+06xGz+aAsRyRxoyF6QhYjdfBWh6YY2oaM7fkqg==
-----END RSA PRIVATE KEY-----
',
      group   => 'root',
      owner   => 'root',
      mode    => '0600',
      require => File['.ssh'],
    } ->
    file { 'id_rsa.pub':
      ensure  => 'present',
      path    => '/root/.ssh/id_rsa.pub',
      content => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDP4XkPBLjwgZ69L4TZND0813BW4OMUg3IutgcpS667sUzpbHkyMiRYBrIkM+7CXnllznadBIOk/sxVbC3ZJaKhVr4F8wbxYL63sWWPliaXVfomtRBETlezfLdupmqOye3+OFxuXVyxd3678A6f2nGoYM5FUghE65lTst/u3ZgqQneyrL3ajHFI1aNYyFh+0gZACeUY9f3NEQocIMgmCU5v60SZ6H3/6+SP3dqgOOl1WdKWzXtf1lDfP++vDy9wBHE0xUgwBB1OPZAc+oed9mnwlHSxZ2Vg6uxquCHpb96qTcuVRxIv/1rcnBfYb7k7HM4ZRAmgbg0MQy+5IyV9IF6b root@${::hostname}
",
      group   => 'root',
      owner   => 'root',
      mode    => '0644',
      require => File['.ssh'],
    }
  }
}
