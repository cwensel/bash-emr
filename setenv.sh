
# 
# you must set EMR_HOME to point to the root directory of your 'elastic-mapreduce-ruby' install
#

export PATH=$EMR_HOME:$PATH

# EMR helpers
KEYPAIR=`cat $EMR_HOME/credentials.json | grep key-pair-file | cut -d':' -f2 | sed -n 's|.*"\([^"]*\)".*|\1|p'`
export EMR_SSH_OPTS="-i "$KEYPAIR" -o StrictHostKeyChecking=no -o ServerAliveInterval=30"

function emr {
  RESULT=`elastic-mapreduce $*`
  ID=`echo "$RESULT" | head -1 | sed -n 's|^Cr.*\(j-[^ ]*\)$|\1|p'`
  
  [ -n "$ID" ] && export EMR_FLOW_ID="$ID"
  
  echo "$RESULT"
}

function emrset {
  if [ -z "$1" ]; then
    echo $EMR_FLOW_ID
  else
    export EMR_FLOW_ID=$1
  fi
}

function flowid {
  if [ -z "$EMR_FLOW_ID" ]; then
    echo "$1"
  else
    echo "$EMR_FLOW_ID"
  fi
}

function emrhost {
  FLOW_ID=`flowid $1`
  unset H
  while [ -z "$H" ]; do
   H=`emr -j $FLOW_ID --describe | grep MasterPublicDnsName | sed -n 's|.*"\([^"]*.amazonaws.com\)".*|\1|p'`
   sleep 5
  done
  echo $H
}

function emrscreen {
 HOST=`emrhost $1`
 ssh $EMR_SSH_OPTS -t "hadoop@$HOST" 'screen -s -$SHELL -D -R'
}

function emrtail {
  if [ -z "$1" ]; then
    echo "Must provide step number to tail!"
    HOST=`emrhost $HH`
    ssh $EMR_SSH_OPTS -t "hadoop@$HOST" "ls -1 /mnt/var/log/hadoop/steps/"
    return
  fi
      
  if [ $# == 2 ]; then
    HH=$1
    STEP=$2
  else
    HH=""
    STEP=$1
  fi   
  HOST=`emrhost $HH`
  ssh $EMR_SSH_OPTS -t "hadoop@$HOST" "tail -100f /mnt/var/log/hadoop/steps/$STEP/syslog"
}

function emrlogin {
 HOST=`emrhost $1`
 ssh $EMR_SSH_OPTS "hadoop@$HOST"
}
 
function emrproxy {
 HOST=`emrhost $1`
 echo http://$HOST:9100
 ssh $EMR_SSH_OPTS -D 6666 -N "hadoop@$HOST"
}

function emrstat {
 FLOW_ID=`flowid $1`
 emr -j $FLOW_ID --describe | grep 'LastStateChangeReason' | head -1 | cut -d":" -f2 | sed -n 's|^ "\([^\"]*\)".*|\1|p'
}

function emrterminate {
 FLOW_ID=`flowid $1`
 emr -j $FLOW_ID --terminate
 export EMR_FLOW_ID=""
}

function emrscp {
 HOST=`emrhost`
 scp $EMR_SSH_OPTS $1 "hadoop@$HOST:"
}

