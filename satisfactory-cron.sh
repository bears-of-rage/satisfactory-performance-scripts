#!/bin/bash

# Functions
source satisfactory-functions.sh

# Required
working_dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
  json_data=$(cat "$working_dir/satisfactory-configs.json")

# Values from JSON
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
              gameusr=$(echo "$json_data" | jq -r '.["satisfactory-configs"].sudo_user_account')
              host_ip=$(echo "$json_data" | jq -r '.["satisfactory-configs"].host_server_local_ip')
            game_port=$(echo "$json_data" | jq -r '.["satisfactory-configs"].satisfactory_query_port')
     disable_seasonal=$(echo "$json_data" | jq -r '.["satisfactory-configs"].disable_seasonal_events_yesno')
       autosave_count=$(echo "$json_data" | jq -r '.["satisfactory-configs"].number_of_autosaves')
           steamappid=$(echo "$json_data" | jq -r '.["satisfactory-configs"].steamcmd_satisfactory_id')
    original_save_dir=$(echo "$json_data" | jq -r '.["satisfactory-configs"].original_save_loc')
     persist_game_dir=$(echo "$json_data" | jq -r '.["satisfactory-configs"].persistent_game_loc')
         ram_game_dir=$(echo "$json_data" | jq -r '.["satisfactory-configs"].ramdrive_game_loc')
       ram_drive_size=$(echo "$json_data" | jq -r '.["satisfactory-configs"].ramdrive_size_in_MB')
    history_retention=$(echo "$json_data" | jq -r '.["satisfactory-configs"].history_retention')
history_daily_archive=$(echo "$json_data" | jq -r '.["satisfactory-configs"].history_daily_consolidate_yesno')
        manualkeyword=$(echo "$json_data" | jq -r '.["satisfactory-configs"].manual_save_keyword')
      manual_save_dir=$(echo "$json_data" | jq -r '.["satisfactory-configs"].manual_save_dir_yesno')
       discord_notify=$(echo "$json_data" | jq -r '.["satisfactory-configs"].discord_notify_yesno')
      discord_webhook=$(echo "$json_data" | jq -r '.["satisfactory-configs"].discord_webhook')
     notify_threshold=$(echo "$json_data" | jq -r '.["satisfactory-configs"].discord_notify_threshold')
        cron_interval=$(echo "$json_data" | jq -r '.["satisfactory-configs"].crontab_interval_in_minutes')
        svc_overwrite=$(echo "$json_data" | jq -r '.["satisfactory-configs"].overwrite_existing_service_yesno')
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Constants
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
                      usrhome="/home/$gameusr"
             persist_game_bin="$persist_game_dir/binaries"
            persist_game_saves="$persist_game_dir/saves"
                 ram_game_bin="$ram_game_dir/binaries"
                ram_game_saves="$ram_game_dir/saves"
                   engine_ini="$ram_game_bin/FactoryGame/Saved/Config/LinuxServer/Engine.ini"
  original_save_dir_full_path="$usrhome/$original_save_dir"
                     www_root="/var/www/html"
                  www_archive="$www_root/archive"
                   www_manual="$www_root/manual"
                  www_history="$www_root/history"
               www_historycon="$www_root/consolidated_history"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Pre-Requisite Checks
#  What user am I?
#  Do I have sudo access?
#  Am I scheduled to repeat?
#  Do I need a sudo password?

echo -e "\e[33mchecking if ramdrive is present...\e[0m"

if [ ! -d $ram_game_dir ]; then
  echo -e "\e[33mramdrive not found...entering validation mode\e[0m"
  
  # Validation Mode

  # Make sure software is installed
  install_repo_dependencies
  install_steam
  install_common
  install_jinja2cli

  # Create RamDrive Folder & Mount as Drive
  sudo mkdir -p $ram_game_dir
  sudo mount -t tmpfs -o size="$ram_drive_size"m satisfactory "$ram_game_dir"

  # Check if persistent saves already exist
  if [ -d "$persist_game_saves" ]; then
    # Saves Exist, Copy into RamDrive
    sudo rsync -a "$persist_game_saves" "$ram_game_dir"
    wait
  else
    # Saves do NOT exist, create directory structure
    sudo mkdir -p "$ram_game_saves"
  fi

  # Check if satisfactory binaries and configs already exist
  if [ -d "$persist_game_bin" ]; then
    # Binares Exist, Copy into RamDrive
    sudo rsync -a "$persist_game_bin" "$ram_game_dir"
    wait
  else
    # Binaries do NOT Exist, create directory structure.
    sudo mkdir -p "$ram_game_bin"
  fi

  # Recursively ensure all permissions are correct
  sudo chown -R "$gameusr":"$gameusr" "$ram_game_dir"

  # Verify Symlinks and Install/Update Satisfactory
  setup_symlinks $original_save_dir_full_path $ram_game_saves
  install_satisfactory "$ram_game_bin" "anonymous" "$steamappid"

  # Configure Satisfactory to Run as a Service
  if [ "$svc_overwrite" == "yes" ]; then
    delete_satisfactory_service
  fi

  if [ ! -f /etc/systemd/system/satisfactory.service ]; then
    install_satisfactory_service $ram_game_bin $host_ip $game_port $gameusr $ram_game_dir $disable_seasonal
  fi

  # Validate Additional Configurations
  # Number of AutoSaves
  update_autosave_count $engine_ini $autosave_count

  # Start The Server
  sudo systemctl start satisfactory

else
  echo -e "\e[32mramdrive found...entering sync mode[0m"

  # Make sure Persistent Saves Directory Exists
  if [ ! -d "$persist_game_saves" ]; then 
    sudo mkdir -p "$persist_game_saves"
    sudo chown -R "$gameusr":"$gameusr" "$persist_game_saves"
  fi

  # Copies all save files from Ramdrive to persistent Storage
  sudo rsync -a --delete $ram_game_saves $persist_game_dir

  # Game Save Publishing

  # Check for and Create tarball of current histories if enabled
  if [ "$history_daily_archive" == "yes" ]; then
    daily_archive $www_historycon $www_history 9
  fi

  # Cleanup Existing History
    limit_history $www_history $history_retention

  # Update History
    make_history $www_root $www_history

  # if enabled, make copies of manual files with keyword
  if [ "$manual_save_dir" == "yes" ]; then
    manual_sync $manualkeyword $ram_game_saves $www_manual
  fi
  
  # sync the normal autosaves into the webroot
  autosave_sync $ram_game_saves $www_root
  
  # copy binaries to persistent storage
  if [ ! -d "$persist_game_bin" ]; then
    sudo mkdir -p "$persist_game_bin"
    sudo chown -R "$gameusr":"$gameusr" "$persist_game_bin"
  fi
  sudo rsync -a --delete "$ram_game_bin" "$persist_game_dir"
  wait

  # check disk capacity
  if [ "$discord_notify" == "yes" ]; then
    usage=$(df -h "$www_root" | awk 'NR==2{print $5}' | tr -d '%')
    message="ALERT: satisfactory Server has a disk at "$usage"% used"

    if [ "$usage" -gt "$notify_threshold" ]; then
      discord_message $message $discord_webhook
    fi
fi