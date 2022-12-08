#Get Directory of this script
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
EPIC_LOC="/home/steam/.config"

#Satisfactory Game Default/Persistent Location
GAME_LOC="/games/satisfactory"
GAME_SAVES="${GAME_LOC}/saves"
GAME_BINARIES="${GAME_LOC}/binaries"

#Satisfactory Volatile/RamDrive Location(s)
GAME_RD_LOC="/tmp/satisfactory-ramdrive"
GAME_RD_SAVES="${GAME_RD_LOC}/saves"
GAME_RD_BINARIES="${GAME_RD_LOC}/binaries"

#Apache2 website root dir
WWW_ROOT="/var/www/html/"

#install steamcmd if needed
IS_STEAM_HERE=$(command -v steamcmd >/dev/null 2>&1 || { echo >&2 "no"; })
if [ "$IS_STEAM_HERE" = "no" ]; then sudo apt install steamcmd -y; fi

#install apache2 if needed
if [ ! -f /etc/systemd/system/apache2.service ]; then 
  sudo apt install apache2 -y
  sudo systemctl enable apache2
  sudo systemctl start apache2
fi

#Check if the Ramdisk is NOT Present
#Typically this will run after the server reboots since ramdisk is a temporary filesystem in ram.
if [ ! -d $GAME_RD_LOC ]; then

  #If ramdisk is not present - create the dir and mount as ramdrive.
  sudo mkdir -p $GAME_RD_LOC
  sudo mount -t tmpfs -o size=12288m satisfactory ${GAME_RD_LOC}
  
  #check persistent storage for save files
  if [ -d "$GAME_SAVES" ]; then
    #if saves are there, sync them to the ramdrive
    rsync -a $GAME_SAVES $GAME_RD_SAVES
    wait
    else
      #if saves are missing make the directory on the ramdrive for them.
      sudo mkdir -p $GAME_RD_SAVES
  fi

  #check persistant storage for game binaries
  if [ -d "$GAME_BINARIES" ]; then
    #if binaries are there, sync them to the ramdrive
    rsync -a $GAME_BINARIES $GAME_RD_BINARIES
    wait
    else
      #if binaries are missing make the directory on the ramdrive for them.
      sudo mkdir -p $GAME_RD_BINARIES
  fi

  #Verify Symlink for Save File Redirection is setup
  #Remember satisfactory runs as steam:steam
  #Deal with Backup copies & backup current.
  if [ -d "$EPIC_LOC/Epic.old" ]; then sudo rm -rf $EPIC_LOC/Epic.old; fi
  if [ -d "$EPIC_LOC/Epic" ]; then sudo mv $EPIC_LOC/Epic $EPIC_LOC/Epic.old; fi

  #Recreate Symlink
  sudo ln -s $GAME_RD_SAVES $EPIC_LOC/Epic

  #Now that all the framework is in place - run steamcmd to force an update and/or install satisfactory.
  sudo /usr/games/steamcmd +force_install_dir ${GAME_RAMDRIVE_BINARIES} +login anonymous +app_update 1690800 validate +quit

  #make sure service file is installed & loaded
  if [ ! -f /etc/systemd/system/satisfactory.service ]; then
    sudo cp $SCRIPT_DIR/satisfactory.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable satisfactory
  fi

  #start the service
  sudo systemctl start satisfactory

#The following will run everytime this script runs, but the RAMDRIVE is already setup & mounted.
#Typically this will run periodically as part of a cron job, and will keep copies of
#saves/binaries somewhere persistent.
else
  #checks if folder for persistent saves exists, and if needed creates it.
  if [ ! -d $GAME_SAVES ]; then sudo mkdir -p $GAME_SAVES; fi

  #copies any and all saves currently found in the Ramdrive, to the persistent storage.
  #this OVERWRITES anything in persistent storage.
  sudo rsync -a --delete $GAME_RD_SAVES $GAME_SAVES

  #copies individual save files to apache root - make available to users to download and use in tools
  #These are small
  sudo rsync -r ${GAME_SAVES}/FactoryGame/Saved/SaveGames/server/ $WWW_ROOT

  #checks if folder for persistent backups of game binaries exists, and if needed creates it.
  if [ ! -d $GAME_BINARIES ]; then sudo mkdir -p $GAME_BINARIES; fi

  #copies any and all binaries found in the ramdrive, to the persistent storage.
  #this OVERWRITES ANYTHING in persistent storage.
  sudo rsync -a --delete $GAME_RD_BINARIES $GAME_BINARIES
  wait
fi