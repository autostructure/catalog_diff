class differ (
  Boolean $sketchy = false,
  String $path_certificate_whitelist = '/etc/puppetlabs/puppetdb/certificate-whitelist',
  String $path_autosign_dot_conf = '/etc/puppetlabs/puppet/autosign.conf',
  String $path_auth_dot_conf = '/etc/puppetlabs/puppetserver/conf.d/auth.conf',
  String $diff_node = 'diff-node',
) {

  class {'::differ::sketchy':}
  -> Class['::differ']

}
