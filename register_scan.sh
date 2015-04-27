#!/bin/bash
#
# Description : Register database in SCAN listeners
# Author : Amaury FRANCOIS <amaury.francois@oracle.com>
#
#
set -x

#######################
## Main Program      ##
#######################
EXAPREFIX=ed02
SCAN=${EXAPREFIX}-scan

usage() { echo "Usage: $0 <DB_UNIQUE_NAME>"; }

[ "$1" -eq "" ] && usage && exit 1

HOST=$(hostname -a)

i=$((${#HOST}-1))
NODE=${HOST:$i:1}

export ORAENV_ASK=NO
export ORACLE_SID=${1}
. oraenv
export ORAENV_ASK=YES
export ORACLE_SID=${1}${NODE}


sqlplus / as sysdba << EOF
alter system set remote_listener='${SCAN}' scope=both sid='*';
alter system set local_listener='(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${EXAPREFIX}db01-vip.infra.fidji)(PORT=1521)))' scope=both sid='${1}1';
alter system set local_listener='(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${EXAPREFIX}db02-vip.infra.fidji)(PORT=1521)))' scope=both sid='${1}2';
EOF
