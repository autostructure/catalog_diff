class catalogdiff (
  String $diff_node = 'diff-node',
  String $path_certificate_whitelist = '/etc/puppetlabs/puppetdb/certificate-whitelist',
  String $path_autosign_dot_conf = '/etc/puppetlabs/puppet/autosign.conf',
  String $path_auth_dot_conf = '/etc/puppetlabs/puppetserver/conf.d/auth.conf',
  Boolean $allow = false,
  Boolean $viewer_on_diff_node = false,
) {
  class {'::catalogdiff::allow_on_masters':}
  -> Class['::catalogdiff::viewer']
  -> Class['::catalogdiff']
}
