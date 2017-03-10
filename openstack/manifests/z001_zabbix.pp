class openstack::z001_zabbix (
  $bootstrap_node           = hiera('controller_1_hostname'),
  $dbname                   = hiera('zabbix_dbname'),
  $user                     = hiera('zabbix_username'),
  $password                 = hiera('zabbix_password'),
  $api_user                 = hiera('zabbix_api_username'),
  $api_password             = hiera('zabbix_api_password'),
  $mail_from                = hiera('zabbix_mail_from'),
  $mail_server              = hiera('zabbix_mail_server'),
  $mail_username            = hiera('zabbix_mail_username'),
  $mail_password            = hiera('zabbix_mail_password'),
  $internal_vip             = hiera('internal_vip'),
  $controller_1_internal_ip = hiera('controller_1_internal_ip'),
  $controller_2_internal_ip = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip = hiera('controller_3_internal_ip'),
  $internal_interface       = hiera('internal_interface'),
  $zabbix_servers           = join(any2array([
    hiera('controller_1_internal_ip'),
    hiera('controller_2_internal_ip'),
    hiera('controller_3_internal_ip')]), ','),
  $manage_firewall          = false,
  $manage_repo              = false,
  $manage_resources         = false,
  $refreshactivechecks      = '',
  $unsafeuserparameters     = '',
  $zabbix_url               = '',
  $zabbix_server            = '',
  $database_type            = '',
  $zabbix_timezone          = '',
  $manage_service           = false,
  $pacemaker                = false,
  $pacemaker_resource       = '',
  $apache_listenport        = '',
  $userparameters           = {},
  $templates                = {},
  $alertscriptspath         = '',
  $sendemail_source         = '',
) {
  if $::hostname == $bootstrap_node {
    $manage_database  = true
    $api_password_md5 = md5($api_password)

    mysql_database { $dbname:
      ensure  => present,
      charset => 'utf8',
      collate => 'utf8_general_ci',
    } ->
    mysql_user {
      "${user}@localhost":
        password_hash => mysql_password($password),;
      "${user}@${$controller_1_internal_ip}":
        password_hash => mysql_password($password),;
      "${user}@${$controller_2_internal_ip}":
        password_hash => mysql_password($password),;
      "${user}@${$controller_3_internal_ip}":
        password_hash => mysql_password($password),
    } ->
    mysql_grant {
      "${user}@localhost/${dbname}.*":
        options    => ['GRANT'],
        privileges => ['ALL'],
        table      => "${dbname}.*",
        user       => "${user}@localhost",;
      "${user}@${$controller_1_internal_ip}/${dbname}.*":
        options    => ['GRANT'],
        privileges => ['ALL'],
        table      => "${dbname}.*",
        user       => "${user}@${$controller_1_internal_ip}",;
      "${user}@${$controller_2_internal_ip}/${dbname}.*":
        options    => ['GRANT'],
        privileges => ['ALL'],
        table      => "${dbname}.*",
        user       => "${user}@${$controller_2_internal_ip}",;
      "${user}@${$controller_3_internal_ip}/${dbname}.*":
        options    => ['GRANT'],
        privileges => ['ALL'],
        table      => "${dbname}.*",
        user       => "${user}@${$controller_3_internal_ip}",
    } ->
    Class['::zabbix::database::mysql'] ->
    exec { "update administrator's password":
      command => "/bin/echo \"UPDATE $dbname.users SET passwd = '$api_password_md5' WHERE userid = '1';\" | \
                  /bin/mysql",
      unless  => "/bin/echo \"UPDATE $dbname.users SET passwd = '$api_password_md5' WHERE userid = '1';\" | \
                  /bin/mysql",
    } ->
    exec { 'zabbix-ready':
      timeout   => '3600',
      tries     => '360',
      try_sleep => '10',
      command   => "/bin/scp ${controller_2_internal_ip}:/etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf2 && \
                                                    diff /etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf2 | \
                                                                         grep -v 'ListenIP' | wc -l | grep '^2$' && \
                                                                                  rm -f /tmp/zabbix_server.conf2 && \
                         scp ${controller_3_internal_ip}:/etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf3 && \
                                                    diff /etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf3 | \
                                                                         grep -v 'ListenIP' | wc -l | grep '^2$' && \
                                                                                  rm -f /tmp/zabbix_server.conf3",
      unless    => "/bin/scp ${controller_2_internal_ip}:/etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf2 && \
                                                    diff /etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf2 | \
                                                                         grep -v 'ListenIP' | wc -l | grep '^2$' && \
                                                                                  rm -f /tmp/zabbix_server.conf2 && \
                         scp ${controller_3_internal_ip}:/etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf3 && \
                                                    diff /etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf3 | \
                                                                         grep -v 'ListenIP' | wc -l | grep '^2$' && \
                                                                                  rm -f /tmp/zabbix_server.conf3",
    } ->
    pacemaker::resource::service { "$pacemaker_resource":
      op_params => 'start timeout=200s stop timeout=200s',
      require   => [Class['::zabbix::server'],
                    Class['::apache::mod::php'],
                    Class['::zabbix::web']],
    }

    create_resources('zabbix::template', $templates)
  } elsif $::hostname =~ /^*controller-\d*$/ {
    $manage_database = false
  }

  class { '::zabbix::agent':
    manage_firewall      => $manage_firewall,
    manage_repo          => $manage_repo,
    manage_resources     => $manage_resources,
    sourceip             => $internal_interface,
    listenip             => $internal_interface,
    server               => $zabbix_servers,
    serveractive         => $zabbix_servers,
    hostname             => $::hostname,
    refreshactivechecks  => $refreshactivechecks,
    unsafeuserparameters => $unsafeuserparameters,
    userparameter        => $userparameter,
  }

  create_resources('zabbix::userparameters', $userparameters)

  if $::hostname =~ /^*controller-\d*$/ {
    class { '::zabbix::server':
      manage_repo        => $manage_repo,
      manage_firewall    => $manage_firewall,
      manage_database    => $manage_database,
      database_type      => $database_type,
      database_host      => $internal_vip,
      database_name      => $dbname,
      database_user      => $user,
      database_password  => $password,
      listenip           => $internal_interface,
      manage_service     => $manage_service,
      pacemaker          => $pacemaker,
      pacemaker_resource => $pacemaker_resource,
    } ->
    class { '::apache::mod::php': } ->
    class { '::zabbix::web':
      manage_repo       => $manage_repo,
      manage_resources  => $manage_resources,
      zabbix_url        => $zabbix_url,
      zabbix_server     => $zabbix_server,
      database_type     => $database_type,
      database_host     => $internal_vip,
      database_name     => $dbname,
      database_user     => $user,
      database_password => $password,
      zabbix_timezone   => $zabbix_timezone,
      apache_listen_ip  => $internal_interface,
      apache_listenport => $apache_listenport,
      zabbix_api_user   => $api_user,
      zabbix_api_pass   => $api_password,
    } ->
    file { "$alertscriptspath/sendEmail":
      ensure  => file,
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      source  => $sendemail_source,
    } ->
    file { "$alertscriptspath/sendEmail.sh":
      ensure  => file,
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => "#!/bin/bash

/usr/lib/zabbix/alertscripts/sendEmail \\
-f $mail_from \\
-s $mail_server \\
-xu $mail_username \\
-xp $mail_password \\
-t \"\$1\" \\
-u \"\$2\" \\
-m \"\$3\" \\
-o message-content-type=html \\
-o message-charset=utf8
",
    }
  }
}
