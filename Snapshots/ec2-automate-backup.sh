#!/bin/bash

# Make sure you use the AWS API tools, not the AMI tools
#Environment Variables
export PATH=$PATH:$EC2_BIN
EC2_HOME=/usr/bin
EC2_BIN=/usr/bin
 
# store the certificates and private key to your amazon account
MY_CERT='/home/<username>/<path-to-cert-XXXXXXXXXXXXXXXXXXXXXXXXXXX.pem>'
MY_KEY='/home/<username>/<path-to-pk-XXXXXXXXXXXXXXXXXXXXXXXXXXXX.pem>'

#Get these credentials from  AWS Identity and Access Mangement (IAM) console from your AWS account
MY_ACCESS_ID=AKIAJIXXXXXXXXXXXXXX
MY_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# fetching the instance-id from the metadata repository
# This instruction displays the Instance ID 
MY_INSTANCE_ID=`wget -q -O- http://169.254.169.254/latest/meta-data/instance-id`
 
# temproary file
TMP_FILE='/tmp/rock-ebs-info.txt'
 
# get list of locally attached volumes via EC2 API:

$EC2_BIN/ec2-describe-volumes -C $MY_CERT -K $MY_KEY > $TMP_FILE
VOLUME_LIST=$(cat $TMP_FILE | grep ${MY_INSTANCE_ID} | awk '{ print $2 }')
 
sync
 
#create the snapshots
echo "Create EBS Volume Snapshot - Process started at $(date +%m-%d-%Y-%T)"
echo ""
echo $VOLUME_LIST
for volume in $(echo $VOLUME_LIST); do
   NAME=$(cat $TMP_FILE | grep Name | grep $volume | awk '{ print $5 }')
   DESC=$NAME-$(date +%m-%d-%Y)
   echo "Creating Snapshot for the volume: $volume with description: $DESC"
   echo "Snapshot info below:"
   $EC2_BIN/ec2-create-snapshot -C $MY_CERT -K $MY_KEY -d $DESC $volume
   echo ""
done
 
echo "Snapshot Creation Process ended at $(date +%m-%d-%Y-%T)"
echo ""
 
#remove the temp file
rm -f $TMP_FILE


#Delete the Old snapshots

#temporary file 
TMP_SFILE='/tmp/snap_inf.txt'

#You can change the number of days by just changing the "3 days ago" to "x days ago"
date_3d=`date +%Y-%m-%d --date '3 days ago'` 

#Volume ID of the particular EC2 Instance
vol_id=vol-XXXXXXX 

#EC2 API command to Describe snapshots
# Here the output of the below statement is stored in a temporary file for further usage
ec2-describe-snapshots -O $MY_ACCESS_ID -W $MY_ACCESS_KEY | grep $date_3d | awk '{ if($3 == $vol_id) print $2 }' > /tmp/snap_inf.txt 2>&1

#Reading the temporary file and assigning the Snapshot ID to the variable
snapshot_name=`cat /tmp/snap_inf.txt | grep "$obj0" | awk '{print $1}'`

#Messages to log the events
echo "Deleting the snapshot id:$snap_id which is 3 days old (i.e. $date_3d) ......"

#EC2 API command to delete the snapshots
ec2-delete-snapshot -C $EC2_CERT -K $EC2_PRIVATE_KEY $snapshot_name
echo "deleted the old snapshot successfully ! "

#remove the temporary file
rm -f $TMP_SFILE

echo "Snapshot Deletion Process ended at $(date +%m-%d-%Y-%T)"
echo ""
