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
    $sync_db = true
  } else {
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
    sync_db              => $sync_db,
    manage_service       => false,
    enabled              => false,
  }

  class { '::apache':
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
    exec { 'keystone-manage fernet_setup':
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone > /dev/null 2>&1",
      unless    => "/usr/bin/keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone > /dev/null 2>&1",
      require   => Class['::keystone'],
    } ->
    exec { 'keystone-ready':
      # wait for all nodes to complete the ::keystone::wsgi::apache installation
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/ssh controller-1 '/usr/bin/ls -l /etc/httpd/conf.d/10-keystone_wsgi_admin.conf' > /dev/null 2>&1 && \
                    /usr/bin/ssh controller-2 '/usr/bin/ls -l /etc/httpd/conf.d/10-keystone_wsgi_admin.conf' > /dev/null 2>&1 && \
                    /usr/bin/ssh controller-3 '/usr/bin/ls -l /etc/httpd/conf.d/10-keystone_wsgi_admin.conf' > /dev/null 2>&1",
      unless    => "/usr/bin/ssh controller-1 '/usr/bin/ls -l /etc/httpd/conf.d/10-keystone_wsgi_admin.conf' > /dev/null 2>&1 && \
                    /usr/bin/ssh controller-2 '/usr/bin/ls -l /etc/httpd/conf.d/10-keystone_wsgi_admin.conf' > /dev/null 2>&1 && \
                    /usr/bin/ssh controller-3 '/usr/bin/ls -l /etc/httpd/conf.d/10-keystone_wsgi_admin.conf' > /dev/null 2>&1",
    } ->
    pacemaker::resource::ocf { 'apache':
      ensure         => 'present',
      ocf_agent_name => 'heartbeat:apache',
      clone_params   => 'interleave=true',
    } ->
    # exec { 'sleep 30s': command => '/usr/bin/sleep 30', } ->
    keystone_service { 'keystone':
      ensure      => 'present',
      type        => 'identity',
      description => 'OpenStack Identity Service',
    } ->
    keystone_endpoint { 'keystone':
      ensure       => 'present',
      region       => 'RegionOne',
      admin_url    => "http://${host}:35357/v3",
      public_url   => "http://${host}:5000/v3",
      internal_url => "http://${host}:5000/v3",
    } ->
    exec { 'delete domain default':
      command => "/usr/bin/openstack --os-token ${admin_token} --os-url http://${host}:35357/v3 --os-identity-api-version 3 domain set --disable default && \
                  /usr/bin/openstack --os-token ${admin_token} --os-url http://${host}:35357/v3 --os-identity-api-version 3 domain delete default",
      onlyif  => "/usr/bin/openstack --os-token ${admin_token} --os-url http://${host}:35357/v3 --os-identity-api-version 3 domain show default | \
                  /usr/bin/grep 'The default domain' > /dev/null 2>&1",
    } ->
    keystone_domain { 'default':
      ensure      => 'present',
      description => 'Default Domain',
    } ->
    keystone_tenant { 'admin':
      ensure      => 'present',
      description => 'Admin Project',
      domain      => 'default',
    } ->
    keystone_user { 'admin':
      ensure   => 'present',
      password => 'admin1234',
      # email    => 'admin@example.org',
      domain   => 'default',
    } ->
    keystone_role { 'admin': ensure => 'present', } ->
    keystone_user_role { 'admin::default@admin::default':
      ensure         => 'present',
      user           => 'admin',
      user_domain    => 'default',
      project        => 'admin',
      project_domain => 'default',
      roles          => ['admin'],
    } ->
    keystone_tenant { 'service':
      ensure      => 'present',
      enabled     => true,
      description => 'Service Project',
      domain      => 'default',
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

  file { '/root/keystonerc_admin':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=admin1234
export OS_AUTH_URL=http://${host}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export PS1='[\u@\h \W(keystone_admin)]\$ '
",
  }
}
