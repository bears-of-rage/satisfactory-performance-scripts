# satisfactory-performance-scripts
scripts to run satisfactory server on a ram disk with save files being copied and published via apache

# prereqs
suggest making two folders on root
/repos
/games

create steam user if you have not, make sure it has sudo access.
I also suggest making sure that steam has access to the above two directories natively.


# running the script
clone this repository into /repos
 - should end up with /repos/satisfactory-performance-scripts

execute the script via while logged in as steam user
cd /repos/satisfactory-performance-scripts
./satisfactory-cron.sh

# why are we using this script to run satisfactory
at a certain point there is too much crap in the save file - even though its small.
when satisfactory save process runs, it reindexes the file and if you have a bunch of stuff it will cause a hang for the players that is annoying.
to get around this we moved the game binaries & saves to a ram disk to remove as much latency as possible.
it does provide moderate improvement.
- it also means that if the server crashes or reboots all your crap is gone because...ram.

So this script comes into play.
The script runs - if its the first time on the server, it installs & configures all the things.
if its the first time since reboot it re-configures all the ram drive stuff.
once the ramdrive exists, it restores copies of binaries and save files to the ramdrive.
then it runs steamcmd to make sure the game is up to date, and starts the server service.

The next time the script runs, it will see that the ramdrive exists now.
since the ramdrive exists it means that the server was most likely running - and it copies any binaries and save files over to persistent locations on normal disk space.

Overall the idea is
 - set this up as a cron job under sudo (sudo crontab -e)
 - set it to run every 5 minutes.
 - every 5 minutes this runs, if its the first time - it installs all the shit, or sets up the ramdrive.
 - subsequent runs it backs up your shit to normal storage.
 - it also copies the save files to an apache web directory so that if you want users can hit the server and download the save file and upload it to utilities/etc.


# To setup the cron job
Again I'm assuming you have downloaded this crap to /repos

ssh into your server and run "sudo su crontab -e"
In the crontab file copy this line - make sure its uncommented.

*/5 * * * * /repos/satisfactory-performance-scripts/satisfactory-cron.sh

this will run the script in the path listed every 5 minutes.
so satisfactory autosaves run ever 10-15 minutes, this will sync them every 5.


