#!/bin/bash

INTERVAL=3 #seconds
OXALIS_HOME=/opt/.oxalis
INBOUND_DIR=$OXALIS_HOME/inbound
NFS_DIR=$OXALIS_HOME/nfs_folder_name/OxalisInbound
NFS_DIR_SEC=$OXALIS_HOME/nfs_folder_secondary_name/OxalisInbound
TEMP_DIR=$OXALIS_HOME/tmp #temp storage to move files

while true
do

  # check directory exists
  if [ -d $INBOUND_DIR ]; then
    if [ -d $NFS_DIR ]; then
	  # check for new files in inbound directory
      if [ ! -z "$(ls -A $INBOUND_DIR)" ]; then

        TEMP=$TEMP_DIR/$(uuidgen)

        mkdir $TEMP

        mv -f $INBOUND_DIR/* $TEMP/

        cp -f -r $TEMP/* $NFS_DIR

        if [ -d $NFS_DIR_SEC ]; then
          cp -f -r $TEMP/* $NFS_DIR_SEC
        fi
        
        rm -r $TEMP
      fi
    fi
  fi

  sleep $INTERVAL
  
done
