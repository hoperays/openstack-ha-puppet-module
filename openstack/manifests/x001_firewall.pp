class openstack::x001_firewall {
  class { 'firewall': }

  resources { 'firewall': purge => true, }

  firewall { '000 accept all icmp':
    proto  => 'icmp',
    action => 'accept',
  } ->
  firewall { '001 accept all to lo interface':
    proto   => 'all',
    iniface => 'lo',
    action  => 'accept',
  } ->
  firewall { '002 reject local traffic not on loopback interface':
    iniface     => '! lo',
    proto       => 'all',
    destination => '127.0.0.1/8',
    action      => 'reject',
  } ->
  firewall { '003 accept related established rules':
    proto  => 'all',
    state  => ['RELATED', 'ESTABLISHED'],
    action => 'accept',
  } ->
  firewall { '004 allow inbound ssh':
    dport    => 22,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '005 allow inbound ntp':
    dport    => 123,
    proto    => 'udp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '006 allow inbound ceph monitor':
    dport    => 6789,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '007 allow inbound ceph osd':
    dport    => 6800-7300,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '008 allow inbound pacemaker web':
    dport    => 2224,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '009 allow inbound pacemaker remote':
    dport    => 3121,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '010 allow inbound pacemaker dlm':
    dport    => 21064,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '011 allow inbound corosync':
    dport    => [5404, 5405],
    proto    => 'udp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '012 allow inbound haproxy monitor':
    dport    => 9300,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '013 allow inbound mysql and mysqldump':
    dport    => 3306,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '014 allow inbound galera state snapshot transfer':
    dport    => 4444,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '015 allow inbound galera cluster replication tcp':
    dport    => 4567,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '016 allow inbound galera cluster replication udp':
    dport    => 4567,
    proto    => 'udp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '017 allow inbound galera incremental state transfer':
    dport    => 4568,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '018 allow inbound galera monitor':
    dport    => 9200,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '019 allow inbound rabbitmq epmd':
    dport    => 4369,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '020 allow inbound rabbitmq amqp 0-9-1 with and without tls':
    dport    => [5671, 5672],
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '021 allow inbound rabbitmq management plugin':
    dport    => 15672,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '022 allow inbound rabbitmq erlang distribution':
    dport    => 25672,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '023 allow inbound memcached':
    dport    => 11211,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '024 allow inbound mongodb':
    dport    => 27017,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '025 allow inbound redis':
    dport    => 6379,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '026 allow inbound redis sentinel':
    dport    => 26379,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '027 allow inbound keystone admin':
    dport    => 35357,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '028 allow inbound keystone public':
    dport    => 5000,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '029 allow inbound glance api':
    dport    => 9292,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '030 allow inbound glance registry':
    dport    => 9191,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '031 allow inbound cinder api':
    dport    => 8776,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '032 allow inbound neutron server':
    dport    => 9696,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '033 allow inbound neutron tunnel':
    dport    => 4789,
    proto    => 'udp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '034 allow inbound nova api':
    dport    => [8773, 8774, 8775],
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '035 allow inbound nova novncproxy':
    dport    => 6080,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '036 allow inbound ceilometer api':
    dport    => 8777,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '037 allow inbound ceilometer collector':
    dport    => 4952,
    proto    => 'udp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '038 allow inbound horizon':
    dport    => [80, 443],
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '039 allow inbound nova compute':
    dport    => 5900-5999,
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '040 allow inbound nova qemu migration':
    dport    => [16509, 49152-49215],
    proto    => 'tcp',
    action   => 'accept',
    provider => 'iptables',
  } ->
  firewall { '998 log all':
    proto => 'all',
    jump  => 'LOG',
  } ->
  firewall { '999 drop all':
    proto  => 'all',
    action => 'drop',
  }
}

