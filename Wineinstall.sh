#!/bin/bash
SCRIPT_START=$(date +%s)
#+ if not running in a command line, create a log file where normal echo output is routed, choose silent mode, detected language unless .txt file is found (see line 107 first), and delete all useless files

# If not running in an interactive terminal, log all output and auto-select all choices
NON_INTERACTIVE=0
if [[ ! -t 1 ]]; then
    NON_INTERACTIVE=1
    LOG_FILE="$(dirname "$0")/install_$(date +%Y%m%d_%H%M%S).log"
    exec > "$LOG_FILE" 2>&1
    echo "Running in non-interactive mode. Log: $LOG_FILE"
fi
# Cheking if requirenemts are met
MISSING=0
if ! command wine --version &>/dev/null; then
    echo "WARNING: wine is not installed as a system package." >&2
    MISSING=1
else
    WINE_VERSION=$(wine --version | grep -oP '[\d]+\.[\d]+' | head -n1)
    WINE_MAJOR=$(echo "$WINE_VERSION" | cut -d. -f1)
    WINE_MINOR=$(echo "$WINE_VERSION" | cut -d. -f2)
    if [[ "$WINE_MAJOR" -lt 11 ]] || { [[ "$WINE_MAJOR" -eq 11 ]] && [[ "$WINE_MINOR" -lt 0 ]]; }; then
        echo "WARNING: Wine $WINE_VERSION detected (minimum recommended: 11.0)." >&2
        echo "         Only Chess Titans is likely to be functional on this version." >&2
        echo "         All games will run slower due to lack of NTSYNC support." >&2
    fi
fi

GAMES_INSTALLER=""
for loc in "$HOME/Downloads/Windows7Games_for_Windows_11_10_8.exe" "$(dirname "$0")/Windows7Games_for_Windows_11_10_8.exe"; do
    [[ -f "$loc" ]] && GAMES_INSTALLER="$loc" && break
done
if [[ -z "$GAMES_INSTALLER" ]]; then
    echo "WARNING: Windows7Games_for_Windows_11_10_8.exe not found in Downloads or next to the script." >&2
    MISSING=1
fi

RESHACKER_INSTALLER=""
for loc in "$HOME/Downloads/reshacker_setup.exe" "$(dirname "$0")/reshacker_setup.exe"; do
    [[ -f "$loc" ]] && RESHACKER_INSTALLER="$loc" && break
done
if [[ -z "$RESHACKER_INSTALLER" ]]; then
    echo "WARNING: reshacker_setup.exe not found in Downloads or next to the script." >&2
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

#Running installers silently or not
GAMES_DIR="$HOME/.wine/drive_c/Program Files/Microsoft Games"
if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    SILENT_CHOICE="y"
else
    echo "Install games silently? All 8 offline games will be installed automatically."
    read -rp "Silent install? [y/N] " SILENT_CHOICE
fi

if [[ "$SILENT_CHOICE" =~ ^[Yy]$ ]]; then
    echo "Silent mode enabled. 8 offline games and Resource hacker will be installed"
    WINEDEBUG=-all wine "$GAMES_INSTALLER" /S
    wait
    WINEDEBUG=-all wine "$RESHACKER_INSTALLER" /SILENT
    wait
else
    echo "Interactive mode:"
    echo "starting games installer, untick the [learn more] textboxes before finishing"
    WINEDEBUG=-all wine "$GAMES_INSTALLER"
    wait
    echo "installing patcher... untick the boxes before [Finish]ing for a smooth experience"
    WINEDEBUG=-all wine "$RESHACKER_INSTALLER"
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
LANG_FORCED=0
# Check for lang.txt override next to the script
LANG_TXT="$(dirname "$0")/lang.txt"
if [[ -f "$LANG_TXT" ]]; then
    LANG_TXT_VALUE=$(head -n1 "$LANG_TXT" | tr -d '[:space:]')
    for LANG_CODE in "${!LCID[@]}"; do
        if [[ "${LANG_TXT_VALUE,,}" == "${LANG_CODE,,}" ]]; then
            DETECTED_LANG="$LANG_CODE"
            DETECTED_LCID="${LCID[$LANG_CODE]}"
            LANG_FORCED=1
            echo "Language overridden by lang.txt: $DETECTED_LANG (LCID: $DETECTED_LCID)"
            break
        fi
    done
    if [[ "$LANG_FORCED" -eq 0 ]]; then
        echo "WARNING: lang.txt found but '${LANG_TXT_VALUE}' is not a recognised language code, ignoring." >&2
    fi
fi

#Language code detected by folder name of the .mui files
if [[ "$LANG_FORCED" -eq 0 ]]; then
    for LANG_CODE in "${!LCID[@]}"; do
        if find "$GAMES_DIR" -maxdepth 2 -type d -name "$LANG_CODE" -print -quit | grep -q .; then
            DETECTED_LCID="${LCID[$LANG_CODE]}"
            DETECTED_LANG="$LANG_CODE"
            break
        fi
    done
fi


