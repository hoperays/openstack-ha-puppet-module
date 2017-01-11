class openstack::y007_compute (
  $nova_password    = 'nova1234',
  $neutron_password = 'neutron1234',
  $cluster_nodes    = ['controller-1','controller-2','controller-3'],
  $host             = 'controller-vip',
  $controller_vip   = '192.168.0.130',
  $rbd_secret_uuid  = '2ad6a20f-ffdd-460d-afba-04ab286f365f',
  $cinder_key       = 'AQB+RUpYfv+aIRAA4AbRb+XICXx+x+shF5AeZQ==',
  $remote_authkey   = 'remote1234',) {
  class { '::nova':
    rabbit_userid       => 'guest',
    rabbit_password     => 'guest',
    rabbit_hosts        => $cluster_nodes,
    rabbit_ha_queues    => true,
    auth_strategy       => 'keystone',
    glance_api_servers  => "http://${host}:9292",
    cinder_catalog_info => 'volumev2:cinderv2:publicURL',
  }

  class { '::nova::keystone::authtoken':
    auth_uri            => "http://${host}:5000/",
    auth_url            => "http://${host}:35357/",
    memcached_servers   => $cluster_nodes,
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    region_name         => 'RegionOne',
    project_name        => 'service',
    username            => 'nova',
    password            => $nova_password,
  }

  class { '::nova::compute':
    vnc_enabled          => true,
    vncserver_proxyclient_address    => $ipaddress_eth0,
    vncproxy_host        => $controller_vip,
    vncproxy_protocol    => 'http',
    vncproxy_port        => '6080',
    vncproxy_path        => '/vnc_auto.html',
    vnc_keymap           => 'en-us',
    reserved_host_memory => '512', # MB
    allow_resize_to_same_host        => true,
    resume_guests_state_on_host_boot => true,
    #
    enabled              => false,
    manage_service       => false,
  }

  class { '::nova::compute::libvirt':
    libvirt_virt_type        => 'kvm',
    vncserver_listen         => '0.0.0.0',
    migration_support        => true,
    libvirt_cpu_mode         => 'host-model', # 'custom'
    libvirt_cpu_model        => undef,        # 'core2duo'
    libvirt_disk_cachemodes  => ['network=writeback'],
    libvirt_hw_disk_discard  => 'unmap',
    libvirt_inject_password  => false,
    libvirt_inject_key       => false,
    libvirt_inject_partition => -2,
    #
    manage_libvirt_services  => false,
  }

  class { '::nova::compute::libvirt::services':
    libvirt_service_name  => 'libvirtd',
    virtlock_service_name => 'virtlockd',
    virtlog_service_name  => 'virtlogd',
    libvirt_virt_type     => 'kvm',
  }

  class { '::nova::compute::rbd':
    libvirt_rbd_user             => 'cinder',
    libvirt_rbd_secret_uuid      => $rbd_secret_uuid,
    libvirt_rbd_secret_key       => $cinder_key,
    libvirt_images_rbd_pool      => 'vms',
    libvirt_images_rbd_ceph_conf => '/etc/ceph/ceph.conf',
    rbd_keyring                  => 'client.cinder',
    ephemeral_storage            => true,
    manage_ceph_client           => false,
  }

  class { '::nova::network::neutron':
    neutron_auth_url                => "http://${host}:35357/v3",
    neutron_url                     => "http://${host}:9696",
    #
    neutron_auth_type               => 'v3password',
    neutron_project_domain_name     => 'default',
    neutron_user_domain_name        => 'default',
    neutron_region_name             => 'RegionOne',
    neutron_project_name            => 'service',
    neutron_username                => 'neutron',
    neutron_password                => $neutron_password,
    #
    neutron_url_timeout             => '30',
    neutron_ovs_bridge              => 'br-int',
    neutron_extension_sync_interval => '600',
    firewall_driver                 => 'nova.virt.firewall.NoopFirewallDriver',
    vif_plugging_is_fatal           => false,
    vif_plugging_timeout            => '0',
    dhcp_domain                     => 'novalocal',
  }

  class { '::neutron':
    auth_strategy       => 'keystone',
    #
    notification_driver => 'neutron.openstack.common.notifier.rpc_notifier',
    rabbit_user         => 'guest',
    rabbit_password     => 'guest',
    rabbit_hosts        => $cluster_nodes,
    rabbit_ha_queues    => true,
  }

  class { '::neutron::keystone::authtoken':
    auth_uri            => "http://${host}:5000/",
    auth_url            => "http://${host}:35357/",
    memcached_servers   => $cluster_nodes,
    auth_type           => 'password',
    project_domain_name => 'default',
    user_domain_name    => 'default',
    region_name         => 'RegionOne',
    project_name        => 'service',
    username            => 'neutron',
    password            => $neutron_password,
  }

  class { '::neutron::agents::ml2::ovs':
    tunnel_types       => ['vxlan'],
    vxlan_udp_port     => '4789',
    local_ip           => $::ipaddress_eth3,
    integration_bridge => 'br-int',
    tunnel_bridge      => 'br-tun',
    bridge_mappings    => ['physnet1:br-eth2'],
    firewall_driver    => 'neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver',
    l2_population      => false,
    #
    manage_service     => false,
    enabled            => false,
  }

  file { '/etc/sysconfig/network-scripts/ifcfg-eth2':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "NAME=eth2
DEVICE=eth2
TYPE=OVSPort
DEVICETYPE=ovs
OVS_BRIDGE=br-eth2
BOOTPROTO=none
ONBOOT=yes
",
  } ->
  file { '/etc/sysconfig/network-scripts/ifcfg-br-eth2':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "NAME=br-eth2
DEVICE=br-eth2
DEVICETYPE=ovs
OVSBOOTPROTO=none
TYPE=OVSBridge
BOOTPROTO=none
ONBOOT=yes
",
  } ->
  exec { 'ovs-vsctl add-br br-eth2':
    timeout   => '3600',
    tries     => '360',
    try_sleep => '10',
    command   => "/usr/bin/ovs-vsctl add-br br-eth2",
    unless    => "/usr/bin/ovs-vsctl list-ports br-eth2",
  } ->
  exec { 'ovs-vsctl add-port br-eth2 eth2':
    timeout   => '3600',
    tries     => '360',
    try_sleep => '10',
    command   => "/usr/bin/ovs-vsctl add-port br-eth2 eth2",
    unless    => "/usr/bin/ovs-vsctl list-ports br-eth2 | /usr/bin/grep eth2",
  }

  package { 'pacemaker-remote': } ->
  file { '/etc/pacemaker':
    ensure  => directory,
    mode    => '0750',
    owner   => 'hacluster',
    group   => 'haclient',
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
    ensure => 'running',
    enable => true,
  }
}
