class openstack::x004_ceph (
  $bootstrap_node              = 'controller-1',
  # uuidgen
  $fsid                        = '9dfaa171-db9e-48c5-af8c-c618cc3bfec4',
  $mon_initial_members         = 'controller-1,controller-2,controller-3',
  $mon_host                    = '192.168.104.131,192.168.104.132,192.168.104.133',
  $authentication_type         = 'cephx',
  $public_network              = '192.168.104.0/24',
  $cluster_network             = '192.168.105.0/24',
  $mon_osd_full_ratio          = '.80',
  $mon_osd_nearfull_ratio      = '.70',
  $osd_pool_default_size       = '3',
  $osd_journal_size            = '30720',
  $filestore_xattr_use_omap    = true,
  $filestore_max_sync_interval = '10',
  $osd_mkfs_type               = 'xfs',
  $osd_mkfs_options_xfs        = '-f -i size=2048',
  $osd_mount_options_xfs       = 'rw,noatime,inode64,logbsize=256k,delaylog',
  $osd_crush_chooseleaf_type   = '1',
  # ceph-authtool --gen-print-key
  $admin_key                   = 'AQDtZ+xX3678NxAAnWIyLVy2dVQ0wZePqWG09Q==',
  $mon_key                     = 'AQDuZ+xXWjN8JhAAEBD7j3EaFVhXQBJzjLdf2Q==',
  $bootstrap_mds_key           = 'AQAyGSxY9+bgNRAAdMFl/EjA6KM5hP1wBcDZog==',
  $bootstrap_osd_key           = 'AQBMdOxXzLkwHxAA8TeFuJyvG6/NHziVyb06bg==',
  $bootstrap_rgw_key           = 'AQClPkpYRsB1CxAAZ9hhExzByrXKbPiV1kDu5Q==',
  $openstack_key               = 'AQB+RUpYfv+aIRAA4AbRb+XICXx+x+shF5AeZQ==',) {
  class { 'ceph':
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

  if $::hostname =~ /^controller-\d+$/ {
    ceph::mon { $::hostname: key => $mon_key, }

    Ceph::Key {
      inject         => true,
      inject_as_id   => 'mon.',
      inject_keyring => "/var/lib/ceph/mon/ceph-${::hostname}/keyring",
    }

    ceph::key { 'client.admin':
      secret  => $admin_key,
      cap_mon => 'allow *',
      cap_osd => 'allow *',
      cap_mds => 'allow *',
    }

    ceph::key { 'client.bootstrap-mds':
      keyring_path => '/var/lib/ceph/bootstrap-mds/ceph.keyring',
      secret       => $bootstrap_mds_key,
      cap_mon      => 'allow profile bootstrap-mds',
    }

    ceph::key { 'client.bootstrap-osd':
      keyring_path => '/var/lib/ceph/bootstrap-osd/ceph.keyring',
      secret       => $bootstrap_osd_key,
      cap_mon      => 'allow profile bootstrap-osd',
    }

    ceph::key { 'client.bootstrap-rgw':
      keyring_path => '/var/lib/ceph/bootstrap-rgw/ceph.keyring',
      secret       => $bootstrap_rgw_key,
      cap_mon      => 'allow profile bootstrap-rgw',
    }

    ceph::key { 'client.openstack':
      secret  => $openstack_key,
      cap_mon => 'allow r',
      cap_osd => 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=backups, allow rwx pool=vms, allow rwx pool=images, allow rwx pool=metrics',
      mode    => '0644',
    }

  } elsif $::hostname =~ /^storage-\d+$/ {
    ceph::key { 'client.bootstrap-mds':
      keyring_path => '/var/lib/ceph/bootstrap-mds/ceph.keyring',
      secret       => $bootstrap_mds_key,
      cap_mon      => 'allow profile bootstrap-mds',
    }

    ceph::key { 'client.bootstrap-osd':
      keyring_path => '/var/lib/ceph/bootstrap-osd/ceph.keyring',
      secret       => $bootstrap_osd_key,
      cap_mon      => 'allow profile bootstrap-osd',
    }

    ceph::key { 'client.bootstrap-rgw':
      keyring_path => '/var/lib/ceph/bootstrap-rgw/ceph.keyring',
      secret       => $bootstrap_rgw_key,
      cap_mon      => 'allow profile bootstrap-rgw',
    }

    #    ceph::osd {
    #      '/dev/sdc':
    #        journal => '/dev/sdb';
    #
    #      '/dev/sdd':
    #        journal => '/dev/sdb';
    #    }
  } elsif $::hostname =~ /^compute-\d+$/ {
    ceph::key { 'client.openstack':
      secret  => $openstack_key,
      cap_mon => 'allow r',
      cap_osd => 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=backups, allow rwx pool=vms, allow rwx pool=images, allow rwx pool=metrics',
      mode    => '0644',
    }
  }

  if $::hostname == $bootstrap_node {
    ceph::pool {
      'rbd':
        ensure => 'absent';

      'volumes':
        pg_num => '64';

      'images':
        pg_num => '64';

      'backups':
        pg_num => '64';

      'vms':
        pg_num => '64';

      'metrics':
        pg_num => '64';
    }
  }
}
