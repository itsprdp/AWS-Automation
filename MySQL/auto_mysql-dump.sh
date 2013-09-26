#!/bin/bash
 # Environment Variables
 DB_BACKUP="/var/backups/`date +%Y-%m-%d`"
 DB_USER="<db_username>"
 DB_PASSWD="<db_password>"
 PASS="<some_random_password>"
 DB_TNAME="<db_table_name>"

 # Getting the Hostname of the Machine
 HN=`hostname | awk -F. '{print $1}'`
  
 # Create the backup directory under /var/backups/ as XXXX-XX-XX/
 mkdir -p $DB_BACKUP
    
 # Remove backups older than 10 days
 TEMP=`find "/var/backups/" -maxdepth 1 -type d -mtime +10`
 rm -rf $TEMP
 # Option 1: Backup each database on the system using a root username and password
 for db in $(mysql --user=$DB_USER --password=$DB_PASSWD -e 'show databases' -s --skip-column-names| grep -i $DB_TNAME)
   do sudo mysqldump --user=$DB_USER --password=$DB_PASSWD --opt $db | gzip > "$DB_BACKUP/mysqldump-$HN-$db-$(date +%Y-%m-%d).gz"
    openssl enc -aes-256-cbc -e -in "$DB_BACKUP/mysqldump-$HN-$db-$(date +%Y-%m-%d).gz" -out "$DB_BACKUP/mysqldump-$HN-$db-$(date +%Y-%m-%d).gz.enc" -pass pass:$PASS
    rm -rf "$DB_BACKUP/mysqldump-$HN-$db-$(date +%Y-%m-%d).gz"
   done

#For Decryption Use this and the <password> would be same as the encryption password
#openssl aes-256-cbc -d -in <input_encrypted_file.gz> -out <output_decrypted.gz> -pass pass:<password>
