class kafka::client {
  if ($::osfamily == "RedHat") {
    package { 'adiscon-librdkafka1':
      ensure => latest,
      alias  => 'librdkafka',
      before => Class['Rsyslog::Packages'],
    }
    if ($::operatingsystemmajrelease == '6') {
      package {'kafkacat':
        ensure  => latest,
        require => Package['librdkafka'],
      }
    }
  }

  $broker_connect = [
    "kafka1.example.com",
    "kafka2.example.com",
    "kafka3.example.com",
  ]

  $seed = fqdn_rand(100)	# Use a random number for the seed below so the array is shuffled once
  $broker_connectstr = inline_template("<%= srand(@seed.to_i); @broker_connect.sort_by{rand}.join(',') %>")

  file {'/etc/kafka':
    ensure => directory,
  }

  file {'/etc/kafka/broker_connect':
    ensure  => present,
    content => "${broker_connectstr}\n",
    mode    => 0644,
    owner   => root,
    group   => root,
  }

}

class kafka::client::fat {
  package { 'jdk':
    ensure => present,
  }

  package { 'kafka':
    ensure  => $package_ensure,
    name    => $package_name,
    require => [Class['kafka::users'],Package['jdk']],
  }
}
