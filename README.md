# Windows 7 games on Wine
This is a guide to show how to get classic windows 7 games working through WINE (only tested on linux mint)
(do screenshots in a VM)
"wine loves older win versions, even got minesweeper, but I am nostalgic for the windows 7 games, just before enshittification and levels connected to microsoft store. Chess is 64bit, rest are 32bit, since wine 11 both work withut need sepaarte prefixes
1. get win7 games installer from Aero, it has dependancies installed + language
2. Execute with wine, Though to get sound working (even if not completely well), get kron4ek build, more later
3. click on language you want, it might take a while to load next part, install what u want, untick learn ore's or u get sent to browser pages
4. Due to MUI files not supported by wine, games will not work correctly, or at all. Solve this by editing files in cdrive-wingames (or download stuff in repo under fixedwingames, then delete og folder and replace it with this)
5. If want replicability or unsure of safety, download and install resource hacker, open, find chess.exe and folder next to it, click on import thing, merge, [remember settings] done, delete old exe and mui, do the same where mui name matched exe or dll, full list is: ..................
6. Done! if importing old saves, they located in ............, otherwise sound may not work in all but chess, but with kron4ek it works, after downloading it, put it in a folder, use my shell file if u want, include shortcuts and folder of icons [check if icons are in system with only kron4ek]
