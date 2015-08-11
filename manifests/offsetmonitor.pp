class kafka::offsetmonitor ( $port=80, $refresh='5.minutes',
    # See https://github.com/quantifind/KafkaOffsetMonitor
    $retain='2.days', $binpath='/opt/kafka/bin',
    $vardir='/var/tmp', $logfile='/var/log/kafka/kafkaoffsetmonitor.log' ) {

  validate_absolute_path($binpath)
  validate_absolute_path($vardir)
  validate_absolute_path($logfile)

  package { 'KafkaOffsetMonitor':
    ensure => latest,
  }

  # See http://quantifind.com/KafkaOffsetMonitor/
  # TODO: make a real service definition
  exec { 'run_offsetmonitor':
    provider => shell, # see https://projects.puppetlabs.com/issues/4288
    command  => "exec java -cp $binpath/KafkaOffsetMonitor-assembly-0.2.1.jar com.quantifind.kafka.offsetapp.OffsetGetterWeb --zk `cat /etc/kafka/zookeeper_connect` --port $port --refresh $refresh --retain $retain >> $logfile 2>&1 &",
    require  => [Package['KafkaOffsetMonitor'],Package['jdk'],Class[Kafka::Install]],
    cwd      => $vardir,
    unless   => '/usr/bin/pgrep -f KafkaOffsetMonitor',
  }
}
