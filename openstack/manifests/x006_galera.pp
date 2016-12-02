class openstack::x006_galera (
  $galera_servers        = 'controller-1,controller-2,controller-3',
  $galera_master         = 'controller-1',
  $root_password         = 'root1234',
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
      # 'open_files_limit'    => '-1',
      # 'wsrep_provider_options'         => "gmcast.listen_addr=tcp://${::hostname}:4567;",
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

  exec { 'galera-ready':
    command     => '/usr/bin/clustercheck >/dev/null',
    timeout     => 30,
    tries       => 180,
    try_sleep   => 10,
    environment => ['AVAILABLE_WHEN_READONLY=0'],
    require     => Exec['create-root-sysconfig-clustercheck'],
  }

  if $::hostname == $galera_master {
    pcmk_resource { 'galera':
      ensure          => $ensure,
      resource_type   => "ocf:heartbeat:galera",
      resource_params => "enable_creation=true wsrep_cluster_address='gcomm://${galera_servers}' additional_parameters='--open-files-limit=16384'",
      meta_params     => "master-max=3 ordered=true",
      op_params       => "promote timeout=300s on-fail=block",
      master_params   => true,
      require         => Exec['create-root-sysconfig-clustercheck'],
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
  }

  class { 'mysql::server::account_security':
    require => Exec['galera-ready'],
  }

  file { '/etc/sysconfig/clustercheck':
    ensure  => file,
    mode    => '0600',
    owner   => 'root',
    group   => 'root',
    content => "MYSQL_USERNAME=clustercheck\nMYSQL_PASSWORD=${clustercheck_password}\nMYSQL_HOST=localhost\n",
    require => Exec['galera-ready'],
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
}
