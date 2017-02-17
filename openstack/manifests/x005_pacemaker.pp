class openstack::x005_pacemaker (
  $bootstrap_node  = 'controller-1',
  $hacluster_pwd   = 'hacluster1234',
  $cluster_members = 'controller-1 controller-2 controller-3',
  $cluster_name    = 'openstack_cluster',
  $manage_fw       = false,
  $remote_authkey  = 'remote1234',) {
  if $::hostname == $bootstrap_node {
    $setup_cluster = true
  } else {
    $setup_cluster = false
  }

  if $::hostname =~ /^controller-\d+$/ {
    class { '::pacemaker': hacluster_pwd => $hacluster_pwd, } ->
    class { '::pacemaker::corosync':
      cluster_members => $cluster_members,
      cluster_name    => $cluster_name,
      manage_fw       => $manage_fw,
      remote_authkey  => $remote_authkey,
      setup_cluster   => $setup_cluster,
    }
  } elsif $::hostname =~ /^compute-\d+$/ {
    package { 'pacemaker-remote': ensure => 'present', } ->
    file { '/etc/pacemaker':
      ensure => directory,
      mode   => '0750',
      owner  => 'hacluster',
      group  => 'haclient',
    } ->
    file { '/etc/pacemaker/authkey':
      ensure  => file,
      mode    => '0640',
      owner   => 'hacluster',
      group   => 'haclient',
      content => $remote_authkey,
    } ->
    service { 'pacemaker_remote':
      name   => 'pacemaker_remote',
      ensure => 'stopped',
      enable => false,
    }
  }

  if $::hostname == $bootstrap_node {
    pacemaker_resource_default { 'resource-stickiness':
      ensure => 'present',
      value  => 'INFINITY',
    }

    pacemaker_property {
      'maintenance-mode':
        ensure => 'present',
        value  => false,;

      'stonith-enabled':
        ensure => 'present',
        value  => false,;
    }
  }
}
