#!/bin/bash
#
# Description : Activate AL mode
# Author : Amaury FRANCOIS <amaury.francois@oracle.com>
#
#
#set -x

#######################
## Main Program      ##
#######################

usage() { echo "Usage: $0 <DB_UNIQUE_NAME>"; }


read -p "This will stop ${1}, are you sure ?" choice
case "$choice" in
  y|Y ) echo "OK activating ARCHIVE LOG MODE on ${1}";;
  n|N ) exit 1;;
  * ) usage && exit 1;;
esac

HOST=$(hostname -a)

i=$((${#HOST}-1))
NODE=${HOST:$i:1}

export ORAENV_ASK=NO
export ORACLE_SID=${1}
. oraenv
export ORAENV_ASK=YES
export ORACLE_SID=${1}${NODE}

#echo "Stopping the database"
srvctl stop database -d ${1}

#echo "Starting the database in mount mode"
srvctl start instance -d ${1} -i ${ORACLE_SID} -o mount


sqlplus / as sysdba << EOF
alter system set db_recovery_file_dest_size=100G scope=both sid='*';
alter system set db_recovery_file_dest='+RECO' scope=both sid='*';
alter database archivelog;
EOF

echo "Stopping the database"
srvctl stop database -d ${1}

echo "Starting the database"
srvctl start database -d ${1}
