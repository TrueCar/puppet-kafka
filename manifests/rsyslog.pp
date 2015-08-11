class kafka::rsyslog {
  rsyslog::file_monitor { 'kafka.out':
    path => '/var/log/kafka',
    filteropts => ":msg, contains, \"INFO\" stop\n:msg, contains, \"TRACE\" stop",
  }
  rsyslog::file_monitor { 'kafka.err':
    path => '/var/log/kafka',
  }
  rsyslog::file_monitor { 'state-change.log':
    path => '/var/log/kafka',
  }
}
