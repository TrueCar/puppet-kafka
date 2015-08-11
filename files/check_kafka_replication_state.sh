#!/bin/bash
#
# A quick check on replication status to look for CRITICAL unavailable partitions and
# WARNING underreplicated partitions for all topics
#
TOPICBIN='/usr/hdp/current/kafka-broker/bin/kafka-topics.sh'
ZOOKEEPER=$(/bin/cat /etc/kafka/zookeeper_connect)
UNDERREPLICATEDCMD='--under-replicated-partitions'
UNAVAILABLECMD='--unavailable-partitions'
WC='/usr/bin/wc'

STATUSSTR='UNKNOWN'
EXITCODE=4

if [ -z "$ZOOKEEPER" ]; then
  echo "${STATUSSTR}: cannot read zookeeper connect string"
  exit $EXITCODE
fi

if [ ! -x "$TOPICBIN" ]; then
   echo "${STATUSSTR}: cannot execute ${TOPICBIN}"
   exit $EXITCODE
fi

NUMUNDERREPLICATED=$(${TOPICBIN} --zookeeper ${ZOOKEEPER} --describe ${UNDERREPLICATEDCMD} 2>/dev/null | ${WC} -l)
NUMUNAVAILABLE=$(${TOPICBIN} --zookeeper ${ZOOKEEPER} --describe ${UNAVAILABLECMD} 2>/dev/null | ${WC} -l)

if [ -z "$NUMUNDERREPLICATED" -o -z "$NUMUNAVAILABLE" ]; then
  echo "${STATUSSTR}: error reading output from topics"
  exit $EXITCODE
fi

if [ $NUMUNAVAILABLE -gt 0 ]; then
  STATUSSTR="CRITICAL: ${NUMUNAVAILABLE} unavailable partitions"
  EXITCODE=2
elif [ $NUMUNDERREPLICATED -gt 0 ]; then
  STATUSSTR="WARNING: ${NUMUNDERREPLICATED} underreplicated partitions found"
  EXITCODE=1
elif [ $NUMUNAVAILABLE -eq 0 -a $NUMUNDERREPLICATED -eq 0 ]; then
  STATUSSTR="OK: all partitions good"
  EXITCODE=0
fi

echo $STATUSSTR
exit $EXITCODE
