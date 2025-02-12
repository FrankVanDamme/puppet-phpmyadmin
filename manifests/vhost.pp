# == Class: phpmyadmin::vhost
#
# Allows you to generate a vhost configuration for using phpmyadmin within a specific apache virtualhost.
# By default the phpmyadmin install will be available within the localhost definitions on apache.
# The class requires the use of puppetlabs-apache module
#
# === Parameters
# [*vhost_enabled*]
#   Default to true. Will allow you to install or uninstall the vhost entry
# [*priority*]
#   Defaults to 20, which is a reasonable default. This sets in which order the vhost is loaded.
# [*docroot*]
#   The default should be fine. This sets where the 'DocumentRoot' for the vhost is. This
#   defaults to the phpmyadmin shared resources path, which is then governed by config include.
# [*aliases*]
#   Allows you to set an alias for the phpmyadmin vhost, or to have an array of alias entries
# [*vhost_name*]
#   You can set a name for the vhost entry. This defaults to phpdb.$::domain
# [*ssl*]
#   Enable SSL support for the vhost. If enabled we disable phpmyadmin on port 80.
# [*ssl_redirect*]
#   If true, redirects 80 -> 443 (default: false)
#
# [*ssl_cert*]
#   The contents of an SSL cert to use in SSL mode
# [*ssl_key*]
#   The contents of an SSL key to use in SSL mode
# [*ssl_ca*]
#   The contents of an SSL CA to use in SSL mode (default: undef)
# [*ssl_cert_file*]
#   The filepath to use as the SSL cert
# [*ssl_key_file*]
#   The filepath to use as the SSL key
# [*ssl_ca_file*]
#   The filepath to use as the SSL CA (default: undef)
#
# === Examples
#
#  phpmyadmin::vhost { 'phpmyadmin.domain.com':
#    vhost_name => 'phpmyadmin.domain.com',
#  }
#
# === Authors
#
# Justice London <jlondon@syrussystems.com>
#
# === Copyright
#
# Copyright 2013 Justice London, unless otherwise noted.
#
define phpmyadmin::vhost (
  Enum['present','absent'] $ensure      = present,
  Boolean $vhost_enabled                = true,
  String $priority                      = '20',
  Stdlib::Absolutepath $docroot         = $::phpmyadmin::params::doc_path,
  $aliases                              = '',
  String $vhost_name                    = $name,
  Boolean $ssl                          = false,
  Boolean $ssl_redirect                 = false,
  String $ssl_cert                      = '',
  String $ssl_key                       = '',
  $ssl_ca                               = undef,
  $ssl_cert_file                        = '',
  $ssl_key_file                         = '',
  $ssl_ca_file                          = undef,
  Stdlib::Absolutepath $conf_dir        = $::apache::params::conf_dir,
  Stdlib::Absolutepath $conf_dir_enable = $::phpmyadmin::params::site_enable_dir,
) {
  include ::phpmyadmin

  #If SSL is enabled, use 443 port by default
  case $ssl {
    true: {
      #Set vhost port
      $port = '443'

      if $ssl_cert_file == '' {
        #Define SSL key files if SSL is enabled
        file { "${conf_dir}/phpmyadmin_${vhost_name}.crt":
          ensure => $ensure,
          mode   => '0644',
          source => $ssl_cert,
        }
        $ssl_apache_cert = "${conf_dir}/phpmyadmin_${vhost_name}.crt"
      } else {
        $ssl_apache_cert = $ssl_cert_file
      }

      if $ssl_key_file == '' {
        file { "${conf_dir}/phpmyadmin_${vhost_name}.key":
          ensure => $ensure,
          mode   => '0644',
          source => $ssl_key,
        }
        $ssl_apache_key = "${conf_dir}/phpmyadmin_${vhost_name}.key"
      } else {
        $ssl_apache_key = $ssl_key_file
      }

      if $ssl_ca != undef {
        file { "${conf_dir}/phpmyadmin_${vhost_name}-ca.crt":
          ensure => $ensure,
          mode   => '0644',
          source => $ssl_ca,
        }
        $ssl_apache_ca = "${conf_dir}/phpmyadmin_${vhost_name}-ca.crt"
      } else {
        if $ssl_ca_file != undef {
          $ssl_apache_ca = $ssl_ca_file
        } else {
          $ssl_apache_ca = undef
        }
      }

      if $ssl_redirect == true {
        apache::vhost { "${vhost_name}-http":
          ensure        => $ensure,
          docroot       => $docroot,
          priority      => $priority,
          port          => 80,
          servername    => $vhost_name,
          serveraliases => $aliases,
          rewrites      => [{
            comment      => 'Redirect to HTTPS',
            rewrite_cond => ['%{HTTPS} off'],
            rewrite_rule => ['(.*) https://%{HTTP_HOST}%{REQUEST_URI}'],
          }],
        }
      }
    }
    default: {
      #Default vhost port
      $port = '80'

      #No SSL cert/key define
      $ssl_apache_cert = undef
      $ssl_apache_key  = undef
      $ssl_apache_ca   = undef
    }
  }

  #Creates a basic vhost entry for apache
  apache::vhost { $vhost_name:
    ensure          => $ensure,
    docroot         => $docroot,
    priority        => $priority,
    port            => $port,
    serveraliases   => $aliases,
    ssl             => $ssl,
    custom_fragment => template('phpmyadmin/apache/phpmyadmin_fragment.erb'),
    ssl_cert        => $ssl_apache_cert,
    ssl_key         => $ssl_apache_key,
    ssl_ca          => $ssl_apache_ca,
  }

}
