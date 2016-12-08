class openstack::x005_pacemaker (
  $cluster_password     = 'hacluster1234',
  $cluster_nodes        = 'controller-1 controller-2 controller-3',
  $bootstrap_node       = 'controller-1',
  $cluster_name         = 'openstack-cluster',
  $cluster_auth_key     = 'remote1234',
  $cluster_auth_enabled = true,) {
  class { 'pacemaker::new':
    firewall_corosync_manage => false,
    firewall_pcsd_manage     => false,
    cluster_password         => $cluster_password,
    cluster_nodes            => $cluster_nodes,
    cluster_name             => $cluster_name,
    cluster_auth_key         => $cluster_auth_key,
    cluster_auth_enabled     => $cluster_auth_enabled,
  }

  if $::hostname == $bootstrap_node {
    pacemaker_property { 'stonith-enabled':
      ensure => 'present',
      value  => false,
    }

    #  pacemaker_property { 'no-quorum-policy':
    #    ensure => 'present',
    #    value  => 'ignore',
    #  }

    pacemaker_property { 'pe-warn-series-max':
      ensure => 'present',
      value  => '1000',
    }

    pacemaker_property { 'pe-input-series-max':
      ensure => 'present',
      value  => '1000',
    }

    pacemaker_property { 'pe-error-series-max':
      ensure => 'present',
      value  => '1000',
    }

    pacemaker_property { 'cluster-recheck-interval':
      ensure => 'present',
      value  => '1min',
    }
  }

  exec { 'wait-for-settle':
    timeout   => '3600',
    tries     => '360',
    try_sleep => '10',
    command   => "/usr/sbin/pcs status | grep -q 'partition with quorum' > /dev/null 2>&1",
    unless    => "/usr/sbin/pcs status | grep -q 'partition with quorum' > /dev/null 2>&1",
    require   => Class['pacemaker::new'],
  }
}
