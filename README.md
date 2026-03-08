# Windows 7 games on Wine
This is a guide to show how to get classic windows 7 games working through WINE 
(only tested on linux mint, some things may not work as shown)

## Prerequisites
Before installing the games, You need any version of [wine](https://gitlab.winehq.org/wine/wine/-/wikis/Download) installed on your system, starting with 11.0, as that is when running 32bit application alongside 64bit ones is available. However with the base application sound does not function on all games, excluding Chess Titans.
The method I have chosen to get sound working is downloading [kron4ek wine](https://github.com/Kron4ek/Wine-Builds/releases) (11.2 wow64 used), placing in a folder with its own prefix (if it is used alongside regular wine it might break some apps already installed, as it wants to change the default prefix settings), and then running it from there. You can use more user-friendly apps, like bottles and lutris, but either it starts after 5 seconds, or is too fiddly to set up, thus other methods will not be covered here.
Apart from wine, the [windows 7 games installer](https://win7games.com/#games) from Aero will be used, since it is packaged to be easy to install.
The tool used to fix the executables used in this guide is [resource hacker](https://www.angusj.com/resourcehacker).

## Plain Wine
If Wine 11.0 or later is already installed on your system, and are not bothered with a possible lack of sound, then the next steps are fairly easy:
1. Execute the games installer with wine, select the language you prefer, it may take a bit for the installer to go to the next option.
3. Click on the language you want to install, afterwards select whitch games will be installed (by default all offline games are selected), untick "learn more"'s at the end or you will get sent to a browser page
4. SInce [MUI files are not supported by Wine](https://forum.winehq.org/viewtopic.php?t=37417), all games will not load the UI correctly, and some may just not open. To solve this, you will need the games' files in your `drive_c/Program Files/Microsoft Games` by using resource hacker.
- Alternatively, if you, trust a stranger on the internet, you can download the modified files under `enUS-exes`.
5. After installing resource hacker through Wine, in the app file => open, find `chess.exe` under `My computer -> C: -> Program Files/Microsoft Games` open it, click on Action => Add from resource file, slect to display all files, enter the flder next to the executables, select the .MUI file, tick [overwrite], tick [check all], import, file => save, repeat for all main .exe files n every game folder with matching .MUI's, you can also use the folder and floffy disk icons, or ctrl+o and ctrl+s for a faster experience. Full list of files to merge is:
```
chess.exe + chess.exe.mui
FreeCell.exe + FreeCell.exe.mui
Hearts.exe + Hearts.exe.mui
Mahjong.exe + Mahjong.exe.mui
Minesweeper.exe + Minesweeper.exe.mui
PurblePlace.exe + PurblePlace.exe.mui
Solitaire.exe + Solitaire.exe.mui
SpiderSolitaire.exe + SpiderSolitaire.exe.mui
```
6. Afterwards, you can delete all files with `_original` in their name, and the folders of the language with the .mui file
7. If wine did not create the shortcuts properly, it can be done manually by going to `.wine/drive_c/ProgramData/Microsoft/Windows/Start Menu/Programs/Games`, open a command line there, and type `wine winemenubuilder <.lnk name>` for every game you want a shortcut for.

## Kron4ek Wine
There is an automatic script that will set up the `krowine` command in `.local/bin` and set up the desktop shortcuts, and in `.local/share/applications` through they will have to be moved to a category manually, as long as you place the aero installer and the wine-11.2-amd64-wow64.tar.xz in the folder downloaded from the repo. Modify the `kron4ek-install.sh` if you want to change the parameters.
### Manual
1. The Wine executable is located in `/wine-11.2-amd64-wow64/bin/wine`
2. To have the prefix contained, you can invoke aspecific location from the start thus the full command can look like:
```bash
#!/bin/bash
env WINEPREFIX=/home/$USER/.kron4ek-wine/wowsoundfix /home/$USER/.kron4ek-wine/wine-11.2-amd64-wow64/bin/wine <exeutable>
```
3. all of this can be placed in a single shell file and used as a fucntion by adding `"$@"` at the end to pass the arguments to the command, as with the `krowine` file in this repository.
4. All Done! if importing old saves, they located in `drive_c/users/$USER/AppData/Local/Microsoft Games`, otherwise sound may not work in all but chess
- Not all done for Kronek! To have an easier time with calling this specific wine from its folder, you can place a shell file in `.local/bin`
  Personally, I placed:



## Screenshots





---

Personal note:
Wine developers, and those in general focused on its betterment, seem to love older windows versions before Vista (for exmple the inbuilt minesweeper, nd general visuals), but I am nostalgic for the windows 7 era aero style, where the inbuilt games got modern enough to not seem "vintage" but before the hellscape that is Microsoft Solitaire Collection.
Shoutout to the one [useful forum post](https://forum.winehq.org/viewtopic.php?t=37417) that gave me the begginings of solving the ui issues, since Wine cannot handle MUI files.
Also I am using the images from another (archived) [github guide](https://web.archive.org/web/20220914142532/https://gist.github.com/eladkarako/0c23ce1157b4c6175817c78a7adb577f), since they are very nicely edited.
