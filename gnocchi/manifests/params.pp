# Parameters for puppet-gnocchi
#
class gnocchi::params {
  include ::openstacklib::defaults

  case $::osfamily {
    'RedHat': {
      $sqlite_package_name        = undef
      $common_package_name        = 'openstack-gnocchi-common'
      $api_package_name           = 'openstack-gnocchi-api'
      $api_service_name           = 'openstack-gnocchi-api'
      $indexer_package_name       = 'openstack-gnocchi-indexer-sqlalchemy'
      $carbonara_package_name     = 'openstack-gnocchi-carbonara'
      $metricd_package_name       = 'openstack-gnocchi-metricd'
      $metricd_service_name       = 'openstack-gnocchi-metricd'
      $statsd_package_name        = 'openstack-gnocchi-statsd'
      $statsd_service_name        = 'openstack-gnocchi-statsd'
      $client_package_name        = 'python-gnocchiclient'
      $gnocchi_wsgi_script_path   = '/var/www/cgi-bin/gnocchi'
      $gnocchi_wsgi_script_source = '/usr/lib/python2.7/site-packages/gnocchi/rest/app.wsgi'
      $pymysql_package_name       = undef
      $cradox_package_name        = 'python2-cradox'
      $rados_package_name         = 'python-rados'
    }
    'Debian': {
      $sqlite_package_name        = 'python-pysqlite2'
      $common_package_name        = 'gnocchi-common'
      $api_package_name           = 'gnocchi-api'
      $api_service_name           = 'gnocchi-api'
      $indexer_package_name       = 'gnocchi-indexer-sqlalchemy'
      $carbonara_package_name     = 'gnocchi-carbonara'
      $metricd_package_name       = 'gnocchi-metricd'
      $metricd_service_name       = 'gnocchi-metricd'
      $statsd_package_name        = 'gnocchi-statsd'
      $statsd_service_name        = 'gnocchi-statsd'
      $client_package_name        = 'python-gnocchiclient'
      $gnocchi_wsgi_script_path   = '/usr/lib/cgi-bin/gnocchi'
      $gnocchi_wsgi_script_source = '/usr/share/gnocchi-common/app.wsgi'
      $pymysql_package_name       = 'python-pymysql'
      $cradox_package_name        = undef
      $rados_package_name         = 'python-rados'
    }
    default: {
      fail("Unsupported osfamily: ${::osfamily} operatingsystem")
    }

  } # Case $::osfamily
}
