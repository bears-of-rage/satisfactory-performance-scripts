install_repo_dependencies(){
  sudo apt update -yqq
  sudo apt install -yqq software-properties-common
  sudo add-apt-repository multiverse
  sudo dpkg --add-architecture i386
}

install_steam() {
  sudo apt update -yqq
  sudo echo steam steam/license note '' | sudo debconf-set-selections
  sudo echo steam steam/question select "I AGREE" | sudo debconf-set-selections
  sudo apt install -yqq steamcmd
}

install_common() {
  sudo apt install  -yqq apache2 cron zip  python3-pip
  sudo systemctl enable apache2
  sudo systemctl start apache2
}

install_satisfactory() {
  local target=$1
  local login=$2
  local appid=$3
  sudo /usr/games/steamcmd +force_install_dir $target +login $login +app_update $appid validate +quit
}

setup_symlinks() {
  local path=$1
  local target=$2

  if [ ! -d "$path" ]; then
    mkdir -p "$path"
  else
    if [ -d "$path/server-old" ]; then 
      rm -rf "$path/server-old"
    fi
    
    if [ -d "$path/server" ]; then
      mv "$path/server" "$path/server-old"
    fi
  fi

  ln -s "$target" "$path/server"
}

install_jinja2cli() {
  sudo pip3 install -q -y jinja2-cli
}

delete_satisfactory_service() {
    local svcpath="/etc/systemd/system/satisfactory.service"
    sudo rm -rf "$svcpath"
    sudo systemctl daemon-reload
}

install_satisfactory_service() {
  local rgb=$1
  local ip=$2
  local port=$3
  local gameusr=$4
  local rgd=$5
  local evts=$6
  local svcpath="/etc/systemd/system/satisfactory.service"
  
  if [ -n "$evts" ]; then
    evts="-DisableSeasonalEvents"
  fi

  sudo jinja2 "service-template.j2" \
    -D bin="$rgb" \
    -D mh=" -multihome=$ip" \
    -D pt=" -ServerQUeryPort=$port" \
    -D de=" $evts" \
    -D usr="$gameusr" \
    -D gamedir="$rgd" \
    > "$svcpath"

  sudo systemctl daemon-reload
}

update_autosave_count(){
  local engine=$1
  local count=$2
  local option_line1="[/Script/FactoryGame.FGSaveSession]"
  local option_line2="mNumRotatingAutosaves="
  local fulloption="[/Script/FactoryGame.FGSaveSession]\nmNumRotatingAutosaves="
  local optionwithconfig="$option$count"

  sudo sed -i "/^$option_line1/d" "$engine"
  sudo sed -i "/^$option_line2/d" "$engine"
  sudo echo -e "$optionwithconfig" >> "$engine"
}

daily_archive() {
  local target=$1
  local source=$2
  local compression=$3
  local tarball="$(date +"%Y%m%d").tar.gz"

  if [ ! -d "$target" ]; then
    sudo mkdir -p "$target"
  fi

  if [ ! -e "$target/$tarball" ]; then
    sudo tar -czf "$target/$tarball" -C "$source" -"$compression" .
  fi
}

limit_history(){
  local target=$1
  local count=$2
  local subfolders="$target/*"

  if [ "${#subfolders[@]}" -gt "$count" ]; then
    list_of_folders=($(ls -t $target | tail -n +"$(($count + 1))"))

    for folder in "${list_of_folders[@]}"; do
      sudo rm -rf "$target/$folder"
    done
}

make_history() {
  local source=$1
  local target=$2
  local newhistory="$source"/"$(date +"%Y%m%d_%H%M%S")"

  sudo mkdir -p $newhistory
  find "$source" -maxdepth 1 -type f -name '*.sav' -exec sudo mv {} "$newhistory" \;
}

manual_sync() {
  local keyword=$1
  local source=$2
  local target=$3

  sudo mkdir -p $target
  find "$source" -maxdept 1 -type f -name "*$keyword*" -exec sudo cp -p -f {} "$target" \;
}

autosave_sync() {
  local source=$1
  local target=$2

  find "$source" -maxdept 1 -type -f  -name '*autosave*' -exec sudo cp -p -f {} "$target" \;
}

discord_message() {
  local webhook=$1
  local message=$2

  curl -X POST \
    -H "Content-Type: application/json" \
    -d "{\"content\":\"$message\"}" \
    "$webhook"
}