#!/bin/bash

# This script takes the dump of a specified MySQL DB and
# stores the backup into the specified Amazon S3 Bucket.
# The script validates the uploaded file with the local file
# via md5 checksum before the succesfull termination

# Required packages
# s3cmd which is a standard package
# And s3cmd has to be configured via 's3cmd --configure'
# Saved settings will be under '/home/<USERNAME>/.s3cfg'

# Set MySQL server settings
HOST="localhost"
USERNAME="root"
PASSWORD=""
DB_NAME="db_production"

# s3 bucket name
S3_BUCKET="db-production"

# Backup File prefix
PREFIX_NAME="eater"

# Set where backups will be stored
TODAYS_DATE=`date "+%Y-%m-%d"`
BACKUP_PATH="/tmp/backup/$TODAYS_DATE"

# ----- NO NEED TO CHANGE ANYTHING BELOW ---------- #

# Auto detect unix bin paths, enter these manually if script fails to auto detect
MYSQL_DUMP_BIN_PATH="$(which mysqldump)"
TAR_BIN_PATH="$(which tar)"
S3CMD="$(which s3cmd)"

echo "Started Backup: `date`";

# Create BACKUP_PATH directory if it does not exist
[ ! -d $BACKUP_PATH ] && mkdir -p $BACKUP_PATH || :

# Ensure directory exists before dumping to it
if [ -d "$BACKUP_PATH" ]; then

  cd $BACKUP_PATH

  # initialize temp backup directory
  TMP_BAK_FILE="eater-$TODAYS_DATE-prod.sql"

  echo "=> Backing up MySQL data";

  # dump
  if [ "$USERNAME" != "" -a "$PASSWORD" != "" ]; then
    $MYSQL_DUMP_BIN_PATH -u $USERNAME -p$PASSWORD $DB_NAME > $TMP_BAK_FILE >> /dev/null
  fi

  # check to see if it was dumped correctly

  if [ -f "$TMP_BAK_FILE" ]; then
    FILE_NAME="${PREFIX_NAME}-dbbackup-${TODAYS_DATE}"

    # turn dumped files into a single tar file
    $TAR_BIN_PATH --remove-files -czf $FILE_NAME.tar.gz $TMP_BAK_FILE >> /dev/null

    # verify that the file was created
    if [ -f "$FILE_NAME.tar.gz" ]; then
      echo "=> MySQL Backup : Success";
      MYSQL_FILE="$FILE_NAME.tar.gz"
    else
      echo "=> Failed to create backup file: $BACKUP_PATH/$FILE_NAME.tar.gz";
      exit 1;
    fi
  else
    echo "=> Failed to backup MySQL db";
    exit 1;
  fi

  # verify that the file was created
  if [ -f "$BACKUP_PATH/$FILE_NAME.tar.gz" ]; then
    echo "=> Success: `du -sh $FILE_NAME.tar.gz`";
  else
    echo "=> Failed to create backup file: $BACKUP_PATH/$FILE_NAME.tar.gz";
    exit 1;
  fi

  FILE_NAME_2="$FILE_NAME-2"
  # upload the zip to s3 bucket
  s3cmd put $FILE_NAME.tar.gz s3://$S3_BUCKET/DB_BACKUP/$TODAYS_DATE/$FILE_NAME.tar.gz 2>&1 | cat > s3.log

  # Retrieve the file back and verify that its hasn't been corrupted
  s3cmd get s3://$S3_BUCKET/DB_BACKUP/$TODAYS_DATE/$FILE_NAME.tar.gz $FILE_NAME_2.tar.gz 2>&1 | cat >> s3.log

  chksum1=$(md5sum $FILE_NAME.tar.gz | awk '{ print $1 }')
  chksum2=$(md5sum $FILE_NAME_2.tar.gz | awk '{ print $1 }')

  if [ $chksum1 == $chksum2 ]; then
    echo "Uploaded the file to s3 bucket successfully !";
    # Clean files
    if [ -f "$BACKUP_PATH/$FILE_NAME.tar.gz" ]; then
	    rm -f "$BACKUP_PATH/$FILE_NAME.tar.gz"
    fi

    if [ -f "$BACKUP_PATH/$FILE_NAME_2.tar.gz" ]; then
	    rm -f "$BACKUP_PATH/$FILE_NAME_2.tar.gz"
    fi
  else
    echo "Uploaded file $FILE_NAME.tar.gz in s3 bucket:$S3_BUCKET is corrupted !";
  fi
else
  echo "=> Failed to create backup path: $BACKUP_PATH";
fi
