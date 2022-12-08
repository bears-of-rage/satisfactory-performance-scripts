#Satisfactory Game Default/Persistent Location
GAME_LOC="/games/satisfactory"
GAME_SAVES="${GAME_LOC}/saves"
GAME_BINARIES="${GAME_LOC}/binaries"

#Satisfactory Volatile/RamDrive Location(s)
GAME_RD_LOC="/tmp/satisfactory-ramdrive"
GAME_RAMDRIVE_SAVES="${GAME_RD_LOC}/satisfactory-saves"
GAME_RAMDRIVE_BINARIES="${GAME_RD_LOC}/satisfactory"

#Apache2 website root dir
WWW_ROOT="/var/www/html/"

#steamcmd status
IS_STEAM_HERE=$(command -v steamcmd >/dev/null 2>&1 || { echo >&2 "no"; })

#Check if steamcmd is installed
if [ "$IS_STEAM_HERE" = "no" ]; then
  sudo apt install steamcmd -y
fi

#Check if the Ramdisk is Present
if [ ! -d $GAME_RD_LOC ]; then

  #If ramdisk is not present - create the dir and mount as ramdrive.
  sudo mkdir -p $GAME_RD_LOC
  sudo mount -t tmpfs -o size=12288m satisfactory ${GAME_RD_LOC}
  
  #check persistent storage for save files
  if [ -d "$GAME_SAVES/satisfactory-saves" ]; then
    #if saves are there, sync them to the ramdrive
    rsync -a $GAME_SAVES/satisfactory-saves ${GAME_RD_LOC}/
    wait
    else
      #if saves are missing make the directory on the ramdrive for them.
      sudo mkdir -p $GAME_RAMDRIVE_SAVES
  fi

  #check persistant storage for game binaries
  if [ -d "$GAME_BINARIES/satisfactory" ]; then
    #if binaries are there, sync them to the ramdrive
    rsync -a $GAME_BINARIES/satisfactory ${GAME_RD_LOC}/
    wait
    else
      #if binaries are missing make the directory on the ramdrive for them.
      sudo mkdir -p $GAME_RAMDRIVE_BINARIES
  fi

  #Now that the framework is in place - run steamcmd to force an update and/or install satisfactory.
  sudo /usr/games/steamcmd +force_install_dir ${GAME_BINARIES} +login anonymous +app_update 1690800 validate +quit
fi

#else
#  if [ ! -d ${GAME_LOC}/satisfactory-saves ]; then
#    sudo mkdir -p ${GAME_LOC}/satisfactory-saves
#  fi
#  sudo rsync -a --delete ${GAME_RAMDRIVE_SAVES} ${GAME_LOC}/satisfactory-saves/
#  sudo rsync -r ${GAME_LOC}/satisfactory-saves/Epic/FactoryGame/Saved/SaveGames/server/ ${WWW_ROOT}
#
#  if [ ! -d ${GAME_RD_LOC}/satisfactory ]; then
#    sudo mkdir -p ${GAME_RD_LOC}/satisfactory
#    sudo rsync -a --delete ${GAME_RAMDRIVE_BINARIES} ${GAME_RD_LOC}/satisfactory/
#    wait
#  fi
#fi
