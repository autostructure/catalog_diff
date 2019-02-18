#
# This class configures master(s) to allow a specific node to requerst facts
# and compiled catalogs, using those facts.
#
# Typically unwise for production. Make sure you UNDERSTAND the implications
# of enabling "allow" class prior to doing so. Noteworthy considerations:
#
#    auto-signing         - enables basic auto-signing for node defined
#                           in $diff_node parameter
#    whitelist puppetdb   - enables query whitelisting for node defined
#                           in $diff_node parameter
#    facts API endpoint   - enables node defined in $diff_node parameter
#                           to retrieve factsets for all nodes
#    catalog API endpoint - enables node defined in $diff_node parameter
#                           to retrieve catalogs for all nodes
#
# Once testing is complete (even on non-production systems) leave configured
# node in diff_node parameter and set "allow" to false. Doing so is expected
# to remove changes to the following files:
#
#     /etc/puppetlabs/puppetdb/certificate-whitelist
#     /etc/puppetlabs/puppet/autosign.conf
#     /etc/puppetlabs/puppetserver/conf.d/auth.conf
#
# Lastly, after an agent run on master(s), verify the above files no longer
# contain reference to diff_node hostname.
#

class puppet_catalog_diff::allow (
) {

  $allow_on_masters = $::catalog_diff_allow::allow_on_masters
  $path_certificate_whitelist = $::puppet_catalog_diff::path_certificate_whitelist
  $path_autosign_dot_conf = $::puppet_catalog_diff::path_autosign_dot_conf
  $path_auth_dot_conf = $::puppet_catalog_diff::path_auth_dot_conf
  $diff_node = $::puppet_catalog_diff::diff_node

  # logic to setup/remove configs based on parameter
  if $allow_on_masters {
    warning('Leaving "allow_on_masters" class set to true enforces a potentially exploitable configuration.')
    $state = present
  }
  else {
    $state = absent
  }

  file_line { "whitelist ${diff_node}":
    ensure => $state,
    path   => $path_certificate_whitelist,
    line   => $diff_node,
    notify => Service['pe-puppetdb'],
  }

  file_line { "autosign ${diff_node}":
    ensure => $state,
    path   => $path_autosign_dot_conf,
    line   => $diff_node,
    notify => Service['pe-puppetdb'],
  }

  puppet_authorization::rule { "facts endpoint ${diff_node}":
    ensure               => $state,
    match_request_path   => '^/puppet/v3/facts/([^/]+)$',
    match_request_type   => 'regex',
    match_request_method => ['put','get'],
    allow                => ['$1', $diff_node],
    sort_order           => 200,
    path                 => $path_auth_dot_conf,
    notify               => Service['pe-puppetserver'],
  }

  puppet_authorization::rule { "catalog endpoint ${diff_node}":
    ensure               => $state,
    match_request_path   => '^/puppet/v3/catalog/([^/]+)$',
    match_request_type   => 'regex',
    match_request_method => ['get','post'],
    allow                => ['$1', $diff_node],
    sort_order           => 200,
    path                 => $path_auth_dot_conf,
    notify               => Service['pe-puppetserver'],
  }

}
