# == Class: znapzend::config
#
class znapzend::config {

  ## CLASS VARIABLES

  $init_path = $facts['os']['family'] ? {
    'FreeBSD' => "/usr/local/etc/rc.d/${znapzend::service_name}",
    'Solaris' => "/lib/svc/method/${znapzend::service_name}",
    default   => "/lib/systemd/system/${znapzend::service_name}.service",
  }
  $init_mode = $facts['os']['family'] ? {
    'RedHat'  => '0644',
    default   => '0555',
  }
  $root_group= $facts['os']['family'] ? {
    'Darwin'  => 'wheel',
    'Solaris' => 'bin',
    default   => 'root',
  }
  $osdowncase = downcase($facts['os']['family'])

  ## MANAGED RESOURCES

  # directories
  file {
    'znapzend_service_conf_dir':
      ensure => 'directory',
      path   => $znapzend::service_conf_dir,
      owner  => $znapzend::user,
      group  => $znapzend::group,
      mode   => '0755',;
    'znapzend_service_log_dir':
      ensure => 'directory',
      path   => $znapzend::service_log_dir,
      owner  => $znapzend::user,
      group  => $znapzend::group,
      mode   => '0755',;
    'znapzend_service_pid_dir':
      ensure => 'directory',
      path   => $znapzend::service_pid_dir,
      owner  => $znapzend::user,
      group  => $znapzend::group,
      mode   => '0755',;
  }

  # conditional sudo
  if $znapzend::manage_sudo {
    file { "${znapzend::sudo_d_path}/znapzend":
      owner   => 'root',
      group   => $root_group,
      mode    => '0440',
      content => epp('znapzend/znapzend_sudo.epp'),
    }
  }

  # conditional add non-root user/group
  if $znapzend::manage_user and $znapzend::user != 'root' {
    create_resources('group', $znapzend::groups, {
      before => File[
        'znapzend_service_conf_dir',
        'znapzend_service_log_dir',
        'znapzend_service_pid_dir',
      ],
    })
    create_resources('user', $znapzend::users, {
      shell => $znapzend::user_shell,
    })
  }

  if $znapzend::manage_init {
    # OS-specific init script(s)
    file { 'znapzend_init':
      ensure  => 'file',
      owner   => 'root',
      group   => $root_group,
      mode    => $init_mode,
      path    => $init_path,
      content => epp("znapzend/znapzend_init_${osdowncase}.epp"),
    }

    # Solaris needs more resources...
    if $facts['os']['family'] == 'Solaris' {
      file {
        "/var/svc/manifest/system/filesystem/${znapzend::service_name}.xml":
          ensure  => 'file',
          owner   => 'root',
          group   => 'bin',
          mode    => '0555',
          content => epp('znapzend/znapzend.xml.epp'),
      }
      ~> exec { 'reload-manifest':
        refreshonly => true,
        command     => join([
          '/usr/sbin/svccfg import',
          "/var/svc/manifest/system/filesystem/${znapzend::service_name}.xml",
        ], ' '),
      }
    }
  }
}
