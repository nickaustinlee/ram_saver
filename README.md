# OS X RAM Saver Scripts

Are you sick of background apps eating up precious RAM on your Mac? I've noticed that even with 16 GB of RAM, I need to spend time killing unused background apps to free up space when I'm doing intensive work. This is annoying, and I built a program to help do this work for me in the background. If you have > 32 GB of RAM, you probably won't need this app.

RAM_SAVER: A lightweight set of scripts that periodically eliminates idle, memory-hogging UI programs if you have high memory pressure. 

The program defines > 1 GB of Swap and > 5 GB of Compressed Memory as the threshold to act. You can change these thresholds to meet your needs.

System compatibility: Mac OS X

Instructions

*Read through all of the scripts to make sure you're comfortable with what the program does! Don't blindly run .sh code without checking it first. *

You may need to run `chmod +x` on each file before it can operate on your system.

On OS X terminal, create a cron job: 

```bash
crontab -e
```

Add this to the cron jobs: 

```bash
*/10 * * * * /Users/your_username/path/to/ram_saver/memory_watcher.sh >> /Users/your_username/path/to/ram_saver/memory_monitor.log 2>&1
```
(put the appropriate username and/or file path)

Explanation: 
1. The cron job will run `memory_watcher.sh` every 10 minutes and output the logs to a file. `memory_watcher.sh` manages logging logic, and operates `memory_monitor.sh` to expunge apps.
2. `memory_monitor.sh` consults system metrics and uses empirical thresholds to determine if your computer has "memory pressure".
3. If `memory_monitor.sh` determines you have memory pressure, it will run `kill_unused_apps.sh` to kill all UI-based programs that don't currently have a UI screen visible, consume >100 MB in system memory, and were created > 1 hour ago.
4. Logs are piped to a `memory_monitor.log`. There is code logic in `memory_watcher.sh` to rotate the log file when it hits 10 MB, and then wipe the log clean. So you'll never have more than 20 MB of logs.

NOTE: You can change the thresholds for your personal definition of "memory pressure". I'm using an older computer (Macbook Air M2, with 16GB RAM), and I empirically found that Compressed Memory > 5 GB or SWAP > 1 GB usually means the system is starting to experience pressure. 

## Excluding Apps ##

Add the name of each app to the `exclude_apps.txt` file, on a new line. The name of the app might differ slightly from the name of the process to kill. You can use this command to figure out the exact names: 

```bash
ps aux | grep -i <app_name>
```
For example, when I do this for backblaze, I discover the process name is actually "Backblaze11". 

```bash
Mac:Programming nicklee$ ps aux | grep -i backblaze
nicklee          83792   0.4  0.4 411874400  71808   ??  S     7:48PM   0:00.94 /Applications/Backblaze.app/Contents/MacOS/Backblaze11
root             82436   0.1  0.0 411357008   7008   ??  S     6:35PM   0:42.20 /Library/Backblaze.bzpkg/bzfilelist
nicklee           1730   0.0  0.3 412004288  56080   ??  S    13Mar25   0:16.42 /Library/Backblaze.bzpkg/bzbmenu.app/Contents/MacOS/bzbmenu
root              1053   0.0  0.0 411741328   6464   ??  Ss   13Mar25   8:59.78 /Applications/Backblaze.app/Contents/MacOS/bzserv
```
Therefore, I would put Backblaze11 on my exclusion list. 
