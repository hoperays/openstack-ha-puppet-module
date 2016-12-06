class openstack::y001_keystone (
  $bootstrap_node    = 'controller-1',
  $keystone_password = 'keystone1234',
  $allowed_hosts     = ['%'],
  $admin_token       = 'e38f3dd7116ee3bc3dba',
  $cluster_nodes     = ['controller-1', 'controller-2', 'controller-3'],
  $host              = 'controller-vip',) {
  if $::hostname == $bootstrap_node {
    class { '::keystone::db::mysql':
      password      => $keystone_password,
      host          => 'localhost',
      allowed_hosts => $allowed_hosts,
    }
    $enable_fernet_setup = true
    $sync_db = true
  } else {
    $enable_fernet_setup = false
    $sync_db = false
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
    sync_db              => $sync_db,
    enabled              => false,
  }

  if $::hostname =~ /^controller-\d+$/ and $::hostname != $bootstrap_node {
    exec { 'rsync fernet keys':
      command => "/usr/bin/rsync -avzP ${bootstrap_node}:/etc/keystone/fernet-keys/ /etc/keystone/fernet-keys/ > /dev/null 2>&1",
      unless  => "/usr/bin/rsync -avzP ${bootstrap_node}:/etc/keystone/fernet-keys/ /etc/keystone/fernet-keys/ > /dev/null 2>&1",
      require => Class['::keystone'],
    }
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
