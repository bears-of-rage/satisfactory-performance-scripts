GAME-LOC="/games/satisfactory"
GAME-RD-LOC="/tmp/satisfactory-ramdrive"
GAME-RAMDRIVE-SAVES="${GAME-RD-LOC}/satisfactory-saves"
GAME-RAMDRIVE-BINARIES="${GAME-RD-LOC}/satisfactory"
WWW-ROOT="/var/www/html/"

if [! -d '$GAME-RD-LOC' ]; then
  sudo mkdir -p '$GAME-RD-LOC'
  sudo mount -t tmpfs -o size=12288m satisfactory ${GAME-RD-LOC}
  rsync -a ${GAME-LOC}/satisfactory-saves ${GAME-RAMDRIVE-SAVES}
  wait
  sudo chown -R steam:steam ${GAME-RAMDRIVE-SAVES}
  wait
  rsync -a ${GAME-LOC}/satisfactory ${GAME-RD-LOC}
  wait
  sudo chown -R steam:steam ${GAME-RAMDRIVE-BINARIES}
  wait
  sudo /usr/games/steamcmd +force_install_dir ${GAME-RD-LOC} +login anonymous +app_update 1690800 validate +quit
  wait
  sudo systemctl start satisfactory
  wait
  sleep 5
else
  if [! -d ${GAME-LOC}/satisfactory-saves]; then
    sudo mkdir -p ${GAME-LOC}/satisfactory-saves
  fi
  sudo rsync -a --delete ${GAME-RAMDRIVE-SAVES} ${GAME-LOC}/satisfactory-saves/
  sudo rsync -r ${GAME-LOC}/satisfactory-saves/Epic/FactoryGame/Saved/SaveGames/server/ ${WWW-ROOT}

  if [ ! -d ${GAME-RD-LOC}/satisfactory ]; then
    sudo mkdir -p ${GAME-RD-LOC}/satisfactory
    sudo rsync -a --delete ${GAME-RAMDRIVE-BINARIES} ${GAME-RD-LOC}/satisfactory/
    wait
   fi
fi
