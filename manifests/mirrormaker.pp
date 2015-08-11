class kafka::mirrormaker {
  include kafka::client
  include kafka::users

  $vardir = '/var/log/kafka'

  file {'/etc/kafka/mirrormaker':
    ensure  => 'directory',
    recurse => true,
    purge   => true, # This helps remove configs we don't want automagically
  }
  file {$vardir: # Caution, this is duplicated in kafka::install but I don't know how to share it easily
    ensure  => directory,
    owner   => kafka,
    group   => kafka,
    mode    => '0755',
    recurse => true,
    require => Class[Kafka::Users],
  }
  file {'/etc/logrotate.d/mirrormaker':
    ensure  => present,
    content => template('kafka/etc/logrotate.d/mirrormaker.erb'),
    require => File[$vardir],
  }

  package {'mirror_maker':
    ensure => 'latest',
  }
}
