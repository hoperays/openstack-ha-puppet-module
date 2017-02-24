class openstack::x011_redis (
  $bootstrap_node   = 'controller-1',
  $redis_password   = 'redis1234',
  $redis_file_limit = '10240',) {
  class { '::redis':
    bind           => $ipaddress_vlan53,
    masterauth     => $redis_password,
    requirepass    => $redis_password,
    #
    notify_service => false,
    service_manage => false,
  }

  file { '/etc/security/limits.d/redis.conf':
    content => inline_template("redis soft nofile <%= @redis_file_limit %>\nredis hard nofile <%= @redis_file_limit %>\n"),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  package { 'python-redis': ensure => 'present', }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::ocf { 'redis':
      ocf_agent_name  => 'heartbeat:redis',
      master_params   => '',
      meta_params     => 'notify=true ordered=true interleave=true',
      resource_params => 'wait_last_known_master=true',
      op_params       => 'start timeout=200s stop timeout=200s',
      require         => Class['::redis'],
    }
  }
}
