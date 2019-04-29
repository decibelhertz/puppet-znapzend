# == Class: znapzend::install
#
class znapzend::install {
  file {
    $znapzend::service_pid_dir:
      ensure  => 'directory',
      owner   => $znapzend::user,
      group   => $znapzend::group,
      mode    => '0644',
      recurse => true,
      before  => File[$znapzend::service_log_dir],;
    $znapzend::service_log_dir:
      ensure => 'directory',
      owner  => $znapzend::user,
      group  => $znapzend::group,
      mode   => '0755',
      before => File[$znapzend::service_conf_dir],;
    $znapzend::service_conf_dir:
      ensure => 'directory',
      owner  => $znapzend::user,
      group  => $znapzend::group,
      mode   => '0755',;
  }

  if $znapzend::package_manage {
    package { $znapzend::package_name :
      ensure => $znapzend::package_ensure,
      name   => $znapzend::package_name,
    }
  }

  # init script(s)
  case $::osfamily {
    'FreeBSD': {
        file { "/usr/local/etc/rc.d/${znapzend::service_name}":
          ensure  => 'file',
          owner   => 'root',
          group   => 'wheel',
          mode    => '0755',
          content => epp('znapzend/znapzend_init_freebsd.epp'),
          notify  => Service[$znapzend::service_name],
        }
    } 'RedHat': {
        file { '/lib/systemd/system/znapzend.service':
          ensure  => 'file',
          owner   => 'root',
          group   => 'root',
          mode    => '0644',
          content => epp('znapzend/znapzend_init_redhat.epp'),
          notify  => Service[$znapzend::service_name],
        }
    } 'Solaris': {
        file {
          "/lib/svc/method/${znapzend::service_name}":
            ensure  => 'file',
            owner   => 'root',
            group   => 'bin',
            mode    => '0555',
            content => epp('znapzend/znapzend_init_solaris.epp'),
            notify  => Service[$znapzend::service_name],;
          "/var/svc/manifest/system/filesystem/${znapzend::service_name}.xml":
            ensure  => 'file',
            owner   => 'root',
            group   => 'bin',
            mode    => '0555',
            content => epp('znapzend/znapzend.xml.epp'),
            notify  => Exec['reload-manifest'],;
        }
        exec { 'reload-manifest':
          refreshonly => true,
          command     => join([
            '/usr/sbin/svccfg import',
            "/var/svc/manifest/system/filesystem/${znapzend::service_name}.xml",
          ], ' '),
        }
    } default: {
      # NOOP
    }
  }

  # manage sudo
  if $znapzend::manage_sudo {
    file { "${znapzend::sudo_d_path}/znapzend":
      owner   => 'root',
      mode    => '0440',
      content => epp('znapzend/znapzend_sudo.epp'),
    }
  }

  # add non-root user/group if specified
  if $znapzend::user != 'root' {
    if $znapzend::manage_user {
      group { $znapzend::group:
        ensure => 'present',
      }
      -> user { $znapzend::user:
        ensure  => 'present',
        comment => 'znapzend backup user',
        shell   => $znapzend::user_shell,
        home    => $znapzend::user_home,
      }
    }
  }
}
