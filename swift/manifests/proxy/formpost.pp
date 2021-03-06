#
# Configure swift formpost.
#
# == Dependencies
#
# == Examples
#
#  include swift::proxy::formpost
#
# == Authors
#
#   Mehdi Abaakouk <sileht@sileht.net>
#
# == Copyright
#
# Copyright 2012 eNovance licensing@enovance.com
#
class swift::proxy::formpost() {

  include ::swift::deps

  concat::fragment { 'swift-proxy-formpost':
    target  => '/etc/swift/proxy-server.conf',
    content => template('swift/proxy/formpost.conf.erb'),
    order   => '130',
  }

}
