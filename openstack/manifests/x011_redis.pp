class openstack::x011_redis (
  $bootstrap_node   = hiera('controller_1_hostname'),
  $bind             = hiera('internal_interface'),
  $redis_password   = hiera('redis_password'),
  $redis_file_limit = '',
  $manage_resources = false,
) {
  class { '::redis':
    bind           => $bind,
    masterauth     => $redis_password,
    requirepass    => $redis_password,
    notify_service => $manage_resources,
    service_manage => $manage_resources,
  }

  file { '/etc/security/limits.d/redis.conf':
    content => inline_template(
      "redis soft nofile <%= @redis_file_limit %>\nredis hard nofile <%= @redis_file_limit %>\n"),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  package { 'python-redis':
    ensure => 'present',
  }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::ocf { 'redis':
      ocf_agent_name  => 'heartbeat:redis',
      master_params   => '',
      meta_params     => 'notify=true ordered=true interleave=true',
      resource_params => 'wait_last_known_master=true',
      op_params       => 'start timeout=200s stop timeout=200s',
      require         => [
        Class['::redis'],
        Package['python-redis'],
      ],
    }
  }
}
