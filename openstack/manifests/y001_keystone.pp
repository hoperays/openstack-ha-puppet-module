class openstack::y001_keystone (
  $bootstrap_node           = hiera('controller_1_hostname'),
  $rabbit_userid            = hiera('rabbit_username'),
  $rabbit_password          = hiera('rabbit_password'),
  $admin_token              = hiera('admin_token'),
  $admin_username           = hiera('admin_username'),
  $admin_password           = hiera('admin_password'),
  $dbname                   = hiera('keystone_dbname'),
  $user                     = hiera('keystone_username'),
  $password                 = hiera('keystone_password'),
  $public_vip               = hiera('public_vip'),
  $internal_vip             = hiera('internal_vip'),
  $controller_1_internal_ip = hiera('controller_1_internal_ip'),
  $controller_2_internal_ip = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip = hiera('controller_3_internal_ip'),
  $admin_interface          = hiera('admin_interface'),
  $public_interface         = hiera('public_interface'),
  $internal_interface       = hiera('internal_interface'),
  $token_expiration         = '',
  $token_provider           = '',
  $token_driver             = '',
  $credential_keys_0        = '',
  $credential_keys_1        = '',
) {
  if $::hostname == $bootstrap_node {
    class { '::keystone::db::mysql':
      dbname        => $dbname,
      user          => $user,
      password      => $password,
      host          => 'localhost',
      allowed_hosts => [$internal_vip],
    }
    $sync_db = true
    Anchor['keystone::dbsync::end'] ->
    exec { "${dbname}-db-ready-echo":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/ssh ${controller_2_internal_ip} 'echo ok > /tmp/${dbname}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'echo ok > /tmp/${dbname}-db-ready'",
      unless    => "/bin/ssh ${controller_2_internal_ip} 'echo ok > /tmp/${dbname}-db-ready' && \
                    /bin/ssh ${controller_3_internal_ip} 'echo ok > /tmp/${dbname}-db-ready'",
    }
  } else {
    $sync_db = false
    Anchor['keystone::config::end'] ->
    exec { "${dbname}-db-ready":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/cat /tmp/${dbname}-db-ready | grep ok",
      unless    => "/bin/cat /tmp/${dbname}-db-ready | grep ok",
    } ->
    Anchor['keystone::service::begin'] ->
    exec { "${dbname}-db-ready-rm":
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/rm -f /tmp/${dbname}-db-ready",
      unless    => "/bin/rm -f /tmp/${dbname}-db-ready",
    }
  }

  class { '::keystone::db':
    database_max_retries    => '-1',
    database_db_max_retries => '-1',
    database_connection     => "mysql+pymysql://${user}:${password}@${internal_vip}/${dbname}",
  }

  class { '::keystone':
    admin_token           => $admin_token,
    admin_password        => $admin_password,
    notification_format   => 'basic',
    log_dir               => '/var/log/keystone',
    public_port           => '5000',
    public_bind_host      => $internal_interface,
    admin_port            => '35357',
    admin_bind_host       => $internal_interface,
    catalog_template_file => '/etc/keystone/default_catalog.templates',
    catalog_driver        => 'sql',
    credential_key_repository          => '/etc/keystone/credential-keys',
    fernet_key_repository => '/etc/keystone/fernet-keys',
    notification_driver   => 'messaging',
    rabbit_hosts          => [
      "${controller_1_internal_ip}:5672",
      "${controller_2_internal_ip}:5672",
      "${controller_3_internal_ip}:5672"],
    rabbit_use_ssl        => false,
    rabbit_userid         => $rabbit_userid,
    rabbit_password       => $rabbit_password,
    rabbit_ha_queues      => true,
    rabbit_heartbeat_timeout_threshold => '60',
    enable_proxy_headers_parsing       => true,
    token_expiration      => $token_expiration,
    token_provider        => $token_provider, # fernet
    token_driver          => $token_driver,
    revoke_by_id          => true,
    enable_ssl            => false,
    #
    sync_db               => $sync_db,
    enable_bootstrap      => $sync_db,
    # enable_fernet_setup => $sync_db,
    enable_credential_setup            => true,
    credential_keys       => {
      '/etc/keystone/credential-keys/0' => {
        content => $credential_keys_0,
      }
      ,
      '/etc/keystone/credential-keys/1' => {
        content => $credential_keys_1,
      }
      ,
    }
    ,
    service_name          => 'httpd',
    #
    purge_config          => true,
  }

  class { '::apache':
    ip => $internal_interface,
  }

  class { '::keystone::wsgi::apache':
    ssl             => false,
    bind_host       => $internal_interface,
    admin_bind_host => $internal_interface,
  }

  class { '::keystone::cors':
  }

  class { '::keystone::cron::token_flush':
  }

  keystone_config {
    'ec2/driver':
      value => 'keystone.contrib.ec2.backends.sql.Ec2';

    'security_compliance/lockout_failure_attempts':
      value => '6';

    'security_compliance/lockout_duration':
      value => '1800';

    # 'security_compliance/disable_user_account_days_inactive':
    #   value => '90';

    # 'security_compliance/password_expires_days':
    #   value => '90';

    # 'security_compliance/password_expires_ignore_user_ids':
    #   value => ['3a54353c9dcc44f690975ea768512f6a'];

    'security_compliance/password_regex':
      value => '^(?=.*\d)(?=.*[a-zA-Z]).{7,}$';

    'security_compliance/password_regex_description':
      value => 'Passwords must contain at least 1 letter, 1 digit, and be a minimum length of 7 characters.';

    'security_compliance/unique_last_password_count':
      value => '5';

    'security_compliance/minimum_password_age':
      value => '1';
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
      public_url     => "http://${public_vip}:5000",
      internal_url   => "http://${internal_vip}:5000",
      admin_url      => "http://${internal_vip}:35357",
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
    content => "# Clear any old environment that may conflict.
for key in $( set | awk '{FS=\"=\"}  /^OS_/ {print \$1}' ); do unset \$key ; done
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=${admin_username}
export OS_PASSWORD=${admin_password}
export OS_AUTH_URL=http://${internal_vip}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export PS1='[\u@\h \W(keystone_admin)]# '
",
  }
}