#Modifies scripts if language is not english-US
if [[ "$DETECTED_LCID" -ne 1033 ]]; then

    if [[ "$LANG_FORCED" -eq 1 || "$NON_INTERACTIVE" -eq 1 ]]; then
        echo "Using language: $DETECTED_LANG (LCID: $DETECTED_LCID)"
    else
        # Ask if the detected language is the one the user wants
        echo "Detected installed language: $DETECTED_LANG (LCID: $DETECTED_LCID)"
        read -rp "Use this language for patching? [Y/n] " LANG_CONFIRM
        if [[ "$LANG_CONFIRM" =~ ^[Nn]$ ]]; then
            echo "Available languages:"
            IFS=$'\n' SORTED_LANGS=($(printf '%s\n' "${!LCID[@]}" | sort)); unset IFS
            select CHOSEN_LANG in "${SORTED_LANGS[@]}"; do
                if [[ -n "$CHOSEN_LANG" ]]; then
                    DETECTED_LANG="$CHOSEN_LANG"
                    DETECTED_LCID="${LCID[$CHOSEN_LANG]}"
                    echo "Selected: $DETECTED_LANG (LCID: $DETECTED_LCID)"
                    break
                else
                    echo "Invalid selection, please try again."
                fi
            done
        fi
    fi

    # Check if 7z is available for extracting language folders from the installer
    if ! command -v 7z &>/dev/null; then
        echo "WARNING: 7z is not installed. Cannot extract additional language files from the installer." >&2
        echo "         Only the already-installed language ($DETECTED_LANG) will be available." >&2
    else
        echo "Extracting $DETECTED_LANG language files from installer..."
        for GAME in "${!GAMES[@]}"; do
            IFS="|" read -r EXE_NAME DESKTOP_NAME ICON_NAME <<< "${GAMES[$GAME]}"
            GAME_DIR="$GAMES_DIR/$GAME"

            if [[ ! -d "$GAME_DIR" ]]; then
                echo "  $DESKTOP_NAME install folder not found, skipping language extraction..."
                continue
            fi

            # Extract any paths containing the target language folder into the game's directory.
            # The installer is a self-extracting archive; paths inside follow the game folder structure.
            TMPDIR_LANG=$(mktemp -d)
            if 7z e "$GAMES_INSTALLER" -ir!"${GAME}/${DETECTED_LANG}/*" -o"$TMPDIR_LANG" -y &>/dev/null; then
                if [[ -n "$(ls -A "$TMPDIR_LANG" 2>/dev/null)" ]]; then
                    mkdir -p "$GAME_DIR/$DETECTED_LANG"
                    cp -r "$TMPDIR_LANG/." "$GAME_DIR/$DETECTED_LANG/"
                    echo "  Extracted $DETECTED_LANG files for $DESKTOP_NAME."
                else
                    echo "  No $DETECTED_LANG files found in installer for $DESKTOP_NAME."
                fi
            else
                echo "  Could not extract $DETECTED_LANG files for $DESKTOP_NAME."
            fi
            rm -rf "$TMPDIR_LANG"
        done
    fi

    echo "Patching reshacker scripts for locale $DETECTED_LANG (LCID: $DETECTED_LCID)..."
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
echo ""
if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    CLEANUP="y"
else
    echo "Cleanup options:"
    echo "  y: Remove .mui folders, temporary files, and uninstall Resource Hacker"
    echo "  p: Remove .mui folders and temporary files only (keep Resource Hacker)"
    echo "  n: No cleanup"
    read -rp "Choice? [y/p/N] " CLEANUP
fi


if [[ "$CLEANUP" =~ ^[YyPp]$ ]]; then
    #echo "Removing installers..."
    #rm -f "$HOME/Downloads/Windows7Games_for_Windows_11_10_8.exe"
    #rm -f "$HOME/Downloads/reshacker_setup.exe"

    echo "Removing .mui folders..."
    find "$GAMES_DIR" -type f -name "*.mui" -exec dirname {} \; | sort -u | while read -r dir; do
        echo "  Deleting: $dir"
        rm -rf "$dir"
    done

    echo "Removing leftover .png and .res files from game folders..."
    find "$GAMES_DIR" -maxdepth 2 -type f -name "*.png" -delete
    find "$GAMES_DIR" -maxdepth 2 -type f -name "*.res" -delete

    if [[ "$CLEANUP" =~ ^[Yy]$ ]]; then
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
    else
        echo "Skipping Resource Hacker uninstall."
    fi

    echo "Cleanup complete."
fi

# Remove any shortcuts Wine created in its programs menu during this session
WINE_GAMES_MENU="$HOME/.local/share/applications/wine/Programs/Games"
if [[ -d "$WINE_GAMES_MENU" ]]; then
    REF_FILE=$(mktemp)
    touch -d "@$SCRIPT_START" "$REF_FILE" 2>/dev/null || touch -t "$(date -d @"$SCRIPT_START" +%Y%m%d%H%M.%S)" "$REF_FILE"
    mapfile -d '' NEW_SHORTCUTS < <(find "$WINE_GAMES_MENU" -maxdepth 1 -type f -newer "$REF_FILE" -print0)
    rm -f "$REF_FILE"
    if [[ "${#NEW_SHORTCUTS[@]}" -gt 0 ]]; then
        for SHORTCUT in "${NEW_SHORTCUTS[@]}"; do
            rm -f "$SHORTCUT"
        done
        echo "Removed Wine-generated menu shortcuts."
    else
        echo "No Wine-generated menu shortcuts to remove."
    fi
fi

echo "Done."
