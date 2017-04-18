class openstack::x004_ceph (
  $bootstrap_node              = hiera('controller_1_hostname'),
  # uuidgen
  $fsid                        = '',
  $cluster_name                = join(any2array([
    hiera('cloud_name'),
    hiera('region_name'),
  ]), '-'),
  $mon_initial_members         = join(any2array([
    hiera('controller_1_hostname'),
    hiera('controller_2_hostname'),
    hiera('controller_3_hostname'),
  ]), ','),
  $mon_host                    = join(any2array([
    hiera('controller_1_storage_ip'),
    hiera('controller_2_storage_ip'),
    hiera('controller_3_storage_ip'),
  ]), ','),
  $authentication_type         = '',
  $public_network              = '',
  $cluster_network             = '',
  $mon_osd_full_ratio          = '',
  $mon_osd_nearfull_ratio      = '',
  $osd_pool_default_size       = '',
  $osd_journal_size            = '',
  $filestore_xattr_use_omap    = false,
  $filestore_max_sync_interval = '',
  $osd_mkfs_type               = '',
  $osd_mkfs_options_xfs        = '',
  $osd_mount_options_xfs       = '',
  $osd_crush_chooseleaf_type   = '',
  # ceph-authtool --gen-print-key
  $mon_key                     = '',
  $controller_keys             = { },
  $cephstorage_keys            = { },
  $novacompute_keys            = { },
  $osds                        = { },
  $pools                       = { },
  $controller_as_cephstorage   = hiera('controller_as_cephstorage'),
  $novacompute_as_cephstorage  = hiera('novacompute_as_cephstorage'),
  # throttling backfill and recovery
  $osd_max_backfills           = '',
  $osd_recovery_max_active     = '',
  $osd_recovery_op_priority    = '',
) {
  class { '::ceph':
    fsid                     => $fsid,
    mon_initial_members      => $mon_initial_members,
    mon_host                 => $mon_host,
    authentication_type      => $authentication_type,
    public_network           => $public_network,
    cluster_network          => $cluster_network,
    mon_osd_full_ratio       => $mon_osd_full_ratio,
    mon_osd_nearfull_ratio   => $mon_osd_nearfull_ratio,
    osd_pool_default_size    => $osd_pool_default_size,
    osd_journal_size         => $osd_journal_size,
    osd_max_backfills        => $osd_max_backfills,
    osd_recovery_max_active  => $osd_recovery_max_active,
    osd_recovery_op_priority => $osd_recovery_op_priority,
  }

  ceph_config {
    'global/filestore_xattr_use_omap':
      value => $filestore_xattr_use_omap;

    'global/filestore_max_sync_interval':
      value => $filestore_max_sync_interval;

    'global/osd_mkfs_type':
      value => $osd_mkfs_type;

    'global/osd_mkfs_options_xfs':
      value => $osd_mkfs_options_xfs;

    'global/osd_mount_options_xfs':
      value => $osd_mount_options_xfs;

    'global/osd_crush_chooseleaf_type':
      value => $osd_crush_chooseleaf_type;
  }

  if $::hostname =~ /^*controller-\d*$/ {
    ceph::mon { $::hostname:
      # cluster => $cluster_name,
      key => $mon_key,
    }

    Ceph::Key {
      inject         => true,
      inject_as_id   => 'mon.',
      inject_keyring => "/var/lib/ceph/mon/ceph-${::hostname}/keyring",
    }
    create_resources('ceph::key', merge($controller_keys, $cephstorage_keys, $novacompute_keys))

    if $controller_as_cephstorage {
      create_resources('ceph::osd', $osds)
    }
  }

  if $::hostname =~ /^*novacompute-\d*$/ {
    create_resources('ceph::key', $novacompute_keys)

    if $novacompute_as_cephstorage {
      create_resources('ceph::key', $cephstorage_keys)
      create_resources('ceph::osd', $osds)
    }
  }

  if $::hostname =~ /^*cephstorage-\d*$/ {
    create_resources('ceph::key', $cephstorage_keys)
    create_resources('ceph::osd', $osds)
  }

  if $::hostname == $bootstrap_node {
    create_resources('ceph::pool', $pools)
  }
}
