# Windows 7 games on Wine
This is a guide to show how to get classic windows 7 games working through WINE (only tested on linux mint, some things may not work as shown)
(do screenshots in a VM)

0. Before installing the app, wine must be installed on your system. You need any version of [wine](https://gitlab.winehq.org/wine/wine/-/wikis/Download) starting with 11.0, as that is when running 32bit application alongside 64bit ones is available. However with the base application sound does not function on all games, excluding Chess Titans. The method I have chosen is downloading [kron4ek wine](https://github.com/Kron4ek/Wine-Builds/releases) (11.2 wow64 used), placing in a folder with its own prefix (if used alongside regulare wine, since it wants to change the default prefix settings, breaking some apps), and then running it from there. You can use more user-friendly apps, like bottles and lutris, but either it starts after 5 seconds, or is too fiddly to set up, thus other methods will not be covered here.
1. Get the [windows 7 games installer](https://win7games.com/#games) from Aero, since it is packaged to be easy to install
2. Execute instaler with wine, it may take a few seconds for the installer to show up
2a. Kronek: wine is located in `/wine-11.2-amd64-wow64/bin/wine`, 
3. Click on language you want to install, afterwards select whitch games will be installed (by default all offline ones are selected), untick "learn more"'s at the end or you will get sent to a browser page
4. SInce MUI files are not supported by Wine, all games will not load the UI correctly, and some may just not open. To solve this, editing the games' files in your `drive_c/Program Files/Microsoft Games` by using [resource hacker](https://www.angusj.com/resourcehacker)
4a. Alternively, if you, trust a stranger on the internet (I am not random, you cliked on this guide), you can download the modified files under fixedwingames. Download the whole folder and take the files in them to their respective loactions in your install with the same names. You can delete the folder (named after the language you chose) in each game folder so save precious kilobytes
5. After installing resource hacker through Wine, open it, find chess.exe and the folder next to it, click on import thing, merge, [remember settings] done, delete old exe and mui, do the same for all mui files with matching .exe's or .dll's. Full list of files to merege is:

7. All Done! if importing old saves, they located in `drive_c/users/$USER/AppData/Local/Microsoft Games`, otherwise sound may not work in all but chess
 [check if icons are in system with only kron4ek installed]
9. Not all done for Kronek! To have an easier time with calling this specific wine from its folder, you can place a shell file in `.local/bin`
10. Personally, I placed:

```bash
#!/bin/bash
env WINEPREFIX=/home/$USER/.kron4ek-wine/wowsoundfix /home/$USER/.kron4ek-wine/wine-11.2-amd64-wow64/bin/wine "$@"
```


Personal note:
Wine developers, and those in general focused on its betterment, seem to love older windows versions before Vista (for exmple the inbuilt minesweeper, nd general visuals), but I am nostalgic for the windows 7 era aero style, where the inbuilt games got modern enough to not seem "vintage" but before the hellscape that is Microsoft Solitaire Collection.
Shoutout to the one [useful forum post](https://forum.winehq.org/viewtopic.php?t=37417) that gave me the begginings of solving the ui issues, since Wine cannot handle MUI files.
Also I am using the images from another (archived) (github guide)[https://web.archive.org/web/20220914142532/https://gist.github.com/eladkarako/0c23ce1157b4c6175817c78a7adb577f], since they are very nicely edited.

---
