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

  pacemaker_property { 'stonith-enabled':
    ensure => 'present',
    value  => false,
  } ->
  pacemaker_property { 'no-quorum-policy':
    ensure => 'present',
    value  => false,
  } ->
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
    value  => '3min',
  }

  #  if $::hostname == $bootstrap_node {
  #    $setup_cluster = true
  #  } else {
  #    $setup_cluster = false
  #  }
  #
  #  class { '::pacemaker':
  #    hacluster_pwd => $hacluster_pwd,
  #  } ->
  #  class { '::pacemaker::corosync':
  #    cluster_members => $cluster_members,
  #    cluster_name    => $cluster_name,
  #    # cluster_setup_extras => $cluster_setup_extras,
  #    manage_fw       => $manage_fw,
  #    remote_authkey  => $remote_authkey,
  #    setup_cluster   => $setup_cluster,
  #  }

  #  if $::hostname == $bootstrap_node {
  #    pacemaker::property { 'stonith-enabled':
  #      property => 'stonith-enabled',
  #      value    => false,
  #    } ->
  #    #    pacemaker::property { 'no-quorum-policy':
  #    #      property => 'no-quorum-policy',
  #    #      value    => 'ignore',
  #    #    } ->
  #    pacemaker::property { 'pe-warn-series-max':
  #      property => 'pe-warn-series-max',
  #      value    => '1000',
  #    } ->
  #    pacemaker::property { 'pe-input-series-max':
  #      property => 'pe-input-series-max',
  #      value    => '1000',
  #    } ->
  #    pacemaker::property { 'pe-error-series-max':
  #      property => 'pe-error-series-max',
  #      value    => '1000',
  #    } ->
  #    pacemaker::property { 'cluster-recheck-interval':
  #      property => 'cluster-recheck-interval',
  #      value    => '3min',
  #    }
  #  }
}
