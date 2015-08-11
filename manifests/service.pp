# == Class kafka::service
#
class kafka::service inherits kafka {

  if !($kafka::service_ensure in ['running', 'stopped']) {
    fail('service_ensure parameter must be "running" or "stopped"')
  }

  if $kafka::service_manage == true {

    $kafka_gc_log_opts_prefix = "-Xloggc:${gc_log_file}"
    if $kafka_gc_log_opts {
      $kafka_gc_log_opts_real = "KAFKA_GC_LOG_OPTS=\"${kafka_gc_log_opts_prefix} ${kafka_gc_log_opts}\""
    }
    else {
      $kafka_gc_log_opts_real = "KAFKA_GC_LOG_OPTS=\"${kafka_gc_log_opts_prefix}\""
    }

    if $kafka_heap_opts {
      $kafka_heap_opts_real = "KAFKA_HEAP_OPTS=\"${kafka_heap_opts}\""
    }
    else {
      $kafka_heap_opts_real = ''
    }

    if $kafka_jmx_opts {
      $kafka_jmx_opts_real = "KAFKA_JMX_OPTS=\"${kafka_jmx_opts}\""
    }
    else {
      $kafka_jmx_opts_real = ''
    }

    if $kafka_jvm_performance_opts {
      $kafka_jvm_performance_opts_real = "KAFKA_JVM_PERFORMANCE_OPTS=\"${kafka_jvm_performance_opts}\""
    }
    else {
      $kafka_jvm_performance_opts_real = ''
    }

    $kafka_log4j_opts_prefix = "-Dlog4j.configuration=file:${logging_config}"
    if $kafka_log4j_opts {
      $kafka_log4j_opts_real = "KAFKA_LOG4J_OPTS=\"${kafka_log4j_opts_prefix} ${kafka_log4j_opts}\""
    }
    else {
      $kafka_log4j_opts_real = "KAFKA_LOG4J_OPTS=\"${kafka_log4j_opts_prefix}\""
    }

    if $kafka_opts {
      $kafka_opts_real = "KAFKA_OPTS=\"${kafka_opts}\""
    }
    else {
      $kafka_opts_real = ''
    }

    if $kafka::service_manage {
      if $kafka::service_manager == 'supervisor' {
        exec { 'restart-kafka-broker':
          command     => "supervisorctl restart ${kafka::service_name}",
          path        => ['/usr/bin', '/usr/sbin', '/sbin', '/bin'],
          user        => 'root',
          refreshonly => true,
          subscribe   => File[$config],
          onlyif      => 'which supervisorctl &>/dev/null',
          require     => Class['::supervisor'],
        }
      } else {
        service {'kafka-server':
          ensure     => $kafka::service_ensure,
          enable     => $kafka::service_enable,
          hasrestart => true,
          require    => File['/etc/security/limits.conf'],
        }
      }
    }

  }

}
