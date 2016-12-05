class openstack::y001_keystone (
  $keystone_password     = 'keystone1234',
  $host                  = 'controller-vip',
  $cluster_nodes         = [
    'controller-1',
    'controller-2',
    'controller-3'],
  $bootstrap_node        = 'controller-1',
  $admin_token           = 'e38f3dd7116ee3bc3dba',
  $fernet_key_repository = '/etc/keystone/fernet-keys',) {
  class { '::keystone':
    admin_token          => $admin_token,
    rabbit_hosts         => $cluster_nodes,
    rabbit_ha_queues     => true,
    admin_endpoint       => "http://${host}:%(admin_port)s/",
    public_endpoint      => "http://${host}:%(public_port)s/",
    database_connection  => "mysql+pymysql://keystone:${keystone_password}@${host}/keystone",
    database_max_retries => '-1',
    public_bind_host     => $::hostname,
    admin_bind_host      => $::hostname,
    token_provider       => 'fernet',
    verbose              => true,
    sync_db              => false,
    enabled              => false,
  }

  if $::hostname == $bootstrap_node {
    class { '::keystone::db::mysql':
      password      => $keystone_password,
      host          => 'controller-vip',
      allowed_hosts => $cluster_nodes,
    } ->
    class { '::keystone::db::sync': } ->
    exec { 'keystone-manage fernet_setup':
      command     => 'keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone',
      path        => '/usr/bin',
      refreshonly => true,
      creates     => "${fernet_key_repository}/0",
      notify      => Anchor['keystone::service::begin'],
      subscribe   => [Anchor['keystone::install::end'], Anchor['keystone::config::end']],
      tag         => 'keystone-exec',
    } ->
    keystone_config { 'fernet_tokens/key_repository': value => $fernet_key_repository; }
  }

  #  class { '::keystone::roles::admin':
  #    email    => undef,
  #    password => undef,
  #  }
  #
  #  class { '::keystone::endpoint':
  #    public_url => "https://${host}:5000/",
  #    admin_url  => "https://${host}:35357/",
  #  }
  #
  #  keystone_config { 'ssl/enable': value => true }
  #
  #  class { 'apache': }
  #
  #  class { '::keystone::wsgi::apache': ssl => true }
}
