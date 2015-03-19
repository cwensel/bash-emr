bash-emr
========

This is a simple set of bash functions for manipulating a
Amazon Elastic MapReduce clusters.

This work is licensed under a [Creative Commons Attribution 3.0 Unported License](http://creativecommons.org/licenses/by/3.0/).

Install
-----

You must install the [AWS Command Line Interface](http://aws.amazon.com/cli/).

You then must setup an emr_defaults.json file with your default emrsettings. Use the emr_defaults_sample.json as a starting point.

    export EMR_DEFAULTS_JSON=/<mypath>/bash-emr/bash-emr/emr_defaults.json

    . /<mypath>/bash-emr/setenv.sh

Finally, you must source the `setenv.sh` file (in your .bash_profile)

    . setenv.sh


Usage
-----

To find an existing cluster:

	emrlist
	
To attach to a cluster, using a _flow id_:

    emrset <flow id>	

To get the current _flow id_:

	emrset

To remotely login to the master node of the current _flow id_:

	emrlogin
	
To remotely login with just the ip address:

	emrlogin <ip address>	

Note that most commands will take the _cluster id_ or an _ip address_ to override the default _cluster id_ set using `emrset`.

Reference
---------

### emr
This is shorthand for calling from the shell.
    
    emr <some args>

### emrset
When you start a flow on EMR, you will be given a flow id. 
Use __emrset__ to set the flow id for use by many of the other commands
    
    emrset <flow id>
      
Calling __emrset__ without the id returns the current flow id.

### emrlist
Will return the list of recent clusters

### emractive
Will return the list of clusters that in an active state

### emrhost
Will return the current master node on the EMR cluster.

### emrlogin
Will remotely login to the master node. 

### emrstat
Will return the current status of a given running flow.

### emrterminate
Will terminate your remote EMR cluster.

### emrscreen
Will launch screen on the master node. Screen must be already installed.
If a screen instance is already running, this command will automatically attach.

### emrtail
Will automatically 'tail' the current flow step logs.
    
    emrtail 2

Without a step number, a list of available steps will be displayed.

### emrproxy
Will create a local SOCKS proxy to the master node. This is useful for accessing
the JobTracker and NameNode. You must install FoxyProxy in FireFox for this to 
work best.

### emrscp
Will scp a given file to the remote master node.
    
    emrscp my-hadoop-app.jar

This is useful if you leave your EMR cluster running and want to manually spawn 
jobs from __emrlogin__ or __emrscreen__.

### emrscplocal
Will copy the given file or folder from the remote master node to a local path 

    emrscplocal file.on.master.txt ~/myfolder/

### emrconf
Will scp all `conf/*-site.xml` files from the master node into the given directory.
    
    emrconf local-conf

This is useful if you leave your EMR cluster running on a AWS VPC and wish to run Hadoop jobs from a local shell.

