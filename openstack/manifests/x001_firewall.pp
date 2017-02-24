class openstack::x001_firewall {
  class { 'firewall': }

  # resources { 'firewall': purge => true, }

  if $::hostname =~ /^controller-\d+$/ {
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
      dport    => ['22'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '100 allow inbound ntp':
      dport    => ['123'],
      proto    => 'udp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '101 allow inbound ceph monitor':
      dport    => ['6789'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '101 allow inbound ceph osd':
      dport    => ['6800-7300'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '102 allow inbound pacemaker':
      dport    => ['2224', '3121', '21064'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '102 allow inbound corosync':
      dport    => ['5404', '5405'],
      proto    => 'udp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '103 allow inbound haproxy stats':
      dport    => ['1993', '13993'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '104 allow inbound mysql galera':
      dport    => ['873', '3306', '4444', '4567', '4568', '9200'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '105 allow inbound rabbitmq':
      dport    => ['4369', '5671', '5672', '15672', '25672'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '106 allow inbound memcached':
      dport    => ['11211'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '107 allow inbound mongodb':
      dport    => ['27017', '27018', '27019'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '108 allow inbound redis':
      dport    => ['6379', '26379'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '200 allow inbound keystone api':
      dport    => ['5000', '13000', '35357', '13357'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '201 allow inbound glance api':
      dport    => ['9292', '13292'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '201 allow inbound glance registory':
      dport    => ['9191'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '202 allow inbound cinder api':
      dport    => ['8776', '13776'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '203 allow inbound neutron api':
      dport    => ['9696', '13696'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '203 allow inbound neutron dhcp':
      dport    => ['67'],
      proto    => 'udp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '203 allow inbound neutron vxlan':
      dport    => ['4789'],
      proto    => 'udp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '203 allow inbound neutron gre':
      proto    => 'gre',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '203 allow inbound neutron vrrp':
      proto    => 'vrrp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '204 allow inbound nova api':
      dport    => ['8773', '3773', '8774', '13774', '8775', '13775'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '204 allow inbound nova novncproxy':
      dport    => ['6080', '13080'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '204 allow inbound nova compute':
      dport    => ['5900-5999', '16509', '16514', '49152-49215'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '205 allow inbound horizon':
      dport    => ['80', '443'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '206 allow inbound ceilometer api':
      dport    => ['8777', '13777'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '207 allow inbound gnocchi api':
      dport    => ['8041', '13041'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '207 allow inbound gnocchi statsd':
      dport    => ['8125'],
      proto    => 'udp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '208 allow inbound aodh api':
      dport    => ['8042', '13042'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '300 allow inbound zabbix server':
      dport    => ['10051'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '300 allow inbound zabbix agent':
      dport    => ['10050'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '300 allow inbound zabbix snmp':
      dport    => ['127'],
      proto    => 'udp',
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
  } elsif $::hostname =~ /^storage-\d+$/ {
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
      dport    => ['22'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '100 allow inbound ntp':
      dport    => ['123'],
      proto    => 'udp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '101 allow inbound ceph osd':
      dport    => ['6800-7300'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '300 allow inbound zabbix agent':
      dport    => ['10050'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '300 allow inbound zabbix snmp':
      dport    => ['127'],
      proto    => 'udp',
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
  } elsif $::hostname =~ /^compute-\d+$/ {
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
      dport    => ['22'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '100 allow inbound ntp':
      dport    => ['123'],
      proto    => 'udp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '102 allow inbound pacemaker':
      dport    => ['2224', '3121', '21064'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '203 allow inbound neutron vxlan':
      dport    => ['4789'],
      proto    => 'udp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '203 allow inbound neutron gre':
      proto    => 'gre',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '203 allow inbound neutron vrrp':
      proto    => 'vrrp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '204 allow inbound nova compute':
      dport    => ['5900-5999', '16509', '16514', '49152-49215'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '300 allow inbound zabbix agent':
      dport    => ['10050'],
      proto    => 'tcp',
      action   => 'accept',
      provider => 'iptables',
    } ->
    firewall { '300 allow inbound zabbix snmp':
      dport    => ['127'],
      proto    => 'udp',
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
}
