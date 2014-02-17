#!/bin/bash

#---------- Set all the variables to take the backup -----------------------

# Set server settings
HOST="localhost"
PORT="27017"
USERNAME=""
PASSWORD=""

# s3 bucket name
S3_BUCKET="insurance_snoopers_test"

# Backup File prefix
PREFIX_NAME="isnoopers"

# Set Rails App Info
RAILS_APP_NAME="Insurance Snoopers"
RAILS_APP_PATH="/vol/app/insurance_snoopers"

# Set where backups will be stored
TODAYS_DATE=`date "+%Y-%m-%d"`
BACKUP_PATH="/vol/backup/$TODAYS_DATE"

# Auto detect unix bin paths, enter these manually if script fails to auto detect
MONGO_DUMP_BIN_PATH="$(which mongodump)"
TAR_BIN_PATH="$(which tar)"
S3CMD="$(which s3cmd)"

# ---------------------- No Need to Make any changes from here -----------------
echo "Started $RAILS_APP_NAME Backup: `date`";

# Create BACKUP_PATH directory if it does not exist
[ ! -d $BACKUP_PATH ] && mkdir -p $BACKUP_PATH || :

# Ensure directory exists before dumping to it
if [ -d "$BACKUP_PATH" ]; then

  cd $BACKUP_PATH

  # initialize temp backup directory
  TMP_BACKUP_DIR="mongodb-$TODAYS_DATE"

  echo "=> Backing up Mongo Server: $HOST:$PORT";

  # run dump on mongoDB
  if [ "$USERNAME" != "" -a "$PASSWORD" != "" ]; then
    $MONGO_DUMP_BIN_PATH --host $HOST:$PORT -u $USERNAME -p $PASSWORD --out $TMP_BACKUP_DIR >> /dev/null
  else
    $MONGO_DUMP_BIN_PATH --host $HOST:$PORT --out $TMP_BACKUP_DIR >> /dev/null
  fi

  # check to see if mongoDb was dumped correctly

  if [ -d "$TMP_BACKUP_DIR" ]; then
    FILE_NAME="${PREFIX_NAME}-DBBACKUP-${TODAYS_DATE}"

    # turn dumped files into a single tar file
    $TAR_BIN_PATH --remove-files -czf $FILE_NAME.tar.gz $TMP_BACKUP_DIR >> /dev/null

    # verify that the file was created
    if [ -f "$FILE_NAME.tar.gz" ]; then
      echo "=> MongoDB Backup : Success"; 
      MONGO_FILE="$FILE_NAME.tar.gz"
      # forcely remove if files still exist and tar was made successfully
      # this is done because the --remove-files flag on tar does not always work
      if [ -d "$BACKUP_PATH/$TMP_BACKUP_DIR" ]; then
        rm -rf "$BACKUP_PATH/$TMP_BACKUP_DIR"
      fi
    else
      echo "=> Failed to create backup file: $BACKUP_PATH/$FILE_NAME.tar.gz";
      exit 1;
    fi
  else
    echo "=> Failed to backup mongoDB";
    exit 1;
  fi
  
  # Backup the Rails App and compress it to a tar file
  echo "=> Backing up Rails App : $RAILS_APP_NAME";

  if [ -d "$RAILS_APP_PATH" ]; then
    # Set name for the Rails App backup tar file
    FILE_NAME=""
    FILE_NAME="${PREFIX_NAME}-RAILS_APP_BACKUP-${TODAYS_DATE}"
    
    # Compress the Rails App and create a tar file in the backup directory
    $TAR_BIN_PATH -zPcf $FILE_NAME.tar.gz --exclude='*.sock' $RAILS_APP_PATH >> /dev/null

    # verify that the file was created
    if [ -f "$FILE_NAME.tar.gz" ]; then
      echo "=> Rails App backup: Success";
      APP_FILE="$FILE_NAME.tar.gz"
    else
      echo "=> Failed to create RAILS_APP backup file: $BACKUP_PATH/$FILE_NAME.tar.gz";
      exit 1;
    fi
  else
    echo "=> Failed to backup the RAILS_APP: $RAILS_APP_NAME . App Directory doesn't exists !";
    exit 1;
  fi

  # tar zip the APP_FILE and MONGO_FILE
    FILE="${PREFIX_NAME}-BACKUP-${TODAYS_DATE}"
    
    # turn dumped files into a single tar file
    $TAR_BIN_PATH -zPcf $FILE.tar.gz $BACKUP_PATH/$PREFIX_NAME* | cat > tar.log 

    # verify that the file was created
    if [ -f "$BACKUP_PATH/$FILE.tar.gz" ]; then
      echo "=> Success: `du -sh $FILE.tar.gz`"; 

      if [ -f "$BACKUP_PATH/$MONGO_FILE" ]; then
        rm -f "$BACKUP_PATH/$MONGO_FILE"
      fi
      if [ -f "$BACKUP_PATH/$APP_FILE" ]; then
        rm -f "$BACKUP_PATH/$APP_FILE" 
      fi
    else
      echo "=> Failed to create backup file: $BACKUP_PATH/$FILE.tar.gz";
      exit 1;
    fi

  # upload the zip to s3 bucket
  s3cmd put $FILE.tar.gz s3://$S3_BUCKET/$TODAYS_DATE/$FILE.tar.gz 2>&1 | cat > s3.log
  
  # Retrieve the file back and verify that its hasn't been corrupted
  s3cmd get s3://$S3_BUCKET/$TODAYS_DATE/$FILE.tar.gz $FILE_2.tar.gz 2>&1 | cat >> s3.log
  
  chksum1=$(md5sum $FILE.tar.gz | awk '{ print $1 }')
  chksum2=$(md5sum $FILE_2.tar.gz | awk '{ print $1 }')
  
  if [ $chksum1 == $chksum2 ]; then
    echo "Uploaded the file to s3 bucket successfully !";
    if [ -f "$BACKUP_PATH/$FILE_2.tar.gz" ]; then
	rm -f "$BACKUP_PATH/$FILE_2.tar.gz"
    fi
  else
    echo "Uploaded file $FILE.tar.gz in s3 bucket:$S3_BUCKET is corrupted !";
  fi
else
  echo "=> Failed to create backup path: $BACKUP_PATH";
fi
