#!/bin/bash

#Prerequisites
#You need to run this stuff first manually
#
#  sudo adduser -p <password>
#
#
#Get Directory of this script
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
EPIC_SAVE_LOC="/home/steam/.config/Epic/FactoryGame/Saved/SaveGames"

#Satisfactory Game Default/Persistent Location
GAME_LOC="/games/satisfactory"
GAME_SAVES="${GAME_LOC}/saves"
GAME_BINARIES="${GAME_LOC}/binaries"

#Satisfactory Volatile/RamDrive Location(s)
GAME_RD_LOC="/tmp/satisfactory-ramdrive"
GAME_RD_SAVES="${GAME_RD_LOC}/saves"
GAME_RD_BINARIES="${GAME_RD_LOC}/binaries"

#Apache2 website root dir
WWW_ROOT="/var/www/html"
WWW_ARCHIVE="$WWW_ROOT/archive"
WWW_MANUAL="$WWW_ROOT/manual-saves"
WWW_HISTORY="$WWW_ROOT/history"
WWW_LEGEND="$WWW_ROOT/00_legend.txt"
WWW_LEGENDCONTENT="
Archive: For manually moving random saves into as needed.
Manual-Saves: Saved games with 'manual' in the name are copied here.
History: Everytime the cronjob runs, the current saves in root are compressed into a zip and dropped in here.
"

#install steamcmd if needed
echo "Checking for and if needed installing steamcmd"

if ! command -v steamcmd &> /dev/null; then
  sudo apt update -y
  sudo apt install software-properties-common -y
  sudo add-apt-repository multiverse
  sudo dpkg --add-architecture i386
  sudo apt update -y
  sudo echo steam steam/license note '' | sudo debconf-set-selections
  sudo echo steam steam/question select "I AGREE" | sudo debconf-set-selections
  sudo apt install steamcmd -y
fi

#install apache2 if needed
echo "Checking for and if needed installing apache2"

if [ ! -f /lib/systemd/system/apache2.service ]; then 
  sudo apt install apache2 -y
  sudo systemctl enable apache2
  sudo systemctl start apache2
fi

#Check if the Ramdisk is NOT Present
#Typically this will run after the server reboots since ramdisk is a temporary filesystem in ram.
if [ ! -d $GAME_RD_LOC ]; then
  echo "ramdrive not present -> Creating..."
  #If ramdisk is not present - create the dir and mount as ramdrive.
  sudo mkdir -p $GAME_RD_LOC
  sudo mount -t tmpfs -o size=12288m satisfactory ${GAME_RD_LOC}
  
  #check persistent storage for save files
  if [ -d "$GAME_SAVES" ]; then
    #if saves are there, sync them to the ramdrive
    echo "Directory for persistent saves found, attempting sync..."
    rsync -a $GAME_SAVES $GAME_RD_LOC
    wait
    else
      #if saves are missing make the directory on the ramdrive for them.
      echo "Directory for persistent saves not found, creating directory..."
      sudo mkdir -p $GAME_RD_SAVES
      sudo chown steam:steam $GAME_RD_SAVES
  fi

  #check persistant storage for game binaries
  if [ -d "$GAME_BINARIES" ]; then
    #if binaries are there, sync them to the ramdrive
    echo "Directory for persistent backup of satisfactory binaries found, attempting sync..."
    rsync -a $GAME_BINARIES $GAME_RD_LOC
    wait
    else
      #if binaries are missing make the directory on the ramdrive for them.
      echo "Directory for persistent backup of satisfactory binaries not found, creating directory..."
      sudo mkdir -p $GAME_RD_BINARIES
  fi
  
  #Make sure permissions on RAMDRIVE are good
  sudo chown -R steam:steam $GAME_RD_LOC

  #Verify Symlink for Save File Redirection is setup
  #Remember satisfactory runs as steam:steam
  #Deal with Backup copies & backup current.
  if [ ! -d $EPIC_SAVE_LOC ]; then
    mkdir -p $EPIC_SAVE_LOC
    ln -s $GAME_RD_SAVES $EPIC_SAVE_LOC/server
  else
    if [ -d $EPIC_SAVE_LOC/server-old ]; then rm -rf $EPIC_SAVE_LOC/server-old; fi
    if [ -d $EPIC_SAVE_LOC/server ]; then mv $EPIC_SAVE_LOC/server $EPIC_SAVE_LOC/server-old; fi
    ln -s $GAME_RD_SAVES $EPIC_SAVE_LOC/server
  fi

  #Now that all the framework is in place - run steamcmd to force an update and/or install satisfactory.
  echo "Run steamcmd to install/update satisfactory"
  sudo /usr/games/steamcmd +force_install_dir ${GAME_RD_BINARIES} +login anonymous +app_update 1690800 validate +quit

  #make sure service file is installed & loaded
  if [ ! -f /etc/systemd/system/satisfactory.service ]; then
    echo "satisfactory service file not found, installing and enabling service"
    sudo cp $SCRIPT_DIR/satisfactory.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable satisfactory
  fi

  #start the service
  echo "starting satisfactory service"
  sudo systemctl start satisfactory

