class openstack::x007_galera (
  $galera_servers        = 'controller-1,controller-2,controller-3',
  $bootstrap_node        = 'controller-1',
  $clustercheck_password = 'clustercheck1234',
  $mysql_config_file     = '/etc/my.cnf.d/galera.cnf',
  $manage_resources      = false,) {
  $mysql_server_options = {
    'mysqld' => {
      'skip-name-resolve'   => '1',
      'binlog_format'       => 'ROW',
      'default-storage-engine'         => 'innodb',
      'innodb_autoinc_lock_mode'       => '2',
      'innodb_locks_unsafe_for_binlog' => '1',
      'max_connections'     => '8192',
      'query_cache_size'    => '0',
      'query_cache_type'    => '0',
      'bind-address'        => $::hostname,
      'wsrep_provider'      => '/usr/lib64/galera/libgalera_smm.so',
      'wsrep_cluster_name'  => 'galera_cluster',
      'wsrep_slave_threads' => '1',
      'wsrep_certify_nonPK' => '1',
      'wsrep_max_ws_rows'   => '131072',
      'wsrep_max_ws_size'   => '1073741824',
      'wsrep_debug'         => '0',
      'wsrep_convert_LOCK_to_trx'      => '0',
      'wsrep_retry_autocommit'         => '1',
      'wsrep_auto_increment_control'   => '1',
      'wsrep_drupal_282555_workaround' => '0',
      'wsrep_causal_reads'  => '0',
      'wsrep_notify_cmd'    => undef,
      'wsrep_sst_method'    => 'rsync',
      'wsrep_cluster_address'          => "gcomm://${galera_servers}",
      'wsrep_on'            => 'ON',
    }
  }

  package { 'mariadb-server-galera': }

  class { '::mysql::server':
    config_file        => $mysql_config_file,
    override_options   => $mysql_server_options,
    create_root_user   => $manage_resources,
    create_root_my_cnf => $manage_resources,
    service_enabled    => $manage_resources,
    service_manage     => $manage_resources,
    require            => Package['mariadb-server-galera'],
  }

  exec { 'create-root-sysconfig-clustercheck':
    command => "/bin/echo 'MYSQL_USERNAME=root\nMYSQL_PASSWORD=\'\'\nMYSQL_HOST=localhost\n' > /etc/sysconfig/clustercheck",
    unless  => '/bin/test -e /etc/sysconfig/clustercheck && grep -q clustercheck /etc/sysconfig/clustercheck',
    require => Class['::mysql::server'],
  }

  xinetd::service { 'galera-monitor':
    port           => '9200',
    disable        => 'no',
    socket_type    => 'stream',
    protocol       => 'tcp',
    wait           => 'no',
    user           => 'root',
    group          => 'root',
    groups         => 'yes',
    server         => '/usr/bin/clustercheck',
    service_type   => 'UNLISTED',
    per_source     => 'UNLIMITED',
    log_on_success => '',
    log_on_failure => 'HOST',
    flags          => 'REUSE',
    require        => File['/etc/sysconfig/clustercheck'],
  }

  exec { 'galera-ready':
    timeout   => '3600',
    tries     => '360',
    try_sleep => '10',
    command   => '/usr/bin/clustercheck >/dev/null 2>&1',
    unless    => '/usr/bin/clustercheck >/dev/null 2>&1',
    require   => Exec['create-root-sysconfig-clustercheck'],
  }

  file { '/etc/sysconfig/clustercheck':
    ensure  => file,
    mode    => '0600',
    owner   => 'root',
    group   => 'root',
    content => "MYSQL_USERNAME=clustercheck\nMYSQL_PASSWORD=${clustercheck_password}\nMYSQL_HOST=localhost\n",
    require => Exec['galera-ready'],
  }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::ocf { 'galera':
      ensure          => 'present',
      ocf_agent_name  => 'heartbeat:galera',
      resource_params => "enable_creation=true wsrep_cluster_address='gcomm://${galera_servers}' additional_parameters='--open-files-limit=16384'",
      meta_params     => 'master-max=3 ordered=true',
      op_params       => 'promote timeout=300s on-fail=block',
      master_params   => true,
      require         => Exec['create-root-sysconfig-clustercheck'],
      before          => Exec['galera-ready'],
    }

    mysql_user { 'clustercheck@localhost':
      ensure        => 'present',
      password_hash => mysql_password($clustercheck_password),
      require       => Exec['galera-ready'],
    }

    mysql_grant { 'clustercheck@localhost/*.*':
      ensure     => 'present',
      options    => ['GRANT'],
      privileges => ['PROCESS'],
      table      => '*.*',
      user       => 'clustercheck@localhost',
      require    => Mysql_user['clustercheck@localhost'],
    }

    mysql_user { ['root@127.0.0.1', 'root@::1', '@localhost', '@%']:
      ensure  => 'absent',
      require => Exec['galera-ready'],
    }

    exec { 'delete user host like controller-%':
      command => '/usr/bin/mysql -e "delete from mysql.user where host like \'controller-%\';"',
      unless  => '/usr/bin/mysql -e "delete from mysql.user where host like \'controller-%\';"',
      require => Exec['galera-ready'],
    }

    mysql_database { 'test':
      ensure  => 'absent',
      require => Exec['galera-ready'],
    }
  }
}
