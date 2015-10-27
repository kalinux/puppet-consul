# == Class: consul
#
# Installs, configures, and manages consul
#
# === Parameters
#
# [*version*]
#   Specify version of consul binary to download.
#
# [*config_hash*]
#   Use this to populate the JSON config file for consul.
#
# [*pretty_config*]
#   Generates a human readable JSON config file. Defaults to `false`.
#
# [*pretty_config_indent*]
#   Toggle indentation for human readable JSON file. Defaults to `4`.
#
# [*install_method*]
#   Valid strings: `package` - install via system package
#                  `url`     - download and extract from a url. Defaults to `url`.
#                  `none`    - disable install.
#
# [*package_name*]
#   Only valid when the install_method == package. Defaults to `consul`.
#
# [*package_ensure*]
#   Only valid when the install_method == package. Defaults to `latest`.
#
# [*ui_package_name*]
#   Only valid when the install_method == package. Defaults to `consul_ui`.
#
# [*ui_package_ensure*]
#   Only valid when the install_method == package. Defaults to `latest`.
#
# [*restart_on_change*]
#   Determines whether to restart consul agent on $config_hash changes.
#   This will not affect reloads when service, check or watch configs change.
# Defaults to `true`.
#
# [*extra_options*]
#   Extra arguments to be passed to the consul agent
#
# [*init_style*]
#   What style of init system your system uses.
#
# [*purge_config_dir*]
#   Purge config files no longer generated by Puppet
class consul (
  $manage_user           = true,
  $user                  = 'consul',
  $manage_group          = true,
  $extra_groups          = [],
  $purge_config_dir      = true,
  $group                 = 'consul',
  $join_wan              = false,
  $bin_dir               = '/usr/local/bin',
  $arch                  = $consul::params::arch,
  $version               = $consul::params::version,
  $install_method        = $consul::params::install_method,
  $os                    = $consul::params::os,
  $download_url          = undef,
  $download_url_base     = $consul::params::download_url_base,
  $download_extension    = $consul::params::download_extension,
  $package_name          = $consul::params::package_name,
  $package_ensure        = $consul::params::package_ensure,
  $ui_download_url       = undef,
  $ui_download_url_base  = $consul::params::ui_download_url_base,
  $ui_download_extension = $consul::params::ui_download_extension,
  $ui_package_name       = $consul::params::ui_package_name,
  $ui_package_ensure     = $consul::params::ui_package_ensure,
  $config_dir            = '/etc/consul',
  $extra_options         = '',
  $config_hash           = {},
  $config_defaults       = {},
  $pretty_config         = false,
  $pretty_config_indent  = 4,
  $service_enable        = true,
  $service_ensure        = 'running',
  $manage_service        = true,
  $restart_on_change     = true,
  $init_style            = $consul::params::init_style,
  $services              = {},
  $watches               = {},
  $checks                = {},
  $acls                  = {},
) inherits consul::params {

  $real_download_url    = pick($download_url, "${download_url_base}${version}_${os}_${arch}.${download_extension}")
  $real_ui_download_url = pick($ui_download_url, "${ui_download_url_base}${version}_web_ui.${ui_download_extension}")

  validate_bool($purge_config_dir)
  validate_bool($manage_user)
  validate_array($extra_groups)
  validate_bool($manage_service)
  validate_bool($restart_on_change)
  validate_hash($config_hash)
  validate_hash($config_defaults)
  validate_bool($pretty_config)
  validate_integer($pretty_config_indent)
  validate_hash($services)
  validate_hash($watches)
  validate_hash($checks)
  validate_hash($acls)

  $config_hash_real = deep_merge($config_defaults, $config_hash)
  validate_hash($config_hash_real)

  if $config_hash_real['data_dir'] {
    $data_dir = $config_hash_real['data_dir']
  } else {
    $data_dir = undef
  }

  if $config_hash_real['ui_dir'] {
    $ui_dir = $config_hash_real['ui_dir']
  } else {
    $ui_dir = undef
  }

  if ($ui_dir and ! $data_dir) {
    warning('data_dir must be set to install consul web ui')
  }

  if ($config_hash_real['ports'] and $config_hash_real['ports']['rpc']) {
    $rpc_port = $config_hash_real['ports']['rpc']
  } else {
    $rpc_port = 8400
  }

  if ($config_hash_real['addresses'] and $config_hash_real['addresses']['rpc']) {
    $rpc_addr = $config_hash_real['addresses']['rpc']
  } elsif ($config_hash_real['client_addr']) {
    $rpc_addr = $config_hash_real['client_addr']
  } else {
    $rpc_addr = $::ipaddress_lo
  }

  if $services {
    create_resources(consul::service, $services)
  }

  if $watches {
    create_resources(consul::watch, $watches)
  }

  if $checks {
    create_resources(consul::check, $checks)
  }

  if $acls {
    create_resources(consul_acl, $acls)
  }

  $notify_service = $restart_on_change ? {
    true    => Class['consul::run_service'],
    default => undef,
  }

  anchor {'consul_first': }
  ->
  class { 'consul::install': } ->
  class { 'consul::config':
    config_hash => $config_hash_real,
    purge       => $purge_config_dir,
    notify      => $notify_service,
  } ->
  class { 'consul::run_service': } ->
  class { 'consul::reload_service': } ->
  anchor {'consul_last': }
}
