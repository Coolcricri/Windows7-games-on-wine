#!/bin/bash

# Cheking if requirenemts are met
MISSING=0
if ! command wine --version &>/dev/null; then
    echo "WARNING: wine is not installed as a system package." >&2
    MISSING=1
fi

if [[ ! -f "$HOME/Downloads/Windows7Games_for_Windows_11_10_8.exe" ]]; then
    echo "WARNING: Windows7Games_for_Windows_11_10_8.exe not found in Downloads." >&2
    MISSING=1
fi

if [[ ! -f "$HOME/Downloads/reshacker_setup.exe" ]]; then
    echo "WARNING: reshacker_setup.exe not found in Downloads." >&2
    MISSING=1
fi
SCRIPT_DIR="$(dirname "$0")/reshacker_scripts"
if [[ ! -d "$SCRIPT_DIR" ]]; then
    echo "WARNING: reshacker_scripts folder not found next to the script." >&2
    MISSING=1
fi
if [[ "$MISSING" -eq 1 ]]; then
    echo "One or more requirements are missing. Aborting." >&2
    exit 1
fi

#Running installers silentrly or not
GAMES_DIR="$HOME/.wine/drive_c/Program Files/Microsoft Games"
echo "Install games silently? All 8 offline games will be installed automatically."
read -rp "Silent install? [y/N] " SILENT_CHOICE
if [[ "$SILENT_CHOICE" =~ ^[Yy]$ ]]; then
    echo "Silent mode enabled."
    WINEDEBUG=-all wine "$HOME/Downloads/Windows7Games_for_Windows_11_10_8.exe" /S
    wait
    WINEDEBUG=-all wine "$HOME/Downloads/reshacker_setup.exe" /SILENT
    wait
else
    echo "Interactive mode:"
    echo "starting games installer, untick the [learn more] textboxes before finishing"
    WINEDEBUG=-all wine "$HOME/Downloads/Windows7Games_for_Windows_11_10_8.exe"
    wait
    echo "installing patcher... untick the boxes before [Finish]ing for a smooth experience"
    WINEDEBUG=-all wine "$HOME/Downloads/reshacker_setup.exe"
    wait
fi
echo ""

#Table of: Folder_name = exe_name|display_name|icon_name (when installed by wine)
declare -A GAMES=(
    ["Chess"]="chess|Chess Titans|74F7_chess.0"
    ["FreeCell"]="FreeCell|FreeCell|585B_FreeCell.0"
    ["Hearts"]="Hearts|Hearts|B17D_Hearts.0"
    ["Mahjong"]="Mahjong|Mahjong Titans|BD78_Mahjong.0"
    ["Minesweeper"]="Minesweeper|Minesweeper|5687_Minesweeper.0"
    ["Purble Place"]="PurblePlace|Purble Place|ED83_PurblePlace.0"
    ["Solitaire"]="Solitaire|Solitaire|468A_Solitaire.0"
    ["SpiderSolitaire"]="SpiderSolitaire|Spider Solitaire|D17D_SpiderSolitaire.0"
)

#All languages supported by the installer, and their codes
declare -A LCID=(
    ["ar-SA"]=1025   ["bg-BG"]=1026   ["cs-CZ"]=1029   ["da-DK"]=1030
    ["de-DE"]=1031   ["el-GR"]=1032   ["en-US"]=1033   ["es-ES"]=3082
    ["et-EE"]=1061   ["fi-FI"]=1035   ["fr-FR"]=1036   ["he-IL"]=1037
    ["hr-HR"]=1050   ["hu-HU"]=1038   ["it-IT"]=1040   ["ja-JP"]=1041
    ["ko-KR"]=1042   ["lt-LT"]=1063   ["lv-LV"]=1062   ["nb-NO"]=1044
    ["nl-NL"]=1043   ["pl-PL"]=1045   ["pt-BR"]=1046   ["pt-PT"]=2070
    ["ro-RO"]=1048   ["ru-RU"]=1049   ["sk-SK"]=1051   ["sl-SI"]=1060
    ["sr-Latn-CS"]=2074 ["sv-SE"]=1053 ["th-TH"]=1054  ["tr-TR"]=1055
    ["uk-UA"]=1058   ["zh-CN"]=2052   ["zh-TW"]=1028
)

#Manual installer allows Resource Hacker to  be installed anywhere, but .lnk in the start menu always points to it, so no need to force it to be installed in one place
RE_HACKER_LNK="$HOME/.wine/drive_c/ProgramData/Microsoft/Windows/Start Menu/Programs/Resource Hacker.lnk"
RE_HACKER=$(strings "$RE_HACKER_LNK" | grep -i '\\ResourceHacker\.exe' | head -n1)

#Windows path to Wine path
RE_HACKER="$HOME/.wine/drive_c/${RE_HACKER#?:\\}"
RE_HACKER="${RE_HACKER//\\//}"

# Fallback, default installation location
[[ ! -f "$RE_HACKER" ]] && RE_HACKER="$HOME/.wine/drive_c/Program Files (x86)/Resource Hacker/ResourceHacker.exe"

