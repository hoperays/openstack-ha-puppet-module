class openstack::x001_firewall (
  $pre_rules                  = { },
  $post_rules                 = { },
  $zabbix_rules               = { },
  $controller_rules           = { },
  $novacompute_rules          = { },
  $cephstorage_rules          = { },
  $controller_as_novacompute  = hiera('controller_as_novacompute'),
  $controller_as_cephstorage  = hiera('controller_as_cephstorage'),
  $novacompute_as_cephstorage = hiera('novacompute_as_cephstorage'),
) {
  class { '::firewall': }

  create_resources('firewall', $pre_rules, { tag => 'pre' })
  create_resources('firewall', $post_rules, { tag => 'post' })
  Firewall <| tag == 'pre' |> -> Firewall <| tag == 'post' |>
  create_resources('firewall', $zabbix_rules)

  if $::hostname =~ /^*controller-\d*$/ {
    if $controller_as_novacompute {
      create_resources('firewall', merge($novacompute_rules, $controller_rules))
    } else {
      create_resources('firewall', $controller_rules)
    }

    if $controller_as_cephstorage {
      create_resources('firewall', $cephstorage_rules)
    }
  }

  if $::hostname =~ /^*novacompute-\d*$/ {
    create_resources('firewall', $novacompute_rules)

    if $novacompute_as_cephstorage {
      create_resources('firewall', $cephstorage_rules)
    }
  }

  if $::hostname =~ /^*cephstorage-\d*$/ {
    create_resources('firewall', $cephstorage_rules)
  }
}