#The following will run everytime this script runs, but the RAMDRIVE is already setup & mounted.
#Typically this will run periodically as part of a cron job, and will keep copies of
#saves/binaries somewhere persistent.
else
  #checks if folder for persistent saves exists, and if needed creates it.
  echo "checking for, and if needed creating folder for persistent saves."
  if [ ! -d $GAME_SAVES ]; then 
    sudo mkdir -p $GAME_SAVES
    sudo chown -R steam:steam $GAME_SAVES
  fi

  #copies any and all saves currently found in the Ramdrive, to the persistent storage.
  #this OVERWRITES anything in persistent storage.
  echo "copy current saves to persistent storage"
  sudo rsync -a --delete $GAME_RD_SAVES $GAME_LOC

  #copies individual save files to apache root - make available to users to download and use in tools
  #These are small but add up over time.
  #the www directory has been remounted on its own disk so it won't crash the server.
  
  #cleanup the history directory before we check the capacity
  #mtime +2 means older than 2 days
  find "$WWW_HISTORY" -type d -mtime +2 -exec rm -r {}\;

  #check the www capacity and if over 75% post to discord
  CURRENT_USAGE_PERCENT=$(df -h "/ssd/www" | awk 'NR==2{print $5}' | tr -d '%')
  USAGE_THRESHOLD=75
  WARNING_MESSAGE="WARNING:  Satisfactory Server /SSD mount is at "$CURRENT_USAGE_PERCENT"% Used"
  
  if [ "$CURRENT_USAGE_PERCENT" -gt "$USAGE_THRESHOLD" ]; then
    curl -X POST \
     -H "Content-Type: application/json" \
     -d "{\"content\":\"$WARNING_MESSAGE\"}" \
     "$DISC_WH"
  fi


  #now lets validate files and copy crap
  echo "verify folder/file structure"

  if [ ! -d "$WWW_ARCHIVE" ]; then
    sudo mkdir -p "$WWW_ARCHIVE"
  fi

  if [ ! -d "$WWW_MANUAL" ]; then
    sudo mkdir -p "$WWW_MANUAL"
  fi

  if [ ! "$WWW_LEGEND" ]; then
    sudo echo -e "$WWW_LEGENDCONTENT" > "$WWWLEGEND"
  fi

  echo "move current saves into history"
  NEW_HISTORY_PATH="$WWW_HISTORY"/"$(date +"%Y%m%d_%H%M%S")"
  sudo mkdir -p "$NEW_HISTORY_PATH"
  find "$WWW_ROOT" -maxdepth 1 -type f ! -name '00*' -exec sudo mv {} "$NEW_HISTORY_PATH" \;

  echo "copy current saves with 'manual' in the name."
  find "$GAME_SAVES" -maxdepth 1 -type f -name '*manual*' -exec sudo cp -p -f {} "$WWW_MANUAL" \;

  echo "copy current auto-saves to the WWW_ROOT directory"
  find "$GAME_SAVES" -maxdepth 1 -type f -name '*autosave*' -exec sudo cp -p -f {} "$WWW_ROOT" \;

  #checks if folder for persistent backups of game binaries exists, and if needed creates it.
  if [ ! -d $GAME_BINARIES ]; then
    sudo mkdir -p $GAME_BINARIES
    sudo chown -R steam:steam $GAME_BINARIES
  fi

  #copies any and all binaries found in the ramdrive, to the persistent storage.
  #this OVERWRITES ANYTHING in persistent storage.
  echo "copy current binaries to persistent storage"
  sudo rsync -a --delete $GAME_RD_BINARIES $GAME_LOC
  wait

fi