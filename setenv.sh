#
# you must have the AWS Universal CLI installed
# you must set EMR_DEFAULTS_JSON to point to the emr_defaults.json file.
#

export AWS_DEFAULT_OUTPUT="table"

if [ -z "$EMR_DEFAULTS_JSON" ];then
  echo 'EMR_DEFAULTS_JSON has not been set, use emrprofile'
elif [ ! -f $EMR_DEFAULTS_JSON ];then
  echo "Defaults at $EMR_DEFAULTS_JSON does not exist!"
else
  echo "Using EMR defaults: $EMR_DEFAULTS_JSON"
fi

# EMR helpers
export EMR_SSH_KEY=`cat $EMR_DEFAULTS_JSON | grep '"key-pair-file"' | cut -d':' -f2 | sed -n 's|.*"\([^"]*\)".*|\1|p'`
export EMR_SSH_KEY_NAME=`cat $EMR_DEFAULTS_JSON | grep '"key-name"' | cut -d':' -f2 | sed -n 's|.*"\([^"]*\)".*|\1|p'`

export EMR_SSH_OPTS="-i "$EMR_SSH_KEY" -o StrictHostKeyChecking=no -o ServerAliveInterval=30"

function __emr_completion() {
  [ -z "$__EMR_JOBFLOW_LIST" ] && return 0
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=( `compgen -W "${__EMR_JOBFLOW_LIST}" -- ${cur}` )
  return 0
}

function emr {
  RESULT=`aws emr $*`
  ID=`echo "$RESULT" | head -1 | sed -n 's|^Cr.*\(j-[^ ]*\)$|\1|p'`

  [ -n "$ID" ] && export EMR_FLOW_ID="$ID"

  echo "$RESULT"
}

function emrprofile {

  if [ -z "$1" ]; then
    unset AWS_DEFAULT_PROFILE
    echo "clearing profile, using default"
  else
    export AWS_DEFAULT_PROFILE=$1
    echo "changing profile to: $1"
  fi
  export EMR_SSH_KEY=`aws configure get key-pair-file`
  export EMR_SSH_KEY_NAME=`aws configure get key-name`
  export EMR_SSH_OPTS="-i "$EMR_SSH_KEY" -o StrictHostKeyChecking=no -o ServerAliveInterval=30"
}

function emrprivip {
  if [ -z "$EMR_PRIVATE_IPS" ]; then
    EMR_PRIVATE_IPS='true'
  else
    unset EMR_PRIVATE_IPS
  fi
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

  local PRIV="${EMR_PRIVATE_IPS}"
  if [ "$1" = "priv" ]; then
    PRIV="true"
    shift 1
  fi

  FLOW_ID=`flowid $1`

  unset H
  while [ -z "$H" ]; do
   if [ "$PRIV" = "true" ]; then
     H=`emr list-instances --cluster-id $FLOW_ID --instance-group-types MASTER --output json | grep PrivateIpAddress | sed -n -e 's|.*\"\([^\"]*\)\".*|\1|p'`
   else
     H=`emr describe-cluster --cluster-id $FLOW_ID --query [Cluster.MasterPublicDnsName] --output text`
   fi
   sleep 5
  done
  echo $H
}
complete -o nospace -F __emr_completion emrhost

function emrscreen {
 HOST=`emrhost $1 $2`
 SELF=${EMR_SCREEN_NAME:-$USER}
 ssh $EMR_SSH_OPTS -t "hadoop@$HOST" 'screen -s -$SHELL -D -R -S '"$SELF"''
}
complete -o nospace -F __emr_completion emrscreen

function emrscreenlist {
 HOST=`emrhost $1 $2`
 ssh $EMR_SSH_OPTS -t "hadoop@$HOST" 'screen -list'
}
complete -o nospace -F __emr_completion emrscreenlist

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
 HOST=`emrhost $1 $2`
 ssh $EMR_SSH_OPTS "hadoop@$HOST"
}
complete -o nospace -F __emr_completion emrlogin

function emrproxy {
 HOST=`emrhost $1 $2`
 echo "ResourceManager: http://$HOST:8088"
 echo "NameNode       : http://$HOST:50070"
 echo "HUE            : http://$HOST:8888"
 #echo "PRESTO         : http://$HOST:8888"
 echo "EMR Metrics    : http://$HOST:8327"
 echo "Spark History  : http://$HOST:18080"
 echo "Ganglia        : http://$HOST/ganglia/"
 ssh $EMR_SSH_OPTS -D 6666 -N "hadoop@$HOST"
}
complete -o nospace -F __emr_completion emrproxy

function emrprint {
 HOST=`emrhost $1 $2`
 echo "ResourceManager: http://$HOST:8088"
 echo "NameNode       : http://$HOST:50070"
 echo "HUE            : http://$HOST:8888"
 #echo "PRESTO         : http://$HOST:8888"
 echo "EMR Metrics    : http://$HOST:8327"
 echo "Spark History  : http://$HOST:18080"
 echo "Ganglia        : http://$HOST/ganglia/"
}
complete -o nospace -F __emr_completion emrprint

function emrlist {
 local list=`emr list-clusters --query Clusters[*].[Id,Name,Status.State]`

 echo "$list"

 export __EMR_JOBFLOW_LIST=`echo "$list" | grep 'j-' | sed  -n 's|.*\(j-[^ |]*\).*$|\1|p'`
}

function emractive {
  local list=`emr list-clusters --query Clusters[*].[Id,Name,Status.State] --active`

 echo "$list"

 export __EMR_JOBFLOW_LIST=`echo "$list" | grep 'j-' | sed  -n 's|.*\(j-[^ |]*\).*$|\1|p'`
}

function emrstat {
 FLOW_ID=`flowid $1`
 emr describe-cluster --cluster-id $FLOW_ID  --query [Cluster.Name,Cluster.MasterPublicDnsName,Cluster.Status.State,Cluster.Status.StateChangeReason.Message]
}
complete -o nospace -F __emr_completion emrstat

function emrterminate {
 if [ "$1" == -f ]; then f=1; shift; fi
 FLOW_ID=`flowid $1`
 emr terminate-clusters --cluster-ids $FLOW_ID
 export EMR_FLOW_ID=""
}
complete -o nospace -F __emr_completion emrterminate

function emrscp {
 HOST=`emrhost $1 $2`
 [ "$#" -gt 1 ] && shift `(( "$#" - 1 ))`
 scp $EMR_SSH_OPTS -r $1 "hadoop@$HOST:"
}

function emrscplocal {
 HOST=`emrhost $1 $2`
 [ "$#" -gt 2 ] && shift `(( "$#" - 2 ))`
 scp $EMR_SSH_OPTS -r "hadoop@$HOST:"$1 $2
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
