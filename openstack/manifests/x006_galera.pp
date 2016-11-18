class openstack::x006_galera (
  $galera_servers          = 'controller-1,controller-2,controller-3',
  $galera_master           = 'controller-1',
  $bind_address            = $::ipaddress_eth0,
  $root_password           = 'root1234',
  $status_password         = 'clustercheck1234',
  $mysql_max_connections   = '8192',
  $mysql_config_file       = '/etc/my.cnf.d/galera.cnf',
  $manage_resources        = false,
  $remove_default_accounts = true,) {
  $mysql_server_options = {
    'mysqld' => {
      'skip-name-resolve'   => '1',
      'binlog_format'       => 'ROW',
      'default-storage-engine'         => 'innodb',
      'innodb_autoinc_lock_mode'       => '2',
      'innodb_locks_unsafe_for_binlog' => '1',
      'query_cache_size'    => '0',
      'query_cache_type'    => '0',
      'bind-address'        => $::hostname,
      'max_connections'     => $mysql_max_connections,
      'open_files_limit'    => '-1',
      'wsrep_on'            => 'ON',
      'wsrep_provider'      => '/usr/lib64/galera/libgalera_smm.so',
      'wsrep_cluster_name'  => 'galera_cluster',
      'wsrep_cluster_address'          => "gcomm://${galera_servers}",
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
      'wsrep_sst_method'    => 'rsync',
      # 'wsrep_provider_options'        => "gmcast.listen_addr=tcp://${gmcast_listen_addr}:4567;",
    }
  }

  package { 'mariadb-server-galera': }

  class { '::mysql::server':
    config_file             => $mysql_config_file,
    override_options        => $mysql_server_options,
    create_root_user        => $manage_resources,
    create_root_my_cnf      => $manage_resources,
    service_manage          => $manage_resources,
    service_enabled         => $manage_resources,
    remove_default_accounts => $remove_default_accounts,
    require                 => Package['mariadb-server-galera']
  }

  file { '/etc/sysconfig/clustercheck':
    ensure  => file,
    mode    => '0600',
    owner   => 'root',
    group   => 'root',
    content => "MYSQL_USERNAME=clustercheck\nMYSQL_PASSWORD=$status_password\nMYSQL_HOST=localhost\n",
    require => Class['::mysql::server'],
  }

  mysql_user { 'clustercheck@localhost':
    ensure        => 'present',
    password_hash => mysql_password($status_password),
    require       => Class['::mysql::server'],
  }

  mysql_grant { 'clustercheck@localhost/*.*':
    ensure     => 'present',
    options    => ['GRANT'],
    privileges => ['PROCESS'],
    table      => '*.*',
    user       => 'clustercheck@localhost',
    require    => Mysql_user['clustercheck@localhost'],
  }

  xinetd::service { 'galera-monitor':
    port           => '9200',
    server         => '/usr/bin/clustercheck',
    per_source     => 'UNLIMITED',
    log_on_success => '',
    log_on_failure => 'HOST',
    flags          => 'REUSE',
    service_type   => 'UNLISTED',
    user           => 'root',
    group          => 'root',
    require        => [File['/etc/sysconfig/clustercheck'], Mysql_grant['clustercheck@localhost/*.*']],
  }

  if $::hostname == $galera_master {
    pacemaker_resource { 'galera':
      primitive_class    => 'ocf',
      primitive_provider => 'heartbeat',
      primitive_type     => 'galera',
      parameters         => {
        'enable_creation'       => true,
        'wsrep_cluster_address' => "gcomm://${galera_servers}",
        'additional_parameters' => '--open-files-limit=16384',
      }
      ,
      metadata           => {
        'master-max' => '3',
        'ordered'    => true,
      }
      ,
      operations         => {
        'promote' => {
          'timeout' => '300s',
          'on-fail' => 'block',
        }
        ,
      }
      ,
      complex_type       => 'master',
      require            => Xinetd::Service['galera-monitor'],
    }

    exec { 'galera-ready':
      command     => '/usr/bin/clustercheck >/dev/null',
      timeout     => 30,
      tries       => 180,
      try_sleep   => 10,
      environment => ['AVAILABLE_WHEN_READONLY=0'],
      require     => Pacemaker_resource['galera'],
    }

    Exec['galera-ready'] -> Mysql_database <| |>
  }
}
