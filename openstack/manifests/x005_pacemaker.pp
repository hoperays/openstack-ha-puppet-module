class openstack::x005_pacemaker (
  $bootstrap_node  = 'controller-1',
  $hacluster_pwd   = 'hacluster1234',
  $cluster_members = 'controller-1 controller-2 controller-3',
  $cluster_name    = 'openstack-cluster',
  $manage_fw       = false,
  $remote_authkey  = 'remote1234',) {
  class { 'pacemaker::new':
    firewall_corosync_manage => false,
    firewall_pcsd_manage     => false,
    cluster_password         => $hacluster_pwd,
    cluster_nodes            => $cluster_members,
    cluster_name             => $cluster_name,
    cluster_auth_key         => $remote_authkey,
    cluster_auth_enabled     => true,
  }

  exec { 'wait-for-settle':
    timeout   => '3600',
    tries     => '360',
    try_sleep => '10',
    command   => "/usr/sbin/pcs status | grep -q 'partition with quorum' > /dev/null 2>&1",
    unless    => "/usr/sbin/pcs status | grep -q 'partition with quorum' > /dev/null 2>&1",
    require   => Class['pacemaker::new'],
  }

  if $::hostname == $bootstrap_node {
    pacemaker_property { 'stonith-enabled':
      ensure => 'present',
      value  => false,
    } ->
    #    pacemaker_property { 'no-quorum-policy':
    #      ensure => 'present',
    #      value  => 'ignore',
    #    } ->
    pacemaker_property { 'pe-warn-series-max':
      ensure => 'present',
      value  => '1000',
    } ->
    pacemaker_property { 'pe-input-series-max':
      ensure => 'present',
      value  => '1000',
    } ->
    pacemaker_property { 'pe-error-series-max':
      ensure => 'present',
      value  => '1000',
    } ->
    pacemaker_property { 'cluster-recheck-interval':
      ensure => 'present',
      value  => '1min',
    }
  }
}
