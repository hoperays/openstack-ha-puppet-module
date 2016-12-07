class openstack::y001_keystone (
  $bootstrap_node    = 'controller-1',
  $keystone_password = 'keystone1234',
  $allowed_hosts     = ['%'],
  $admin_token       = 'e38f3dd7116ee3bc3dba',
  $cluster_nodes     = ['controller-1', 'controller-2', 'controller-3'],
  $host              = 'controller-vip',) {
  if $::hostname == $bootstrap_node {
    class { '::keystone::db::mysql':
      password      => $keystone_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    # $enable_fernet_setup = true
    $sync_db = true
  } else {
    # $enable_fernet_setup = false
    $sync_db = false
  }

  class { '::keystone':
    admin_token          => $admin_token,
    rabbit_hosts         => $cluster_nodes,
    rabbit_ha_queues     => true,
    admin_endpoint       => "http://${host}:35357/",
    public_endpoint      => "http://${host}:5000/",
    database_connection  => "mysql+pymysql://keystone:${keystone_password}@${host}/keystone",
    database_max_retries => '-1',
    public_bind_host     => $::hostname,
    admin_bind_host      => $::hostname,
    token_provider       => 'fernet',
    # enable_fernet_setup  => $enable_fernet_setup,
    sync_db              => $sync_db,
    manage_service       => false,
    enabled              => false,
  }

  if $::hostname == $bootstrap_node {
    exec { 'keystone-manage fernet_setup':
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone > /dev/null 2>&1",
      unless    => "/usr/bin/keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone > /dev/null 2>&1",
      require   => Class['::keystone'],
    }
  } elsif $::hostname =~ /^controller-\d+$/ {
    exec { 'rsync fernet keys':
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/rsync -avzP ${bootstrap_node}:/etc/keystone/fernet-keys/ /etc/keystone/fernet-keys/ > /dev/null 2>&1",
      unless    => "/usr/bin/rsync -avzP ${bootstrap_node}:/etc/keystone/fernet-keys/ /etc/keystone/fernet-keys/ > /dev/null 2>&1",
      require   => Class['::keystone'],
    }
  }

  class { 'apache':
    ip             => $::ipaddress_eth0,
    service_ensure => 'stopped',
    service_enable => false,
  }

  class { '::keystone::wsgi::apache':
    ssl             => false,
    bind_host       => $::ipaddress_eth0,
    admin_bind_host => $::ipaddress_eth0,
  }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::ocf { 'apache':
      ensure         => 'present',
      ocf_agent_name => 'heartbeat:apache',
      clone_params   => true,
      require        => Class['::keystone::wsgi::apache'],
    } ->
    keystone_service { 'identity':
      ensure      => 'present',
      type        => 'identity',
      description => 'OpenStack Identity Service',
    } ->
    keystone_endpoint { 'identity':
      ensure       => 'present',
      region       => 'RegionOne',
      admin_url    => "http://${host}:35357/v3",
      public_url   => "http://${host}:5000/v3",
      internal_url => "http://${host}:5000/v3",
    } ->
    keystone_domain { 'default':
      ensure      => 'present',
      enabled     => true,
      description => 'Default Domain',
    } ->
    keystone_tenant { 'admin':
      ensure      => 'present',
      enabled     => true,
      description => 'Admin Project',
      domain      => 'default',
    } ->
    keystone_user { 'admin':
      ensure   => 'present',
      enabled  => true,
      password => 'admin1234',
      # email    => 'admin@example.org',
      domain   => 'default',
    } ->
    keystone_role { 'admin': ensure => 'present', } ->
    keystone_user_role { 'admin::admin':
      ensure         => 'present',
      user           => 'admin',
      user_domain    => 'default',
      project        => 'admin',
      project_domain => 'default',
      roles          => ['admin'],
    } ->
    keystone_tenant { 'services':
      ensure      => 'present',
      enabled     => true,
      description => 'Services Project',
      domain      => 'default',
    }
  }
}
