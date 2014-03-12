#!/bin/bash

# Very simple mysql database backup with retention
# 03/2014, tomas(at)novotny.cz
# SPDX-License-Identifier: WTFPL

# ###
# Load configuration
# ###

export SCRIPT_WORKDIR="$( cd "$( dirname "$0" )" && pwd )"
cd "${SCRIPT_WORKDIR}"
. ./config.sh

# ###
# Local configuration
# ###

backup_name=`date +%y%m%d-%H%M%S`_`hostname -s`_mysql.bak
export LC_ALL=C
export LANG=en

# ###
# Functions
# ###

function rotate_backups {
	del_backup_dir=$1
	keep_backups=$2
	num_backups=`find $del_backup_dir/*_mysql.bak -size +$BACKUP_SIZE_MIN | wc -l`
	if [ $num_backups -gt $keep_backups ]; then
		num_to_delete=$(( $num_backups - $keep_backups))
		echo "Info: $num_to_delete old backups will be deleted" >> $DEBUG_LOG
		for del_file in `ls $del_backup_dir/*_mysql.bak | head -n $num_to_delete` ; do
			echo "Deleting old backup: $del_file" >> $DEBUG_LOG
			rm $del_file
		done
	else
		echo "Info: Not enough old backups for remove yet" >> $DEBUG_LOG
	fi
}

# ###
# Script itself
# ###

echo -n "Starting at " >> $DEBUG_LOG
date >> $DEBUG_LOG

/usr/bin/mysqldump -u ${DB_USER} -p${DB_PASSWORD} --all-databases > $BACKUP_DIR/$backup_name 2>>$DEBUG_LOG

# Check backup size
if [ ! -s /var/backup/mysql/$backup_name ]; then
	echo "Error: Backup has zero size, exiting" >> $DEBUG_LOG
	exit 1
else
	echo "Info: Backup has non-zero size" >> $DEBUG_LOG
fi

# Move to monthly backup (if not exists)
oldest_month=$(ls $BACKUP_DIR_MONTHLY/$(date +%y%m)* 2>/dev/null | head -n 1 2>/dev/null)
if [ ! -s "$oldest_month" ]; then
	echo "Monthly backup doesn't exist, moving" >> $DEBUG_LOG
	mv $BACKUP_DIR/$backup_name $BACKUP_DIR_MONTHLY/
fi

rotate_backups "$BACKUP_DIR" "$KEEP_DAY_BACKUPS"
rotate_backups "$BACKUP_DIR_MONTHLY" "$KEEP_MONTH_BACKUPS"

echo -n "Finished at " >> $DEBUG_LOG
date >> $DEBUG_LOG
