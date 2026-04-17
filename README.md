# Windows 7 games on Wine
This is a guide to show how to get classic windows 7 games working through WINE.

The modified games should be functiona on any x86 system from wine 11.0, but sound may be broken (verified it works on Bazzite if installed with rpm-ostree)

## Prerequisites
[Wine](https://gitlab.winehq.org/wine/wine/-/wikis/Download) installed on your system, starting with 11.0, as that is when running 32bit application alongside 64bit ones is available.

An alternative to not install wine in the sytem is using the pre-compiled [kron4ek wine](https://github.com/Kron4ek/Wine-Builds/releases) (wine-xx.x-amd64-wow64.tar.xz), placing in a folder with its own prefix (if it is used alongside regular wine it might break some apps already installed, as it wants to change the default prefix settings), and then running it from there.

For the games themselves, the [windows 7 games installer](https://win7games.com/#games) from Aero will be used, since it is packaged to be easy to install.

The tool used to fix the executables used in this guide is [resource hacker](https://www.angusj.com/resourcehacker).

## Instruction
1. Execute the games installer with wine, select the language you prefer, it may take a bit for the installer to go to the next option.
3. Click on the language you want to install, afterwards select whitch games will be installed (by default all offline games are selected), untick "learn more"'s at the end or you will get sent to a browser page
4. SInce [MUI files are not supported by Wine](https://forum.winehq.org/viewtopic.php?t=37417), all games will not load the UI correctly, and some may just not open. To solve this, you will need to fix the games' files in your `~/.wine/drive_c/Program Files/Microsoft Games` by using resource hacker.
- I tried contacting @AngusJohnson to ask how to set up a script to automate this, since I could not figure it out from the instructions on the website, but recieved no reply
5. After installing resource hacker through Wine, in the app file => open, find `chess.exe` under `My computer -> C: -> Program Files/Microsoft Games`
6. Open it, click on Action => Add from resource file
   <img width="385" height="320" alt="rh1" src="https://github.com/user-attachments/assets/71013a9a-050c-4f5f-8852-6807ae88f0d7" />
7. Select to display all files, enter the folder next to the executables, select the .MUI file
   <img width="433" height="88" alt="rh2" src="https://github.com/user-attachments/assets/48fbacf3-abeb-465a-ab48-07fecc3a7a64" />
8. Tick [overwrite], tick [check all], import, file => save
   <img width="230" height="332" alt="rh3" src="https://github.com/user-attachments/assets/ab139f92-d689-4780-b390-4fd0724d4e31" />
9. Repeat for all main .exe files n every game folder with matching .MUI's, you can also use the folder and floppy disk icons, or ctrl+o and ctrl+s for a faster experience. Full list of files to merge is:
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
10. Afterwards, you can delete all files with `_original` in their name, and the folders of the language with the .mui file
   <img width="446" height="214" alt="rh4" src="https://github.com/user-attachments/assets/8765f4b5-4a91-4b6b-9ce1-6f8971ab8048" />
Note: if wine did not create the shortcuts properly, it can be done manually by going to `.wine/drive_c/ProgramData/Microsoft/Windows/Start Menu/Programs/Games`, open a command line there, and type `wine winemenubuilder <.lnk name>` for every game you want a shortcut for.

Icons folder included in repository to make desktop shortcuts.


---

Personal note:
Wine developers, and those in general focused on its betterment, seem to love older windows versions before Vista (for exmple the inbuilt minesweeper, nd general visuals), but I am nostalgic for the windows 7 era aero style, where the inbuilt games got modern enough to not seem "vintage" but before the hellscape that is Microsoft Solitaire Collection.

Shoutout to the one [useful forum post](https://forum.winehq.org/viewtopic.php?t=37417) that gave me the begginings of solving the ui issues, since Wine cannot handle MUI files.

I am using the images from another (archived) [github guide](https://web.archive.org/web/20220914142532/https://gist.github.com/eladkarako/0c23ce1157b4c6175817c78a7adb577f), since they are very nicely edited.
