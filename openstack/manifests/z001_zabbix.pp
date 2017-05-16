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
  $wechat_cropid            = hiera('zabbix_wechat_cropid'),
  $wechat_secret            = hiera('zabbix_wechat_secret'),
  $wechat_appid             = hiera('zabbix_wechat_appid'),
  $wechat_partyid           = hiera('zabbix_wechat_partyid'),
  $internal_vip             = hiera('internal_vip'),
  $controller_2_internal_ip = hiera('controller_2_internal_ip'),
  $controller_3_internal_ip = hiera('controller_3_internal_ip'),
  $internal_interface       = hiera('internal_interface'),
  $manage_firewall          = false,
  $manage_repo              = false,
  $manage_resources         = false,
  $refreshactivechecks      = '',
  $unsafeuserparameters     = '',
  $zabbix_url               = '',
  $zabbix_server            = hiera('internal_fqdn'),
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
  $startpollers             = '',
  $startpollersunreachable  = '',
  $startdiscoverers         = '',
  $timeout                  = '',
) {
  if $::hostname == $bootstrap_node {
    $manage_database = true
    $api_password_md5 = md5($api_password)

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
                                                    diff /etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf2 && \
                                                                                  rm -f /tmp/zabbix_server.conf2 && \
                         scp ${controller_3_internal_ip}:/etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf3 && \
                                                    diff /etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf3 && \
                                                                                  rm -f /tmp/zabbix_server.conf3",
      unless    => "/bin/scp ${controller_2_internal_ip}:/etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf2 && \
                                                    diff /etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf2 && \
                                                                                  rm -f /tmp/zabbix_server.conf2 && \
                         scp ${controller_3_internal_ip}:/etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf3 && \
                                                    diff /etc/zabbix/zabbix_server.conf /tmp/zabbix_server.conf3 && \
                                                                                  rm -f /tmp/zabbix_server.conf3",
    } ->
    pacemaker::resource::service { "$pacemaker_resource":
      op_params => 'start timeout=200s stop timeout=200s',
      require   => [
        Class['::zabbix::server'],
        Class['::apache::mod::php'],
        Class['::zabbix::web'],
      ],
    } ->
    pacemaker::constraint::base { "order-ip-$internal_vip-$pacemaker_resource-Optional":
      constraint_type   => 'order',
      first_action      => 'start',
      first_resource    => "ip-$internal_vip",
      second_action     => 'start',
      second_resource   => "$pacemaker_resource",
      constraint_params => 'kind=Optional',
    } ->
    pacemaker::constraint::colocation { "colocation-$pacemaker_resource-ip-$internal_vip-INFINITY":
      source => "$pacemaker_resource",
      target => "ip-$internal_vip",
      score  => 'INFINITY',
    }

    if $manage_resources == true {
      create_resources('zabbix::template', $templates)
    }
  } elsif $::hostname =~ /^*controller-\d*$/ {
    $manage_database = false
  }

  class { '::zabbix::agent':
    manage_firewall      => $manage_firewall,
    manage_repo          => $manage_repo,
    manage_resources     => $manage_resources,
    sourceip             => $internal_interface,
    listenip             => $internal_interface,
    server               => $internal_vip,
    serveractive         => $internal_vip,
    hostname             => $::hostname,
    refreshactivechecks  => $refreshactivechecks,
    unsafeuserparameters => $unsafeuserparameters,
    timeout              => $timeout,
  }

  create_resources('zabbix::userparameters', $userparameters)

  if $::hostname =~ /^*controller-\d*$/ {
    class { '::zabbix::database':
      manage_database   => $manage_database,
      database_type     => $database_type,
      database_name     => $dbname,
      database_user     => $user,
      database_password => $password,
    } ->
    class { '::zabbix::server':
      manage_repo             => $manage_repo,
      manage_firewall         => $manage_firewall,
      manage_database         => $manage_database,
      database_type           => $database_type,
      database_name           => $dbname,
      database_user           => $user,
      database_password       => $password,
      sourceip                => $internal_vip,
      listenip                => $internal_vip,
      manage_service          => $manage_service,
      pacemaker               => $pacemaker,
      pacemaker_resource      => $pacemaker_resource,
      alertscriptspath        => $alertscriptspath,
      startpollers            => $startpollers,
      startpollersunreachable => $startpollersunreachable,
      startdiscoverers        => $startdiscoverers,
      timeout                 => $timeout,
    } ->
    class { '::apache::mod::php': } ->
    class { '::zabbix::web':
      manage_repo       => $manage_repo,
      manage_resources  => $manage_resources,
      zabbix_url        => $zabbix_url,
      zabbix_server     => $zabbix_server,
      database_type     => $database_type,
      database_name     => $dbname,
      database_user     => $user,
      database_password => $password,
      zabbix_timezone   => $zabbix_timezone,
      apache_listen_ip  => $internal_interface,
      apache_listenport => $apache_listenport,
      zabbix_api_user   => $api_user,
      zabbix_api_pass   => $api_password,
    } ->
    file { $alertscriptspath:
      ensure => directory,
      owner  => 'zabbix',
      group  => 'zabbix',
    } ->
    file { "$alertscriptspath/sendEmail":
      ensure => file,
      mode   => '0755',
      owner  => 'zabbix',
      group  => 'zabbix',
      source => $sendemail_source,
    } ->
    file { "$alertscriptspath/sendEmail.sh":
      ensure  => file,
      mode    => '0755',
      owner   => 'zabbix',
      group   => 'zabbix',
      content => "#!/bin/bash

$alertscriptspath/sendEmail \\
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
    } ->
    file { "$alertscriptspath/wechat.sh":
      ensure  => file,
      mode    => '0755',
      owner   => 'zabbix',
      group   => 'zabbix',
      content => "#!/bin/bash

CropID='$wechat_cropid'
Secret='$wechat_secret'
GURL=\"https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=\$CropID&corpsecret=\$Secret\"

Gtoken=$(/usr/bin/curl -s -G \$GURL | awk -F\\\" '{print \$4}')
PURL=\"https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=\$Gtoken\"

function body() {
local AppID=$wechat_appid
local UserID=\$1
local PartyID=$wechat_partyid
local Msg=$(echo \"$@\" | cut -d\" \" -f3-)
printf '{\\n'
printf '\\t\"touser\": \"'\"\$UserID\"\\\"\",\\n\"
printf '\\t\"toparty\": \"'\"\$PartyID\"\\\"\",\\n\"
printf '\\t\"msgtype\": \"text\",\\n'
printf '\\t\"agentid\": \"'\" \$AppID \"\\\"\",\\n\"
printf '\\t\"text\": {\\n'
printf '\\t\\t\"content\": \"'\"\$Msg\"\\\"\"\\n\"
printf '\\t},\\n'
printf '\\t\"safe\":\"0\"\\n'
printf '}\\n'
}
/usr/bin/curl --data-ascii \"$(body $@)\" \$PURL
",
    }
  }
}
