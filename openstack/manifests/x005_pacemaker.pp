class openstack::x005_pacemaker (
  $bootstrap_node  = 'controller-1',
  $hacluster_pwd   = 'hacluster1234',
  $cluster_members = 'controller-1 controller-2 controller-3',
  $cluster_name    = 'openstack-cluster',
  $manage_fw       = false,
  $remote_authkey  = 'remote1234',) {
  if $::hostname == $bootstrap_node {
    $setup_cluster = true
  } else {
    $setup_cluster = false
  }

  anchor { '::pacemaker::begin': } ->
  class { '::pacemaker':
    hacluster_pwd => $hacluster_pwd, } ->
  anchor { '::pacemaker::end': } ->
  anchor { '::pacemaker::corosync::begin': } ->
  class { '::pacemaker::corosync':
    cluster_members => $cluster_members,
    cluster_name    => $cluster_name,
    # cluster_setup_extras => $cluster_setup_extras,
    manage_fw       => $manage_fw,
    remote_authkey  => $remote_authkey,
    setup_cluster   => $setup_cluster,
  } ->
  anchor { '::pacemaker::corosync::end': }

  if $::hostname == $bootstrap_node {
    pacemaker::property { 'maintenance-mode':
      property => 'maintenance-mode',
      value    => false,
    } ->
    pacemaker::property { 'stonith-enabled':
      property => 'stonith-enabled',
      value    => false,
    } ->
    pacemaker::property { 'osprole-controller-1':
      property => 'osprole',
      value    => 'controller',
      node     => 'controller-1',
    } ->
    pacemaker::property { 'osprole-controller-2':
      property => 'osprole',
      value    => 'controller',
      node     => 'controller-2',
    } ->
    pacemaker::property { 'osprole-controller-3':
      property => 'osprole',
      value    => 'controller',
      node     => 'controller-3',
    }
  }
}
