class openstack::y007_compute (
  $nova_password     = 'nova1234',
  $nova_api_password = 'nova_api1234',
  $neutron_password  = 'neutron1234',
  $controller_vip    = '192.168.0.130',
  $controller_1      = '192.168.0.131',
  $controller_2      = '192.168.0.132',
  $controller_3      = '192.168.0.133',
  $remote_authkey    = 'remote1234',
  $rbd_secret_uuid   = '2ad6a20f-ffdd-460d-afba-04ab286f365f',
  $openstack_key     = 'AQB+RUpYfv+aIRAA4AbRb+XICXx+x+shF5AeZQ==',) {
  class { '::nova':
    database_connection                => "mysql+pymysql://nova:${nova_password}@${controller_vip}/nova",
    api_database_connection            => "mysql+pymysql://nova_api:${nova_api_password}@${controller_vip}/nova_api",
    database_max_retries               => '-1',
    rabbit_userid     => 'guest',
    rabbit_password   => 'guest',
    rabbit_ha_queues  => true,
    rabbit_use_ssl    => false,
    rabbit_heartbeat_timeout_threshold => '60',
    rabbit_hosts      => ["${controller_1}:5672", "${controller_2}:5672", "${controller_3}:5672"],
    auth_strategy     => 'keystone',
    #
    glance_api_servers                 => "http://${controller_vip}:9292",
    cinder_catalog_info                => 'volumev2:cinderv2:publicURL',
    log_dir           => '/var/log/nova',
    notify_api_faults => false,
    state_path        => '/var/lib/nova',
    report_interval   => '10',
    image_service     => 'nova.image.glance.GlanceImageService',
    notify_on_state_change             => 'vm_and_task_state',
    use_ipv6          => false,
    cpu_allocation_ratio               => '4.0',
    ram_allocation_ratio               => '1.0',
    disk_allocation_ratio              => '0.8',
    service_down_time => '60',
    host              => $::hostname,
    rootwrap_config   => '/etc/nova/rootwrap.conf',
    rpc_backend       => 'rabbit',
    notification_driver                => 'messagingv2',
    #
    purge_config      => true,
  }

  class { '::nova::cache':
    enabled          => true,
    backend          => 'oslo_cache.memcache_pool',
    memcache_servers => ["${controller_1}:11211", "${controller_2}:11211", "${controller_3}:11211"],
  }

  class { '::nova::compute':
    vnc_enabled          => true,
    vncserver_proxyclient_address     => $ipaddress_eth0,
    vncproxy_host        => $controller_vip,
    vncproxy_protocol    => 'http',
    vncproxy_port        => '6080',
    vncproxy_path        => '/vnc_auto.html',
    vnc_keymap           => 'en-us',
    reserved_host_memory => '2048', # MB
    heal_instance_info_cache_interval => '60',
    allow_resize_to_same_host         => true,
    resume_guests_state_on_host_boot  => true,
  }

  class { '::nova::compute::libvirt':
    libvirt_virt_type        => 'kvm',
    vncserver_listen         => '0.0.0.0',
    migration_support        => true,
    libvirt_cpu_mode         => 'host-model', # 'custom'
    libvirt_cpu_model        => undef, # 'core2duo'
    libvirt_disk_cachemodes  => ['network=writeback'],
    libvirt_hw_disk_discard  => 'unmap',
    libvirt_inject_password  => false,
    libvirt_inject_key       => false,
    libvirt_inject_partition => -2,
    #
    manage_libvirt_services  => true,
  }

  class { '::nova::compute::rbd':
    libvirt_rbd_user             => 'openstack',
    libvirt_rbd_secret_uuid      => $rbd_secret_uuid,
    libvirt_rbd_secret_key       => $openstack_key,
    libvirt_images_rbd_pool      => 'vms',
    libvirt_images_rbd_ceph_conf => '/etc/ceph/ceph.conf',
    rbd_keyring                  => 'client.openstack',
    ephemeral_storage            => true,
    manage_ceph_client           => false,
  }

  class { '::nova::network::neutron':
    neutron_auth_url                => "http://${controller_vip}:35357/v3",
    neutron_url                     => "http://${controller_vip}:9696",
    #
    neutron_auth_type               => 'v3password',
    neutron_project_domain_name     => 'default',
    neutron_user_domain_name        => 'default',
    neutron_region_name             => 'RegionOne',
    neutron_project_name            => 'services',
    neutron_username                => 'neutron',
    neutron_password                => $neutron_password,
    #
    neutron_url_timeout             => '30',
    neutron_ovs_bridge              => 'br-int',
    neutron_extension_sync_interval => '600',
    firewall_driver                 => 'nova.virt.firewall.NoopFirewallDriver',
    vif_plugging_is_fatal           => true, # false
    vif_plugging_timeout            => '300', # 0
    dhcp_domain                     => 'novalocal',
  }

  class { '::neutron':
    auth_strategy           => 'keystone',
    core_plugin             => 'neutron.plugins.ml2.plugin.Ml2Plugin',
    service_plugins         => [
      'router',
      'qos',
      'trunk',
      'firewall',
      'vpnaas',
      'neutron_lbaas.services.loadbalancer.plugin.LoadBalancerPluginv2'],
    allow_overlapping_ips   => true,
    host                    => $::hostname,
    global_physnet_mtu      => '1450',
    log_dir                 => '/var/log/neutron',
    rpc_backend             => 'rabbit',
    control_exchange        => 'neutron',
    # nova_url              => "http://${controller_vip}:8774/v2.1",
    root_helper             => 'sudo neutron-rootwrap /etc/neutron/rootwrap.conf',
    #
    rabbit_hosts            => ["${controller_1}:5672", "${controller_2}:5672", "${controller_3}:5672"],
    rabbit_use_ssl          => false,
    rabbit_user             => 'guest',
    rabbit_password         => 'guest',
    rabbit_ha_queues        => true,
    rabbit_heartbeat_timeout_threshold => '60',
    #
    dhcp_agents_per_network => '3',
    #
    purge_config            => true,
  }

  class { '::neutron::agents::ml2::ovs':
    tunnel_types               => ['vxlan'],
    vxlan_udp_port             => '4789',
    l2_population              => false,
    arp_responder              => false,
    enable_distributed_routing => false,
    drop_flows_on_start        => false,
    extensions                 => ['qos'],
    integration_bridge         => 'br-int',
    tunnel_bridge              => 'br-tun',
    local_ip                   => $::ipaddress_eth3,
    bridge_mappings            => ['physnet1:br-eth2'],
    firewall_driver            => 'neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver',
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
