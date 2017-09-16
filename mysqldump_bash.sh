#!/bin/bash
username=$1 # your MySQL username
password=$2 # your MySQL password
outpath=$3 # path where backups will be stored
now=$(date +"%Y-%m-%d") # get current date (yyyy-MM-dd)
size_files=$(du -s -m $outpath --apparent-size | cut -f1) #get the size of outpath (in MB)
size_thresh=128 # threshold of folder size in MB

# Delete old folders if folder size > 128 MB:
echo "Starting sqlbackup.sh..."
if [$size_files -gt $size_thresh]
then
        echo "Folder has $size_files MB of backups (threshold is $size_thresh MB) - looking for those that are lder than 12 weeks..."
        find $outpath \( -name '*.gz' -or -name '*.sql' \) -mtime +84 -delete -print
else
        echo "Folder has $size_files MB of files (threshold is $size_thresh MB) - no action needed."
fi

# do mysqldump, pipe to gzip:
echo "Creating dump of MySQL database (user $username, password $password) and GZIP it."
mysqldump --user=${username} --password=${password} --events --all-databases | gzip -7 > ${outpath}/database_backup_${now}.sql.gz
echo "sqlbackup.sh is done!"
