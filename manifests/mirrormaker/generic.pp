define kafka::mirrormaker::generic (
    $fromaz = undef,
    $toaz = undef,
    $topicwhitelist = undef,
    $topicblacklist = undef,
    $numproducerthreads = 1,
    $numconsumerthreads = 1,
    $queuesize = 1000,
    $producer_type = 'async',
    $queue_enqueue_timeout_ms = -1,
    $compression_codec = 'none',
    $batch_num_messages = 1000,
    $vardir = '/var/log/kafka',
    $zkchroot = '/kafka',
    $kafkauser = 'kafka',
    $mirroroptions = '',
  ) {

  if $fromaz == undef or empty($fromaz) { fail('The $fromaz variable is empty/undef') }
  if $toaz == undef or empty($toaz) { fail('The $toaz variable is empty/undef') }
  if $topicwhitelist == undef or empty($topicwhitelist) { fail('The $topicwhitelist variable is empty/undef') }
  if !is_integer($numproducerthreads) { fail('The $numproducerthreads parameter must be an integer number') }
  if !is_integer($numconsumerthreads) { fail('The $numconsumerthreads parameter must be an integer number') }
  if !is_integer($queuesize) { fail('The $queuesize parameter must be an integer number') }
  if $producer_type == undef or empty($producer_type) { fail('The $producer_type variable is empty/undef') }
  if !is_integer($queue_enqueue_timeout_ms) { fail('The $queue_enqueue_timeout_ms parameter must be an integer number') }
  if $compression_codec == undef or empty($compression_codec) { fail('The $compression_codec variable is empty/undef') }
  if !is_integer($batch_num_messages) { fail('The $batch_num_messages parameter must be an integer number') }
  if ($topicwhitelist == undef or empty($topicwhitelist)) and ($topicblacklist == undef or empty($topicblacklist)) { fail('Must specify exactly one of $topicwhitelist or $topicblacklist') }
  if $topicwhitelist and $topicblacklist { fail('Must specify only one of $topicwhitelist or $topicblacklist') }
  if $topicwhitelist and !empty($topicwhitelist) {
    $replicaoption = "--whitelist ${topicwhitelist}"
  } elsif $topicblacklist and !empty($topicblacklist) {
    $replicaoption = "--blacklist ${topicblacklist}"
  } else {
    $replicaoption = ''
  }
  if $kafkauser == undef or empty($kafkauser) { fail('The $kafkauser variable is empty/undef') }
  validate_absolute_path($vardir)
  validate_absolute_path($zkchroot)

  $groupid = "${topicwhitelist}-${fromaz}2${toaz}"
  $target_broker_connect = join(fqdn_rotate(["kafka1.${toaz}.example.com:9092","kafka2.${toaz}.example.com:9092","kafka3.${toaz}.example.com:9092"]),',')
  $target_zookeeper_connect = join(fqdn_rotate(["zookeeper1.${fromaz}.example.com:2181","zookeeper2.${fromaz}.example.com:2181","zookeeper3.${fromaz}.example.com:2181"]),',')

  # Please make sure that your kmirror cosumes FROM a zookeper az that is
  # <2ms away. That is, do NOT have consumers go across the WAN due
  # to zookeeper latency
  # Future versions of kafka will not use zookeeper supposedly
  #
  $consumerfile = "/etc/kafka/mirrormaker/consumer-${groupid}.properties"
  file { $consumerfile:
    content => template('kafka/etc/kafka/mirrormaker/consumer.properties.erb')
  }

  # The producer can be far away (cross WAN) because we are multithreaded
  # and don't use zk
  #
  $producerfile = "/etc/kafka/mirrormaker/producer-${groupid}.properties"
  file { $producerfile:
    content => template('kafka/etc/kafka/mirrormaker/producer.properties.erb')
  }

  $execscript = "/opt/kafka/bin/mirror_maker-${groupid}.sh"
  file {$execscript:
    # This is a hacky way to get a shell script so runuser is clean
    content => "#!/bin/bash\n/opt/kafka/bin/mirror_maker --consumer.config ${consumerfile} --producer.config ${producerfile} --num.streams ${numconsumerthreads} --num.producers ${numproducerthreads} --queue.size ${queuesize} ${replicaoption} ${mirroroptions} >> ${vardir}/mirrormaker-${groupid}.log 2>&1 &\n",
    mode    => '0755',
    require => [File[$consumerfile],File[$producerfile],File[$vardir]],
  }

  # TODO: make a real service definition
  exec { "mirrormaker-${groupid}":
    command => "/sbin/runuser ${kafkauser} /opt/kafka/bin/mirror_maker-${groupid}.sh",
    require => File[$execscript],
    cwd     => $vardir,
    unless  => "/usr/bin/pgrep -ff ${groupid} -u ${kafkauser}",
  }
}

