GAME_LOC="/games/satisfactory"
GAME_RD_LOC="/tmp/satisfactory-ramdrive"
GAME_RAMDRIVE_SAVES="${GAME_RD_LOC}/satisfactory-saves"
GAME_RAMDRIVE_BINARIES="${GAME_RD_LOC}/satisfactory"
WWW_ROOT="/var/www/html/"

if [! -d $GAME_RD_LOC ]; then
  sudo mkdir -p $GAME_RD_LOC
  sudo mount -t tmpfs -o size=12288m satisfactory ${GAME_RD_LOC}
  rsync -a ${GAME_LOC}/satisfactory-saves ${GAME_RAMDRIVE_SAVES}
  wait
  sudo chown -R steam:steam ${GAME_RAMDRIVE_SAVES}
  wait
  rsync -a ${GAME_LOC}/satisfactory ${GAME_RD_LOC}
  wait
  sudo chown -R steam:steam ${GAME_RAMDRIVE_BINARIES}
  wait
  sudo /usr/games/steamcmd +force_install_dir ${GAME_RD_LOC} +login anonymous +app_update 1690800 validate +quit
  wait
  sudo systemctl start satisfactory
  wait
  sleep 5
else
  if [! -d ${GAME_LOC}/satisfactory-saves]; then
    sudo mkdir -p ${GAME_LOC}/satisfactory-saves
  fi
  sudo rsync -a --delete ${GAME_RAMDRIVE_SAVES} ${GAME_LOC}/satisfactory-saves/
  sudo rsync -r ${GAME_LOC}/satisfactory-saves/Epic/FactoryGame/Saved/SaveGames/server/ ${WWW_ROOT}

  if [ ! -d ${GAME_RD_LOC}/satisfactory ]; then
    sudo mkdir -p ${GAME_RD_LOC}/satisfactory
    sudo rsync -a --delete ${GAME_RAMDRIVE_BINARIES} ${GAME_RD_LOC}/satisfactory/
    wait
  fi
fi
