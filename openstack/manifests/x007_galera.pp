class openstack::x007_galera (
  $bootstrap_node        = hiera('controller_1_hostname'),
  $bind_address          = $::hostname,
  $max_connections       = '',
  $galera_nodes          = join(any2array([
    hiera('controller_1_hostname'),
    hiera('controller_2_hostname'),
    hiera('controller_3_hostname')]), ','),
  $gmcast_listen_addr    = hiera('internal_interface'),
  $clustercheck_password = '',
  $mysql_config_file     = '',
  $manage_resources      = false,
) {
  $galera_nodes_count   = count(split($galera_nodes, ','))
  $mysql_server_options = {
    'mysqld' => {
      'skip-name-resolve'              => '1',
      'binlog_format'                  => 'ROW',
      'default-storage-engine'         => 'innodb',
      'innodb_autoinc_lock_mode'       => '2',
      'innodb_locks_unsafe_for_binlog' => '1',
      'innodb_file_per_table'          => 'ON',
      'query_cache_size'               => '0',
      'query_cache_type'               => '0',
      'bind-address'                   => $bind_address,
      'max_connections'                => $max_connections,
      'open_files_limit'               => '-1',
      'wsrep_on'                       => 'ON',
      'wsrep_provider'                 => '/usr/lib64/galera/libgalera_smm.so',
      'wsrep_cluster_name'             => 'galera_cluster',
      'wsrep_cluster_address'          => "gcomm://${galera_nodes}",
      'wsrep_slave_threads'            => '1',
      'wsrep_certify_nonPK'            => '1',
      'wsrep_max_ws_rows'              => '131072',
      'wsrep_max_ws_size'              => '1073741824',
      'wsrep_debug'                    => '0',
      'wsrep_convert_LOCK_to_trx'      => '0',
      'wsrep_retry_autocommit'         => '1',
      'wsrep_auto_increment_control'   => '1',
      'wsrep_drupal_282555_workaround' => '0',
      'wsrep_causal_reads'             => '0',
      'wsrep_sst_method'               => 'rsync',
      'wsrep_provider_options'         => "gmcast.listen_addr=tcp://${gmcast_listen_addr}:4567;",
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
    bind           => hiera('internal_interface'),
    port           => '9200',
    server         => '/bin/clustercheck',
    per_source     => 'UNLIMITED',
    log_on_success => '',
    log_on_failure => 'HOST',
    flags          => 'REUSE',
    service_type   => 'UNLISTED',
    user           => 'root',
    group          => 'root',
    require        => Exec['create-root-sysconfig-clustercheck'],
  }

  exec { 'galera-ready':
    timeout   => '3600',
    tries     => '360',
    try_sleep => '10',
    command   => '/bin/clustercheck >/dev/null 2>&1',
    unless    => '/bin/clustercheck >/dev/null 2>&1',
    require   => Exec['create-root-sysconfig-clustercheck'],
  }

  Exec['galera-ready'] -> Mysql_user <| |>
  Exec['galera-ready'] -> Mysql_database <| |>

  mysql_user { 'clustercheck@localhost':
    ensure        => 'present',
    password_hash => mysql_password($clustercheck_password),
  }

  mysql_grant { 'clustercheck@localhost/*.*':
    ensure     => 'present',
    options    => ['GRANT'],
    privileges => ['PROCESS'],
    table      => '*.*',
    user       => 'clustercheck@localhost',
  }

  file { '/etc/sysconfig/clustercheck':
    ensure  => file,
    mode    => '0600',
    owner   => 'root',
    group   => 'root',
    content => "MYSQL_USERNAME=clustercheck\nMYSQL_PASSWORD=${clustercheck_password}\nMYSQL_HOST=localhost\n",
    require => Mysql_grant['clustercheck@localhost/*.*'],
  }

  if $::hostname == $bootstrap_node {
    pacemaker::resource::ocf { 'galera':
      ensure          => 'present',
      ocf_agent_name  => 'heartbeat:galera',
      resource_params => "additional_parameters='--open-files-limit=16384' enable_creation=true wsrep_cluster_address='gcomm://${galera_nodes}'",
      meta_params     => "master-max=${galera_nodes_count} ordered=true",
      op_params       => 'promote timeout=300s on-fail=block',
      master_params   => true,
      require         => Exec['create-root-sysconfig-clustercheck'],
      before          => Exec['galera-ready'],
    }

    mysql_user { ['root@127.0.0.1', 'root@::1', '@localhost', '@%']: ensure => 'absent', }

    mysql_database { 'test': ensure => 'absent', }

    exec { 'delete user host like %controller-%':
      command => "/bin/echo \"DELETE FROM mysql.user WHERE host LIKE \'%controller-%\'; \
                  flush privileges;\" | \
                  /bin/mysql",
      unless  => "/bin/echo \"DELETE FROM mysql.user WHERE host LIKE \'%controller-%\'; \
                  flush privileges;\" | \
                  /bin/mysql",
      require => Exec['galera-ready'],
    }
  }
}
