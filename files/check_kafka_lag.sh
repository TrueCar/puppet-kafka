#!/bin/bash
# See https://github.com/TrueCar/nagios-scripts

KAFKA_RUN_CLASS=/opt/kafka/bin/kafka-run-class.sh
ZK_SHELL=/opt/kafka/bin/zookeeper-shell.sh
TAIL=/usr/bin/tail
TR=/usr/bin/tr
FLOCK=/usr/bin/flock
CP=/bin/cp

TMPFILE=/tmp/kafkalag.tmp
RSLTFILE=/tmp/kafkalag.out
MAXTIME=3600 # (seconds) If output is older than this, then discard

function printHelp() {

cat >&2 <<EOF
$@
    --warning|-w        Warning threshold
    --critical|-c       Critical threshold
    --zk-connect|-z     Zookeper connection string
    --group|-g          Set Kafka group to monitor
                        if unset, check all consumer groups
EOF

exit 3

}

check_status() {
  OKSTATUS=""
  WARNSTATUS=""
  CRITSTATUS=""
  PERFDATA=""
  for GROUP in ${groups[@]}; do
    if [[ -z $GROUP || $GROUP == "null" || $GROUP =~ "test" ]]; then
      continue # Skip
    fi
    # Topics are generated automagically from zookeeper groups
    topicsraw=`echo "ls /consumers/${GROUP}/offsets" | ${ZK_SHELL} ${ZK} | $TAIL -1 | $TR -d [\[\]]`
    topics=(${topicsraw//, / })
    if [ ${#topics[@]} -lt 1 ]; then
      CRITSTATUS="${CRITSTATUS} No topics found for ${GROUP}"
    else
      for TOPIC in ${topics[@]}; do
        if [[ -z $TOPIC || $TOPIC == "null" || $TOPIC =~ "test" ]]; then
          continue # Skip
        fi
        if [ -x $KAFKA_RUN_CLASS ]; then
          LAG=$($KAFKA_RUN_CLASS kafka.tools.ConsumerOffsetChecker --group "${GROUP}" --zkconnect "${ZK}" --topic "${TOPIC}" |grep $TOPIC |awk -F' ' '{ SUM += $6 } END { printf "%d", SUM}')
        else
          echo "UNKNOWN $KAFKA_RUN_CLASS not found"
          return 3
        fi

        DATA="${GROUP}/${TOPIC}:${LAG}"
        PERFDATA="${PERFDATA};${DATA}"
        if (( LAG >= ${CRITICAL} )); then
          CRITSTATUS="${CRITSTATUS} ${DATA}"
        elif (( LAG >= ${WARNING} )); then
          WARNSTATUS="${WARNSTATUS} ${DATA}"
        else
          OKSTATUS="${OKSTATUS} ${DATA}"
        fi
      done
    fi
  done
  if [ -n "${CRITSTATUS}" ]; then
    echo "CRITICAL ${CRITSTATUS}|${PERFDATA}"
    return 2
  elif [ -n "$WARNSTATUS" ]; then
    echo "WARNING ${WARNSTATUS}|${PERFDATA}"
    return 1
  else
    echo "OK ${OKSTATUS}|${PERFDATA}"
    return 0
  fi
  # Unknown?
  echo "UNKNOWN"
  return 3
}

# main starts here
while [ $# -gt 0 ]
do
    case "$1" in
        --warning|-w)     WARNING="$2";     shift 2;;
        --critical|-c)    CRITICAL="$2";        shift 2;;
        --zk-connect|-z)  ZK="$2";    shift 2;;
        --group|-g)       GROUP="$2";    shift 2;;
        *)                printHelp "Missing parameter" ;;
    esac
done

if [ -z "${WARNING}" ];
then
    printHelp "Please specify a warning threshold"
fi

if [ -z "${CRITICAL}" ];
then
    printHelp "Please specify a critical threshold"
fi

if [ -z "${ZK}" ];
then
    printHelp "Please specify a Zookeper connect string"
fi

if [ -z "${GROUP}" ];
then
  groupsraw=`echo "ls /consumers" | ${ZK_SHELL} ${ZK} | $TAIL -1 | $TR -d [\[\]]`
  groups=(${groupsraw//, / })
  if [ ${#groups[@]} -lt 1 ]; then
    echo "OK - No consumer groups found"
    exit 0
  fi
else
  groups=(${GROUP})
fi

if [ -r "$RSLTFILE" -a -n "$RSLTFILE" ]; then
  timediff=$((`date +%s` - `date -r $RSLTFILE +%s`))
  if [ $timediff -gt 0 -a $timediff -lt $MAXTIME ]; then
    while read -r status results; do
      echo $status $results
      laststatus=$status
    done < $RSLTFILE
  else
    echo "UNKNOWN $RSLTFILE is stale"
  fi
else
  echo "UNKNOWN $RSLTFILE missing"
fi

( # Start a background job to generate the next file
  flock -n 200 || exit 3
  (check_status ; $CP -f $TMPFILE $RSLTFILE) &
) 200>$TMPFILE 1>&200

if [ "$laststatus" == "OK" ]; then
  exit 0
elif [ "$laststatus" == "WARNING" ]; then
  exit 1
elif [ "$laststatus" == "CRITICAL" ]; then
  exit 2
fi

exit 3 # UNKNOWN?
