class openstack::x005_pacemaker (
  $bootstrap_node             = hiera('controller_1_hostname'),
  $cluster_members            = join(any2array([
    hiera('controller_1_hostname'),
    hiera('controller_2_hostname'),
    hiera('controller_3_hostname'),
  ]), ' '),
  $cluster_name               = join(any2array([
    hiera('cloud_name'),
    hiera('region_name'),
  ]), '-'),
  $hacluster_pwd              = hiera('hacluster_password'),
  $remote_authkey             = hiera('remote_authkey'),
  $manage_fw                  = false,
  $pacemaker_property         = { },
  $pacemaker_resource_default = { },
) {
  if $::hostname == $bootstrap_node {
    $setup_cluster = true
    create_resources('pacemaker_property', $pacemaker_property)
    create_resources('pacemaker_resource_default', $pacemaker_resource_default)
  } else {
    $setup_cluster = false
  }

  if $::hostname =~ /^*controller-\d*$/ {
    class { '::pacemaker':
      hacluster_pwd => $hacluster_pwd,
    } ->
    class { '::pacemaker::corosync':
      cluster_members => $cluster_members,
      cluster_name    => $cluster_name,
      remote_authkey  => $remote_authkey,
      manage_fw       => $manage_fw,
      setup_cluster   => $setup_cluster,
    }
  } elsif $::hostname =~ /^*novacompute-\d*$/ {
    package { 'pacemaker-remote':
      ensure => 'present',
    } ->
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
}
