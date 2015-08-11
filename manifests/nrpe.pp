class kafka::nrpe {
  # Monitoring for Kafka servers
  nrpe::check {
  'check_kafka_replication_state':
    check_command => '/usr/lib/nagios/plugins/check_kafka_replication_state.sh';
  }
  nrpe::check {
  'check_kafka_lag':
    check_command => '/usr/lib/nagios/plugins/check_kafka_lag.sh -w 100000 -c 1000000 --zk-connect `cat /etc/kafka/zookeeper_connect`';
  }
  nrpe::check {
    'check_procs_kafka':
    check_command => '/usr/lib64/nagios/plugins/check_procs -c 1: -C java --argument-array="kafka.Kafka"';
  }
}
