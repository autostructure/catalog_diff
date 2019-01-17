#
# Typically unwise for production. Make sure you UNDERSTAND the implications
# of enabling "sketchy" class prior to doing so. Noteworthy considerations:
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
# node in diff_node parameter and set "sketchy" to false. Doing so is expected
# to remove changes to the following files:
#
#     /etc/puppetlabs/puppetdb/certificate-whitelist
#     /etc/puppetlabs/puppet/autosign.conf
#     /etc/puppetlabs/puppetserver/conf.d/auth.conf
#
# Lastly, after an agent run on master(s), verify the above files no longer
# contain reference to diff_node hostname.
#

class differ::sketchy (
) {

  $sketchy = $::differ::sketchy
  $path_certificate_whitelist = $::differ::path_certificate_whitelist
  $path_autosign_dot_conf = $::differ::path_autosign_dot_conf
  $path_auth_dot_conf = $::differ::path_auth_dot_conf
  $diff_node = $::differ::diff_node

  # logic to setup/remove configs based on parameter
  if $sketchy {
    warning('Running differ class with "sketchy" set to true enforces a potentially exploitable configuration. Read and understand the implications of leaving this parameter enabled. Additional information is located inside "differ::sketchy" subclass.')
    $state = present
  }
  else {
    $state = absent
  }

  file_line { "differ whitelist ${diff_node}":
    ensure => $state,
    path   => $path_certificate_whitelist,
    line   => $diff_node,
    notify => Service['pe-puppetdb'],
  }

  # docker-diff
  file_line { "differ autosign ${diff_node}":
    ensure => $state,
    path   => $path_autosign_dot_conf,
    line   => $diff_node,
    notify => Service['pe-puppetdb'],
  }

  puppet_authorization::rule { "differ facts endpoint ${diff_node}":
    ensure               => $state,
    match_request_path   => '^/puppet/v3/facts/([^/]+)$',
    match_request_type   => 'regex',
    match_request_method => ['put','get'],
    allow                => ['$1', $diff_node],
    sort_order           => 200,
    path                 => $path_auth_dot_conf,
    notify               => Service['pe-puppetserver'],
  }

  puppet_authorization::rule { "differ catalog endpoint ${diff_node}":
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
