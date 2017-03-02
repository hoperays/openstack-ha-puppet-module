class openstack::x001_firewall (
  $pre_rules         = {},
  $post_rules        = {},
  $controller_rules  = {},
  $novacompute_rules = {},
  $cephstorage_rules = {},
) {
  class { '::firewall': }

  create_resources('firewall', $pre_rules, { tag => 'pre' })
  create_resources('firewall', $post_rules, { tag => 'post' })
  Firewall <| tag == 'pre' |> -> Firewall <| tag == 'post' |>

  if $::hostname =~ /^*controller-\d*$/ {
    create_resources('firewall', $controller_rules)
  } elsif $::hostname =~ /^*novacompute-\d*$/ {
    create_resources('firewall', $novacompute_rules)
  } elsif $::hostname =~ /^*cephstorage-\d*$/ {
    create_resources('firewall', $cephstorage_rules)
  }
}
