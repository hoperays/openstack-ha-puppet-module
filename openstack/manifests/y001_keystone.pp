class openstack::y001_keystone (
  $keystone_password = 'keystone1234',
  $host              = 'controller-vip',
  $cluster_nodes     = [
    'controller-1',
    'controller-2',
    'controller-3'],
  $bootstrap_node    = 'controller-1',
  $admin_token       = 'e38f3dd7116ee3bc3dba',) {
  if $::hostname == $bootstrap_node {
    $enable_fernet_setup = true
  } else {
    $enable_fernet_setup = false
  }

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
    enable_fernet_setup  => $enable_fernet_setup,
    verbose              => true,
    sync_db              => false,
    enabled              => false,
  }

  if $::hostname == $bootstrap_node {
    class { '::keystone::db::mysql':
      password => $keystone_password,
      host     => 'controller-vip',
    # allowed_hosts => $cluster_nodes,
    } ->
    class { '::keystone::db::sync': }
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
