
# 
# you must set EMR_HOME to point to the root directory of your 'elastic-mapreduce-ruby' install
#
export PATH=$EMR_HOME:$PATH

[ -z "$EMR_CRED_JSON" ] && EMR_CRED_JSON=$EMR_HOME/credentials.json

if [ ! -f $EMR_CRED_JSON ];then
  echo "Credentias at $EMR_CRED_JSON do not exist!"
else
  echo "Using EMR credentials: $EMR_CRED_JSON"
fi

# EMR helpers
export EMR_SSH_KEY=`cat $EMR_CRED_JSON | grep '"key-pair-file"' | cut -d':' -f2 | sed -n 's|.*"\([^"]*\)".*|\1|p'`
export EMR_SSH_KEY_NAME=`cat $EMR_CRED_JSON | grep '"key-pair"' | cut -d':' -f2 | sed -n 's|.*"\([^"]*\)".*|\1|p'`

export EMR_SSH_OPTS="-i "$EMR_SSH_KEY" -o StrictHostKeyChecking=no -o ServerAliveInterval=30"

export ELASTIC_MAPREDUCE_CREDENTIALS=$EMR_CRED_JSON

function __emr_completion() {
  [ -z "$__EMR_JOBFLOW_LIST" ] && return 0
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=( `compgen -W "${__EMR_JOBFLOW_LIST}" -- ${cur}` )
  return 0
}

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
complete -o nospace -F __emr_completion emrset

function flowid {
  if [ -z "$EMR_FLOW_ID" ]; then
    echo "$1"
  else
    echo "$EMR_FLOW_ID"
  fi
}

function emrhost {
  if [[ $1 =~ ^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$ ]]; then
   echo $1
   return
  fi
    
  FLOW_ID=`flowid $1`
  unset H
  while [ -z "$H" ]; do
   H=`emr -j $FLOW_ID --describe | grep MasterPublicDnsName | sed -n 's|.*"\([^"]*\)".*|\1|p'`
   sleep 5
  done
  echo $H
}
complete -o nospace -F __emr_completion emrhost

function emrscreen {
 HOST=`emrhost $1`
 ssh $EMR_SSH_OPTS -t "hadoop@$HOST" 'screen -s -$SHELL -D -R'
}
complete -o nospace -F __emr_completion emrscreen

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
complete -o nospace -F __emr_completion emrtail

function emrlogin {
 HOST=`emrhost $1`
 ssh $EMR_SSH_OPTS "hadoop@$HOST"
}
complete -o nospace -F __emr_completion emrlogin

function emrproxy {
 HOST=`emrhost $1`
 echo "JobTracker: http://$HOST:9100"
 echo "NameNode  : http://$HOST:9101"
 ssh $EMR_SSH_OPTS -D 6666 -N "hadoop@$HOST"
}
complete -o nospace -F __emr_completion emrproxy

function emrlist {
 local opts=""
 if [[ $* != *-v* ]]; then
  opts="$opts --no-steps --active"
 fi
 local list=`emr --list $opts`
 echo "$list"
 export __EMR_JOBFLOW_LIST=`echo "$list" | grep '^j-' | sed  -n 's|^\(j-[^ ]*\).*$|\1|p'`
}

function emrstat {
 FLOW_ID=`flowid $1`
 emr -j $FLOW_ID --describe | grep 'LastStateChangeReason' | sort -r | head -1 | cut -d":" -f2 | sed -n 's|^ "\([^\"]*\)".*|\1|p'
}
complete -o nospace -F __emr_completion emrstat

function emrterminate {
 if [ "$1" == -f ]; then f=1; shift; fi
 FLOW_ID=`flowid $1`
 [ -n "$f" ] && emr -j $FLOW_ID --set-termination-protection false
 emr -j $FLOW_ID --terminate
 export EMR_FLOW_ID=""
}
complete -o nospace -F __emr_completion emrterminate

function emrscp {
 HOST=`emrhost`
 scp $EMR_SSH_OPTS $1 "hadoop@$HOST:"
}

function emrconf {
  if [ -z "$1" ]; then
    echo "Must provide target directory to place files!"
    return
  fi
      
  if [ $# == 2 ]; then
    HH=$1
    CONFPATH=$2
  else
    HH=""
    CONFPATH=$1
  fi   
  HOST=`emrhost $HH`
  scp $EMR_SSH_OPTS "hadoop@$HOST:conf/*-site.xml" $CONFPATH/
}
