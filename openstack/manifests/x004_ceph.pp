class openstack::x004_ceph (
  $bootstrap_node              = hiera('controller_1_hostname'),
  # uuidgen
  $fsid                        = '',
  $mon_initial_members         = join(any2array([
    hiera('controller_1_hostname'),
    hiera('controller_2_hostname'),
    hiera('controller_3_hostname')]), ','),
  $mon_host                    = join(any2array([
    hiera('controller_1_storage_ip'),
    hiera('controller_2_storage_ip'),
    hiera('controller_3_storage_ip')]), ','),
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
  $mon_key  = '',
  $controller_keys             = {},
  $cephstorage_keys            = {},
  $novacompute_keys            = {},
  $osds                        = {},
  $pools                       = {},
) {
  class { '::ceph':
    fsid                   => $fsid,
    mon_initial_members    => $mon_initial_members,
    mon_host               => $mon_host,
    authentication_type    => $authentication_type,
    public_network         => $public_network,
    cluster_network        => $cluster_network,
    mon_osd_full_ratio     => $mon_osd_full_ratio,
    mon_osd_nearfull_ratio => $mon_osd_nearfull_ratio,
    osd_pool_default_size  => $osd_pool_default_size,
    osd_journal_size       => $osd_journal_size,
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
    ceph::mon { $::hostname: key => $mon_key, }

    Ceph::Key {
      inject         => true,
      inject_as_id   => 'mon.',
      inject_keyring => "/var/lib/ceph/mon/ceph-${::hostname}/keyring",
    }
    create_resources('ceph::key', merge($controller_keys, $cephstorage_keys, $novacompute_keys))
  } elsif $::hostname =~ /^*cephstorage-\d*$/ {
    create_resources('ceph::key', $cephstorage_keys)
    create_resources('ceph::osd', $osds)
  } elsif $::hostname =~ /^*novacompute-\d*$/ {
    create_resources('ceph::key', $novacompute_keys)
  }

  if $::hostname == $bootstrap_node {
    create_resources('ceph::pool', $pools)
  }
}
