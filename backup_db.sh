#!/bin/bash
#
# Description : RMAN backup on Exadata
# Author : Amaury FRANCOIS <amaury.francois@oracle.com>
#
#
set -x
#######################
## Default parameters##
#######################
export ORACLE_HOME=/u01/app/oracle/product/12.1.0.2/dbhome_1
LOG_DIR=/u01/app/oracle/backup/logs

#Scan address
SCAN_ADDR=ed02-scan

#Device type, DISK or SBT_TAPE
DEV_TYPE=DISK

#Parallelism
PARALLEL=1

# Possible values are f,0,1,al
LEVEL=f

# Autobackup prefix
AB_PREFIX=

# Backupset prefix
BS_PREFIX=

#FRA Disk Group
FRA_DG=+RECO

#DB Password
DB_PASSWD=welcome1

#Section Size
SECT_SIZE=15G

#Retention
RETENTION="RECOVERY WINDOW OF 1 DAYS"

#Log File Retention (in days)
LOG_RETENTION=7
###########################
#End of Default parameters#
###########################

usage() { echo "Usage: $0 -d <DB_UNIQUE_NAME>.<Domain Name> -l <0|1|f|al> [-p <parallelism> [-t <DISK|SBT_TAPE>]" 1>&2; exit 1; }

while getopts ":d:l:t:p:" o; do
    case "${o}" in
        d)
            DB_GLOBAL_NAME=${OPTARG}
            ;;
        p)
            PARALLEL=${OPTARG}
            ;;
        l)
            LEVEL=${OPTARG}
            ;;
        t)
            DEV_TYPE=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "${DB_GLOBAL_NAME}" ] || [ -z "${LEVEL}" ]; then
    usage
fi


# Build Variables
RMAN_CMD="$ORACLE_HOME/bin/rman target sys/$DB_PASSWD@$SCAN_ADDR/$DB_GLOBAL_NAME"
mkdir -p ${LOG_DIR}/${DB_GLOBAL_NAME}
RMAN_LOG=${LOG_DIR}/${DB_GLOBAL_NAME}/rman_${LEVEL}_${DEV_TYPE}_$(date +%Y%m%d-%H:%M:%S).log
DB_UNIQUE_NAME=$(echo ${DB_GLOBAL_NAME} | cut -d '.' -f 1)


purge_logs()
{
find ${LOG_DIR}/${DB_GLOBAL_NAME} -name "*.log" -mtime +${LOG_RETENTION} | xargs rm -f
}
#Save Current Rman config
save_rman_config()
{
RMAN_SAVED_CONFIG="SET ECHO ON;"
RMAN_SAVED_CONFIG="$RMAN_SAVED_CONFIG $(
($RMAN_CMD << 'EOF'
show all;
EOF
)|grep CONFIGURE
)"
#Debug
#echo "$RMAN_SAVED_CONFIG"
}

#Restore RMAN config
restore_rman_config()
{
echo "$RMAN_SAVED_CONFIG" | $RMAN_CMD
}


#Configure RMAN
build_rman_config()
{
RMAN_CONFIGURATION="CONFIGURE SNAPSHOT CONTROLFILE NAME TO '${FRA_DG}/${DB_UNIQUE_NAME}/snap_cf.ora';
CONFIGURE CONTROLFILE AUTOBACKUP ON;"

if [[ $DEV_TYPE == "DISK" ]]; then
RMAN_CONFIGURATION="$RMAN_CONFIGURATION
CONFIGURE DEVICE TYPE DISK PARALLELISM $PARALLEL BACKUP TYPE TO COMPRESSED BACKUPSET;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${FRA_DG}';
CONFIGURE RETENTION POLICY TO ${RETENTION};"
else
RMAN_CONFIGURATION="$RMAN_CONFIGURATION
CONFIGURE DEVICE TYPE TAPE PARALLELISM $PARALLEL BACKUP TYPE TO BACKUPSET;"
fi
#Debug
#echo "$RMAN_CONFIGURATION"
}

build_rman_script()
{
RMAN_SCRIPT="SET ECHO ON;
$RMAN_CONFIGURATION"

if [[ $LEVEL == "al" ]];then
RMAN_SCRIPT="$RMAN_SCRIPT
BACKUP DEVICE TYPE ${DEV_TYPE} ARCHIVELOG ALL NOT BACKED UP 1 TIMES;
"
elif [[ $LEVEL == "f" ]];then
RMAN_SCRIPT="$RMAN_SCRIPT
BACKUP DEVICE TYPE ${DEV_TYPE} SECTION SIZE ${SECT_SIZE} DATABASE;
BACKUP DEVICE TYPE ${DEV_TYPE} ARCHIVELOG ALL NOT BACKED UP 1 TIMES;
"
else
RMAN_SCRIPT="$RMAN_SCRIPT
BACKUP INCREMENTAL LEVEL $LEVEL DEVICE TYPE ${DEV_TYPE} DATABASE;
BACKUP DEVICE TYPE ${DEV_TYPE} ARCHIVELOG ALL NOT BACKED UP 1 TIMES;
"
fi

if [[ ${DEV_TYPE} == "DISK" ]]; then
RMAN_SCRIPT="$RMAN_SCRIPT
CROSSCHECK BACKUP;
"
fi
#Debug
#echo "$RMAN_SCRIPT"
}

run_rman_script()
{
echo "$RMAN_SCRIPT" | $RMAN_CMD log=$RMAN_LOG
}

build_rman_config
build_rman_script
run_rman_script
purge_logs
