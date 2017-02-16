class openstack::y001_keystone (
  $bootstrap_node    = 'controller-1',
  $admin_token       = 'xnYAbZ638Za2NnuwHB3MtxKF6',
  $admin_password    = 'admin1234',
  $keystone_password = 'keystone1234',
  $allowed_hosts     = ['%'],
  $username          = 'keystone',
  $controller_vip    = '192.168.0.130',
  $controller_1      = '192.168.0.131',
  $controller_2      = '192.168.0.132',
  $controller_3      = '192.168.0.133',) {
  if $::hostname == $bootstrap_node {
    Exec['galera-ready'] ->
    class { '::keystone::db::mysql':
      password      => $keystone_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    $sync_db = true
    Anchor['keystone::dbsync::end'] ->
    exec { "${username}-db-ready-echo":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/ssh controller-2 'echo ok > /tmp/${username}-db-ready' && \
                    /usr/bin/ssh controller-3 'echo ok > /tmp/${username}-db-ready'",
      unless    => "/usr/bin/ssh controller-2 'echo ok > /tmp/${username}-db-ready' && \
                    /usr/bin/ssh controller-3 'echo ok > /tmp/${username}-db-ready'",
    }
  } else {
    $sync_db = false
    Anchor['keystone::config::end'] ->
    exec { "${username}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/cat /tmp/${username}-db-ready | grep ok",
      unless    => "/usr/bin/cat /tmp/${username}-db-ready | grep ok",
    } ->
    Anchor['keystone::service::begin'] ->
    exec { "${username}-db-ready-rm":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/usr/bin/rm -f /tmp/${username}-db-ready",
      unless    => "/usr/bin/rm -f /tmp/${username}-db-ready",
    }
  }

  class { '::keystone::db':
    database_max_retries    => '-1',
    database_db_max_retries => '-1',
  }

  class { '::keystone':
    admin_token           => $admin_token,
    admin_password        => $admin_password,
    notification_format   => 'basic',
    log_dir               => '/var/log/keystone',
    # rpc_backend         => 'rabbit',
    public_port           => '5000',
    public_bind_host      => $::ipaddress_eth0,
    admin_bind_host       => $::ipaddress_eth0,
    admin_port            => '35357',
    catalog_template_file => '/etc/keystone/default_catalog.templates',
    catalog_driver        => 'sql',
    credential_key_repository          => '/etc/keystone/credential-keys',
    database_connection   => "mysql+pymysql://keystone:${keystone_password}@${controller_vip}/keystone",
    # admin_workers       => max($::processorcount, 2),
    # public_workers      => max($::processorcount, 2),
    fernet_key_repository => '/etc/keystone/fernet-keys',
    notification_driver   => 'messaging',
    rabbit_hosts          => ["${controller_1}:5672", "${controller_2}:5672", "${controller_3}:5672"],
    rabbit_use_ssl        => false,
    rabbit_userid         => 'guest',
    rabbit_password       => 'guest',
    rabbit_ha_queues      => true,
    rabbit_heartbeat_timeout_threshold => '60',
    enable_proxy_headers_parsing       => true,
    token_expiration      => '3600',
    token_provider        => 'uuid', # fernet
    token_driver          => 'sql',
    revoke_by_id          => true,
    enable_ssl            => false,
    #
    sync_db               => $sync_db,
    enable_bootstrap      => $sync_db,
    # enable_fernet_setup => $sync_db,
    enable_credential_setup            => true,
    credential_keys       => {
      '/etc/keystone/credential-keys/0' => {
        content => 'd_9esDjvKlaN_Og7ZCqEbvnv9iXphnjOfnt2ZfXq4C4=',
      }
      ,
      '/etc/keystone/credential-keys/1' => {
        content => '17tl2C3zlfMbDwaNpdiufd2zjsXpDPLF3i5Hm1Rd1rQ=',
      }
      ,
    }
    ,
    # default_domain      => 'default',
    manage_service        => false,
    enabled               => false,
    #
    purge_config          => true,
  }

  class { '::keystone::config':
  }

  class { '::apache':
    ip => $::ipaddress_eth0,
  }

  class { '::keystone::wsgi::apache':
    ssl             => false,
    bind_host       => $::ipaddress_eth0,
    admin_bind_host => $::ipaddress_eth0,
  }

  class { '::keystone::cors':
  }

  class { '::keystone::cron::token_flush':
  }

  if $::hostname == $bootstrap_node {
    class { '::keystone::roles::admin':
      email                  => 'admin@example.com',
      password               => $admin_password,
      admin                  => 'admin',
      admin_tenant           => 'admin',
      admin_roles            => ['admin'],
      service_tenant         => 'services',
      admin_tenant_desc      => 'admin tenant',
      service_tenant_desc    => 'Tenant for the openstack services',
      configure_user         => true,
      configure_user_role    => true,
      admin_user_domain      => undef,
      admin_project_domain   => undef,
      service_project_domain => undef,
      target_admin_domain    => undef,
    }

    class { '::keystone::endpoint':
      public_url     => "http://${controller_vip}:5000",
      internal_url   => "http://${controller_vip}:5000",
      admin_url      => "http://${controller_vip}:35357",
      region         => 'RegionOne',
      user_domain    => undef,
      project_domain => undef,
      default_domain => undef,
      version        => 'v3',
    }

    keystone_role { '_member_': ensure => present, }
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
export OS_AUTH_URL=http://${controller_vip}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export PS1='[\u@\h \W(keystone_admin)]# '
",
  }
}
