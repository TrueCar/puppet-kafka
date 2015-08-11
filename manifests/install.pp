# == Class kafka::install
#
class kafka::install inherits kafka {
  class {'yum_repos::hadoop':
    stage => setup,
  }
  
  include kafka::nrpe
  include kafka::rsyslog
  include kafka::client::fat
  $seed = fqdn_rand(100)	# Use a seed to create the random order for connect strings

  file { '/etc/kafka/zookeeper_connect':
    ensure  => present,
    content => inline_template("<%= srand($seed); @zookeeper_connect.sort_by{rand}.join(',') + @zookeeper_chroot %>\n"),
    require => Package['kafka'],
  }

  file { '/etc/logrotate.d/kafka':
    ensure  => present,
    content => template('kafka/etc/logrotate.d/kafka.erb'),
    require => Package['kafka'],
  }

  file { '/etc/init.d/kafka-server':
    ensure  => present,
    source  => "puppet:///modules/kafka/etc/init.d/kafka-server",
    owner   => "root",
    group   => "root",
    mode    => 755,
    require => Package['kafka'],
    notify  => Exec['chkconfigaddkafka'],
  }

  exec {'chkconfigaddkafka':
    command     => '/sbin/chkconfig kafka-server --add',
    refreshonly => true,
    notify      => Class['kafka::service'],
  }

  # RPM is installed in /usr/hdp/<ver>/kafka, we use current below
  file { $base_dir:
    ensure  => 'link',
    target  => '/usr/hdp/current/kafka-broker',
    require => Package['kafka'],
  }

  # We primarily (or only?) create this directory because some Kafka scripts have hard-coded references to it.
  file { $embedded_log_dir:
    ensure  => directory,
    owner   => $kafka::user,
    group   => $kafka::group,
    mode    => '0755',
    require => [File[$base_dir],Class['kafka::users']],
  }

  file { $system_log_dir:
    ensure  => directory,
    owner   => $kafka::user,
    group   => $kafka::group,
    mode    => '0755',
    recurse => true,
    require => File[$embedded_log_dir], # This is a convenient anchor
  }

  file { '/app/kafka':
    ensure  => directory,
    owner   => $kafka::user,
    group   => $kafka::group,
    mode    => '0755',
    recurse => true,
    require => File[$embedded_log_dir], # This is a convenient anchor
  }

  if $limits_manage == true {
    limits::fragment {
      "${user}/soft/nofile": value => $limits_nofile;
      "${user}/hard/nofile": value => $limits_nofile;
    }
  }

  if $tmpfs_manage == false {
    # These 'log' directories are used to store the actual data being sent to Kafka.  Do not confuse them with logging
    # directories such as /var/log/*.
    kafka::install::create_log_dirs { $log_dirs: }
  }
  else {
    # We must first create the directory that we intend to mount tmpfs on.
    file { $tmpfs_path:
      ensure => directory,
      owner  => $kafka::user,
      group  => $kafka::group,
      mode   => '0750',
    }->
    mount { $tmpfs_path:
      ensure  => mounted,
      device  => 'none',
      fstype  => 'tmpfs',
      atboot  => true,
      options => "size=${tmpfs_size}",
    }->
    kafka::install::create_log_dirs { $log_dirs: }
  }

}
