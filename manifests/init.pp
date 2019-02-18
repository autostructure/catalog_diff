#
# The main class for module - ordering-only at the monent
#

class puppet_catalog_diff (
  String $diff_node = 'diff-node',
  String $path_certificate_whitelist = '/etc/puppetlabs/puppetdb/certificate-whitelist',
  String $path_autosign_dot_conf = '/etc/puppetlabs/puppet/autosign.conf',
  String $path_auth_dot_conf = '/etc/puppetlabs/puppetserver/conf.d/auth.conf',
  Boolean $allow = false,
  Boolean $viewer_on_diff_node = false,
) {
  class {'::puppet_catalog_diff::allow':}
  #-> Class['::puppet_catalog_diff::viewer']
  -> Class['::puppet_catalog_diff']
}