#Default language for scripts
DETECTED_LCID=1033
DETECTED_LANG="en-US"

#Language code detected by folder name of the .mui files
for LANG_CODE in "${!LCID[@]}"; do
    if find "$GAMES_DIR" -maxdepth 2 -type d -name "$LANG_CODE" -print -quit | grep -q .; then
        DETECTED_LCID="${LCID[$LANG_CODE]}"
        DETECTED_LANG="$LANG_CODE"
        break
    fi
done

#Modifies scripts if language is not english-US
if [[ "$DETECTED_LCID" -ne 1033 ]]; then
    echo "Detected locale LCID: $DETECTED_LCID — patching reshacker scripts..."
    while IFS= read -r -d '' script_file; do
        sed -i "s/1033/$DETECTED_LCID/g" "$script_file"
        sed -i "s/en-US/$DETECTED_LANG/g" "$script_file"
    done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name "*.txt" -print0)
else
    echo "Locale is en-US (1033) — no script patching needed."
fi
#just in case
mkdir -p "$HOME/.local/share/applications"

#The main games patching loop
for GAME in "${!GAMES[@]}"; do
    IFS="|" read -r EXE_NAME DESKTOP_NAME ICON_NAME <<< "${GAMES[$GAME]}"

    if [[ ! -f "$GAMES_DIR/$GAME/$EXE_NAME.exe" ]]; then
        echo "$DESKTOP_NAME not installed, skipping..."
        continue
    fi
    echo "Processing $DESKTOP_NAME..."

    # Find MUI file
    MUI_FILE=$(find "$GAMES_DIR/$GAME" -type f -name "*.mui" | head -n 1)

    if [[ ! -f "$MUI_FILE" ]]; then
        echo "No MUI file found for $DESKTOP_NAME, skipping..."
        continue
    fi

    WINEDEBUG=-all wine "$RE_HACKER" -open "$MUI_FILE" -save "$GAMES_DIR/$GAME/$EXE_NAME.res" -action extract -mask ",,," -log "logs/$EXE_NAME-extract.log"

    WINEDEBUG=-all wine "$RE_HACKER" -script "./reshacker_scripts/$EXE_NAME-script.txt"
#clean that log
    LOG_DIR="$(dirname "$0")/logs"

    clean_log() {
        local log_file="$1"
        if [[ -f "$log_file" ]]; then
            python3 -c "
import sys
path = sys.argv[1]
data = open(path, 'rb').read()
open(path, 'wb').write(data[::2])
" "$log_file"
        fi
    }
    clean_log "$LOG_DIR/${EXE_NAME}-log.log"
    clean_log "$LOG_DIR/${EXE_NAME}-extract.log"
#create desktop shortcut, copy to menu
    cat > "$HOME/Desktop/${GAME// /_}.desktop" <<EOF
[Desktop Entry]
Name=$DESKTOP_NAME
Exec=wine '$GAMES_DIR/$GAME/$EXE_NAME.exe'
Type=Application
StartupNotify=true
Icon=$ICON_NAME
Categories=Game;
Terminal=false
EOF

    chmod +x "$HOME/Desktop/${GAME// /_}.desktop"
    cp "$HOME/Desktop/${GAME// /_}.desktop" "$HOME/.local/share/applications/"
done

#Cleanup stage
read -rp "Clean up installers, temporary files, and uninstall Resource Hacker? [y/N] " CLEANUP
if [[ "$CLEANUP" =~ ^[Yy]$ ]]; then
    #echo "Removing installers..."
    #rm -f "$HOME/Downloads/Windows7Games_for_Windows_11_10_8.exe"
    #rm -f "$HOME/Downloads/reshacker_setup.exe"

    echo "Removing .mui folders..."
    find "$GAMES_DIR" -type f -name "*.mui" -exec dirname {} \; | sort -u | while read -r dir; do
        echo "  Deleting: $dir"
        rm -rf "$dir"
    done

    echo "Uninstalling Resource Hacker..."
    RESHACKER_DIR="$HOME/.wine/drive_c/Program Files (x86)/Resource Hacker"
    UNINSTALLER=$(find "$RESHACKER_DIR" -maxdepth 1 -name "unins*.exe" 2>/dev/null | head -n1)
    if [[ -n "$UNINSTALLER" ]]; then
        WINEDEBUG=-all wine "$UNINSTALLER" /SILENT 2>/dev/null
    else
        rm -rf "$RESHACKER_DIR"
    fi
    rm -f "$RE_HACKER_LNK"

    if [[ -d "$RESHACKER_DIR" ]]; then
        echo "Removing leftover Resource Hacker files..."
        rm -rf "$RESHACKER_DIR"
    fi

    echo "Removing leftover .png and .res files from game folders..."
    find "$GAMES_DIR" -maxdepth 2 -type f -name "*.png" -delete
    find "$GAMES_DIR" -maxdepth 2 -type f -name "*.res" -delete

    echo "Cleanup complete."
fi
echo "Done."
