#!/bin/bash

source /root/keystonerc_admin

openstack endpoint create --region cn-bj-1 keystone \
  admin http://admin.identity.examplecloud.com:35357
openstack endpoint create --region cn-bj-1 keystone \
  public http://public.identity.examplecloud.com:5000
openstack endpoint create --region cn-bj-1 keystone \
  internal http://internal.identity.examplecloud.com:5000

openstack endpoint create --region cn-bj-1 glance \
  admin http://admin.image.cn-bj-1.examplecloud.com:9292
openstack endpoint create --region cn-bj-1 glance \
  public http://public.image.cn-bj-1.examplecloud.com:9292
openstack endpoint create --region cn-bj-1 glance \
  internal http://internal.image.cn-bj-1.examplecloud.com:9292

openstack endpoint create --region cn-bj-1 cinder \
  admin http://admin.volume.cn-bj-1.examplecloud.com:8776/v1/%\(tenant_id\)s
openstack endpoint create --region cn-bj-1 cinder \
  public http://public.volume.cn-bj-1.examplecloud.com:8776/v1/%\(tenant_id\)s
openstack endpoint create --region cn-bj-1 cinder \
  internal http://internal.volume.cn-bj-1.examplecloud.com:8776/v1/%\(tenant_id\)s
openstack endpoint create --region cn-bj-1 cinderv2 \
  admin http://admin.volume.cn-bj-1.examplecloud.com:8776/v2/%\(tenant_id\)s
openstack endpoint create --region cn-bj-1 cinderv2 \
  public http://public.volume.cn-bj-1.examplecloud.com:8776/v2/%\(tenant_id\)s
openstack endpoint create --region cn-bj-1 cinderv2 \
  internal http://internal.volume.cn-bj-1.examplecloud.com:8776/v2/%\(tenant_id\)s
openstack endpoint create --region cn-bj-1 cinderv3 \
  admin http://admin.volume.cn-bj-1.examplecloud.com:8776/v3/%\(tenant_id\)s
openstack endpoint create --region cn-bj-1 cinderv3 \
  public http://public.volume.cn-bj-1.examplecloud.com:8776/v3/%\(tenant_id\)s
openstack endpoint create --region cn-bj-1 cinderv3 \
  internal http://internal.volume.cn-bj-1.examplecloud.com:8776/v3/%\(tenant_id\)s

openstack endpoint create --region cn-bj-1 neutron \
  admin http://admin.network.cn-bj-1.examplecloud.com:9696
openstack endpoint create --region cn-bj-1 neutron \
  public http://public.network.cn-bj-1.examplecloud.com:9696
openstack endpoint create --region cn-bj-1 neutron \
  internal http://internal.network.cn-bj-1.examplecloud.com:9696

openstack endpoint create --region cn-bj-1 nova \
  admin http://admin.compute.cn-bj-1.examplecloud.com:8774/v2.1
openstack endpoint create --region cn-bj-1 nova \
  public http://public.compute.cn-bj-1.examplecloud.com:8774/v2.1
openstack endpoint create --region cn-bj-1 nova \
  internal http://internal.compute.cn-bj-1.examplecloud.com:8774/v2.1

openstack endpoint create --region cn-bj-1 ceilometer \
  admin http://admin.metering.cn-bj-1.examplecloud.com:8777
openstack endpoint create --region cn-bj-1 ceilometer \
  public http://public.metering.cn-bj-1.examplecloud.com:8777
openstack endpoint create --region cn-bj-1 ceilometer \
  internal http://internal.metering.cn-bj-1.examplecloud.com:8777

openstack endpoint create --region cn-bj-1 gnocchi \
  admin http://admin.metric.cn-bj-1.examplecloud.com:8041
openstack endpoint create --region cn-bj-1 gnocchi \
  public http://public.metric.cn-bj-1.examplecloud.com:8041
openstack endpoint create --region cn-bj-1 gnocchi \
  internal http://internal.metric.cn-bj-1.examplecloud.com:8041

openstack endpoint create --region cn-bj-1 aodh \
  admin http://admin.alarming.cn-bj-1.examplecloud.com:8042
openstack endpoint create --region cn-bj-1 aodh \
  public http://public.alarming.cn-bj-1.examplecloud.com:8042
openstack endpoint create --region cn-bj-1 aodh \
  internal http://internal.alarming.cn-bj-1.examplecloud.com:8042
