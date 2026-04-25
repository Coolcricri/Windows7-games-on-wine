#!/bin/bash

SCRIPT_START=$(date +%s)
#find file in Documents, or next to script
find_asset() {
    local pattern="$1" type="${2:-f}"
    for dir in "$HOME/Downloads" "$(dirname "$0")"; do
        for loc in "$dir"/$pattern; do
            [[ "$type" == "f" && -f "$loc" ]] && echo "$loc" && return 0
            [[ "$type" == "d" && -d "$loc" ]] && echo "$loc" && return 0
        done
    done
    return 1
}

# If not running in an interactive terminal, log all output and auto-select all choices
NON_INTERACTIVE=0
if [[ ! -t 1 ]]; then
    NON_INTERACTIVE=1
    LOG_FILE="$(dirname "$0")/install_$(date +%Y%m%d_%H%M%S).log"
    exec > "$LOG_FILE" 2>&1
    echo "Running in non-interactive mode. Log: $LOG_FILE"
fi

# Parse setup.txt for flag keywords: generate, delete, lang=<code>
SETUP_TXT=$(find_asset "setup.txt") || true
SETUP_GENERATE=0
SETUP_DELETE=0
SETUP_LANG=""
if [[ -f "$SETUP_TXT" ]]; then
    while IFS= read -r line; do
        line="${line// /}"          # strip spaces
        line="${line,,}"            # lowercase
        [[ "$line" == "generate" ]] && SETUP_GENERATE=1
        [[ "$line" == "delete"   ]] && SETUP_DELETE=1
        if [[ "$line" == lang=* ]]; then
            SETUP_LANG="${line#lang=}"
        fi
    done < "$SETUP_TXT"
fi
MISSING=0

# Search for kron4ek wine tar package
WINE_TAR=$(find_asset "wine*.tar.xz") || true

# Check system wine
SYSTEM_WINE=0
if command -v wine &>/dev/null; then
    SYSTEM_WINE=1
    SYS_WINE_VERSION=$(wine --version | grep -oP '[\d]+\.[\d]+' | head -n1)
    SYS_WINE_MAJOR=$(echo "$SYS_WINE_VERSION" | cut -d. -f1)
    if [[ "$SYS_WINE_MAJOR" -lt 11 ]]; then
        echo "WARNING: System wine $SYS_WINE_VERSION detected (minimum recommended: 11.0)." >&2
        echo "         Only Chess Titans is likely to be functional on this version." >&2
        echo "         All games will run slower due to lack of NTSYNC support." >&2
    fi
fi

# Decide which wine to use: kron4ek takes priority when tar is found
WINE_CMD="wine"
WINE_USE_KRON4EK=0
PREFIX="$HOME/.wine"

if [[ "$SYSTEM_WINE" -eq 0 && -z "$WINE_TAR" ]]; then
    echo "WARNING: No wine installation found." >&2
    MISSING=1
elif [[ -n "$WINE_TAR" ]]; then
    if [[ "$SYSTEM_WINE" -eq 1 ]]; then
        if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
            WINE_USE_KRON4EK=1
            echo "kron4ek tar found: kron4ek wine will be used over system wine."
        else
            read -rp "Both system wine $SYS_WINE_VERSION and a kron4ek tar were found. Use kron4ek? [Y/n] " KRON4EK_CHOICE
            [[ ! "$KRON4EK_CHOICE" =~ ^[Nn]$ ]] && WINE_USE_KRON4EK=1 || echo "System wine $SYS_WINE_VERSION will be used."
        fi
    else
        WINE_USE_KRON4EK=1
    fi
else
    echo "Detected system wine $SYS_WINE_VERSION will be used."
fi

# Set up kron4ek wine if chosen
if [[ "$WINE_USE_KRON4EK" -eq 1 ]]; then
    tarfile=$(basename "$WINE_TAR")
    winever="${tarfile%.tar.xz}"

    TAR_WINE_VERSION=$(echo "$winever" | grep -oP '\d+\.\d+' | head -n1)
    TAR_WINE_MAJOR=$(echo "$TAR_WINE_VERSION" | cut -d. -f1)

    if [[ -n "$TAR_WINE_MAJOR" && "$TAR_WINE_MAJOR" -lt 11 ]]; then
        echo "WARNING: kron4ek wine $TAR_WINE_VERSION detected (minimum recommended: 11.0)." >&2
        echo "         Only Chess Titans is likely to be functional on this version." >&2
        echo "         All games will run slower due to lack of NTSYNC support." >&2
    fi

    if [[ "$winever" != *wow64* ]]; then
        echo "WARNING: This kron4ek wine build does not include WOW64." >&2
        echo "         Only Chess Titans will work with this build." >&2
        if [[ "$SYSTEM_WINE" -eq 1 ]]; then
            if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
                echo "Falling back to system wine $SYS_WINE_VERSION." >&2
                WINE_USE_KRON4EK=0
            else
                echo "  b: Fall back to system wine $SYS_WINE_VERSION"
                echo "  c: Continue with this kron4ek build anyway"
                echo "  n: Abort"
                read -rp "Choice? [b/c/N] " WOW64_CHOICE
                case "${WOW64_CHOICE,,}" in
                    b) WINE_USE_KRON4EK=0; echo "Using system wine $SYS_WINE_VERSION." ;;
                    c) ;;
                    *) echo "Aborting." >&2; exit 1 ;;
                esac
            fi
        else
            if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
                echo "Aborting: WOW64 build required and no system wine fallback." >&2
                exit 1
            else
                echo "  c: Continue with this kron4ek build anyway"
                echo "  n: Abort"
                read -rp "Choice? [c/N] " WOW64_CHOICE
                [[ "${WOW64_CHOICE,,}" == "c" ]] || { echo "Aborting." >&2; exit 1; }
            fi
        fi
    fi

    if [[ "$WINE_USE_KRON4EK" -eq 1 ]]; then
        echo "Detected kron4ek wine $TAR_WINE_VERSION will be used."
        mkdir -p "$HOME/.kron4ek-wine"
        ICONS_SRC="$(dirname "$0")/icons"
        [[ -d "$ICONS_SRC" ]] && cp -a "$ICONS_SRC/." "$HOME/.kron4ek-wine/icons"
        echo "Extracting kron4ek wine..."
        tar -xf "$WINE_TAR" -C "$HOME/.kron4ek-wine/"
        mkdir -p "$HOME/.local/bin"
        cat > "$HOME/.local/bin/krowine" <<'KROWINE'
#!/bin/bash
KROWINE
        echo "env WINEPREFIX=\"\$HOME/.kron4ek-wine/wowMUIfix\" WINEDEBUG=-all \"$HOME/.kron4ek-wine/$winever/bin/wine\" \"\$@\"" \
            >> "$HOME/.local/bin/krowine"
        chmod +x "$HOME/.local/bin/krowine"
        WINE_CMD="$HOME/.local/bin/krowine"
        PREFIX="$HOME/.kron4ek-wine/wowMUIfix"
    else
        echo "Detected system wine $SYS_WINE_VERSION will be used."
    fi
fi

HAS_7Z=0
if ! command -v 7z &>/dev/null; then
    echo "WARNING: 7z is not installed. Language extraction will be unavailable." >&2
    echo "         Manual language selection will be disabled." >&2
else
    HAS_7Z=1
fi

HAS_PYTHON=0
if command python3 --version &>/dev/null; then
    HAS_PYTHON=1
else
    echo "WARNING: python3 is not installed. Log files from Resource Hacker will be garbled." >&2
fi

HAS_PETOOLS=0
if [[ "$HAS_PYTHON" -eq 1 ]]; then
    if pip show pe_tools &>/dev/null; then
        HAS_PETOOLS=1
    else
        echo "WARNING: pe_tools is not installed through pip." >&2
        if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
            read -rp "Install pe_tools via pip now? [Y/n] " PIP_CHOICE
            if [[ ! "$PIP_CHOICE" =~ ^[Nn]$ ]]; then
                if pip install pe_tools; then
                    HAS_PETOOLS=1
                else
                    echo "WARNING: pip install failed. Script generation will be unavailable." >&2
                fi
            fi
        fi
        if [[ "$HAS_PETOOLS" -eq 0 ]]; then
            echo "         Script generation disabled. Pre-existing scripts will be used." >&2
        fi
    fi
fi

# Write the reshacker script generator next to the main script
GEN_SCRIPT="$(dirname "$0")/reshacker_gen.py"
if [[ "$HAS_PETOOLS" -eq 1 ]]; then
    cat > "$GEN_SCRIPT" <<'PYEOF'
import subprocess
import sys

def get_reshack_lines(mui_path, win_game_dir, exe_name, skip_types=('MUI',)):
    result = subprocess.run(['peresed', '--print-tree', mui_path], capture_output=True, text=True)
    current_type = None
    current_name = None
    lines = []
    for line in result.stdout.splitlines():
        stripped = line.strip()
        if not stripped or stripped == 'resources:':
            continue
        depth = len(line) - len(line.lstrip())
        if depth == 2:
            current_type = stripped
        elif depth == 4:
            current_name = stripped.split(':')[0].strip()
        elif depth == 6:
            if current_type in skip_types:
                continue
            lang = stripped.split(':')[0].strip()
            type_map = {
                'RT_STRING':      'STRINGTABLE',
                'RT_MENU':        'MENU',
                'RT_DIALOG':      'DIALOG',
                'RT_ACCELERATOR': 'ACCELERATORS',
                'RT_VERSION':     'VERSIONINFO',
            }
            res_type = type_map.get(current_type, current_type)
            res_path = f"{win_game_dir}\\{exe_name}.res"
            lines.append(f'-addoverwrite "{res_path}", {res_type},{current_name},{lang}')
    return lines

if len(sys.argv) < 4:
    print("Usage: reshacker_gen.py <mui_path> <game_folder> <exe_name>", file=sys.stderr)
    sys.exit(1)

MUI_FILE  = sys.argv[1]
GAME      = sys.argv[2]
EXE_NAME  = sys.argv[3]

WIN_BASE     = r"C:\Program Files\Microsoft Games"
WIN_GAME_DIR = f"{WIN_BASE}\\{GAME}"
WIN_EXE      = f"{WIN_GAME_DIR}\\{EXE_NAME}.exe"

commands = get_reshack_lines(MUI_FILE, WIN_GAME_DIR, EXE_NAME)

print('[FILENAMES]')
print(f'Open= "{WIN_EXE}"')
print(f'SaveAs= "{WIN_EXE}"')
print(f'Log= "logs\\{EXE_NAME}-log.log"')
print('[COMMANDS]')
print('\n'.join(commands))
PYEOF
fi

GAMES_INSTALLER=$(find_asset "Windows7Games_for_Windows_11_10_8.exe") || true
if [[ -z "$GAMES_INSTALLER" ]]; then
    echo "WARNING: Windows7Games_for_Windows_11_10_8.exe not found in Downloads or next to the script." >&2
    MISSING=1
fi

RESHACKER_INSTALLER=$(find_asset "reshacker_setup.exe") || true
if [[ -z "$RESHACKER_INSTALLER" ]]; then
    echo "WARNING: reshacker_setup.exe not found in Downloads or next to the script." >&2
    MISSING=1
fi

SCRIPT_DIR="$(dirname "$0")/reshacker_scripts"

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

# Check whether pre-built reshacker scripts cover all games
HAS_SCRIPTS=0
FORCE_GENERATE=0
if [[ -d "$SCRIPT_DIR" ]]; then
    ALL_PRESENT=1
    for _GAME in "${!GAMES[@]}"; do
        IFS="|" read -r _EXE _ _ <<< "${GAMES[$_GAME]}"
        [[ ! -f "$SCRIPT_DIR/$_EXE-script.txt" ]] && ALL_PRESENT=0 && break
    done
    [[ "$ALL_PRESENT" -eq 1 ]] && HAS_SCRIPTS=1
fi
[[ "$SETUP_GENERATE" -eq 1 ]] && FORCE_GENERATE=1

# If setup.txt forces generation but pe_tools are unavailable, warn and clear the flag
if [[ "$FORCE_GENERATE" -eq 1 && "$HAS_PETOOLS" -eq 0 ]]; then
    echo "WARNING: generate requested in setup.txt but pe_tools is not available; ignoring." >&2
    FORCE_GENERATE=0
fi

if [[ "$MISSING" -eq 1 ]]; then
    echo "One or more requirements are missing. Aborting." >&2
    exit 1
fi

#Running installers silentrly or not
GAMES_DIR="$PREFIX/drive_c/Program Files/Microsoft Games"
SKIP_INSTALL=0
if [[ -f "$GAMES_DIR/unwin7games.exe" ]]; then
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        echo "Games already installed: skipping installation."
        SKIP_INSTALL=1
    else
        echo "Windows 7 Games appears to already be installed."
        echo "  u: Uninstall (run uninstaller, then delete the games folder)"
        echo "  s: Skip installation and patch already-installed games"
        echo "  n: Continue with installation anyway"
        read -rp "Choice? [u/s/N] " ALREADY_INSTALLED
        case "${ALREADY_INSTALLED,,}" in
            u)
                echo "Uninstalling existing games..."
                WINEDEBUG=-all "$WINE_CMD" "$GAMES_DIR/unwin7games.exe" /S
                wait
                echo "Deleting games folder..."
                rm -rf "$GAMES_DIR"
                echo "Done."
                exit 0
                ;;
            s)
                SKIP_INSTALL=1
                ;;
        esac
    fi
fi

if [[ "$SKIP_INSTALL" -eq 0 ]]; then
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        SILENT_CHOICE="y"
    else
        echo "Install games silently? All 8 offline games will be installed automatically."
        read -rp "Silent install? [y/N] " SILENT_CHOICE
    fi
    if [[ "$SILENT_CHOICE" =~ ^[Yy]$ ]]; then
        echo "Silent mode enabled."
        WINEDEBUG=-all "$WINE_CMD" "$GAMES_INSTALLER" /S
        wait
        WINEDEBUG=-all "$WINE_CMD" "$RESHACKER_INSTALLER" /SILENT
        wait
    else
        echo "Interactive mode:"
        echo "starting games installer, untick the [learn more] textboxes before finishing"
        WINEDEBUG=-all "$WINE_CMD" "$GAMES_INSTALLER"
        wait
        echo "installing patcher... untick the boxes before [Finish]ing for a smooth experience"
        WINEDEBUG=-all "$WINE_CMD" "$RESHACKER_INSTALLER"
        wait
    fi
else
    WINEDEBUG=-all "$WINE_CMD" "$RESHACKER_INSTALLER" /SILENT
    wait
fi
echo ""

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
RE_HACKER_LNK="$PREFIX/drive_c/ProgramData/Microsoft/Windows/Start Menu/Programs/Resource Hacker.lnk"
RE_HACKER=$(strings "$RE_HACKER_LNK" | grep -i '\\ResourceHacker\.exe' | head -n1)

#Windows path to Wine path
RE_HACKER="$PREFIX/drive_c/${RE_HACKER#?:\\}"
RE_HACKER="${RE_HACKER//\\//}"

# Fallback, default installation location
[[ ! -f "$RE_HACKER" ]] && RE_HACKER="$PREFIX/drive_c/Program Files (x86)/Resource Hacker/ResourceHacker.exe"

#Default language for scripts
DETECTED_LCID=1033
DETECTED_LANG="en-US"
LANG_FORCED=0

# Check for lang= override from setup.txt
if [[ -n "$SETUP_LANG" ]]; then
    for LANG_CODE in "${!LCID[@]}"; do
        if [[ "$SETUP_LANG" == "${LANG_CODE,,}" ]]; then
            DETECTED_LANG="$LANG_CODE"
            DETECTED_LCID="${LCID[$LANG_CODE]}"
            LANG_FORCED=1
            echo "Language overridden by setup.txt: $DETECTED_LANG (LCID: $DETECTED_LCID)"
            break
        fi
    done
    if [[ "$LANG_FORCED" -eq 0 ]]; then
        echo "WARNING: setup.txt lang= value '${SETUP_LANG}' is not a recognised language code, ignoring." >&2
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
            if [[ "$HAS_7Z" -eq 0 ]]; then
                echo "Manual language selection is disabled without 7z." >&2
            else
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
    fi

    # Extract language folders from installer if 7z is available
    if [[ "$HAS_7Z" -eq 0 ]]; then
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
    echo "Locale is en-US (1033): no script patching needed."
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

    WINEDEBUG=-all "$WINE_CMD" "$RE_HACKER" -open "$MUI_FILE" -save "$GAMES_DIR/$GAME/$EXE_NAME.res" -action extract -mask ",,," -log "logs/$EXE_NAME-extract.log"

    # Generate reshacker script if needed (no pre-built scripts, or generate forced) and pe_tools available
    if [[ "$HAS_PETOOLS" -eq 1 && ( "$HAS_SCRIPTS" -eq 0 || "$FORCE_GENERATE" -eq 1 ) ]]; then
        python3 "$GEN_SCRIPT" "$MUI_FILE" "$GAME" "$EXE_NAME" > "$SCRIPT_DIR/$EXE_NAME-script.txt"
    fi

    WINEDEBUG=-all "$WINE_CMD" "$RE_HACKER" -script "$SCRIPT_DIR/$EXE_NAME-script.txt"
#clean that log
    LOG_DIR="$(dirname "$0")/logs"

    clean_log() {
        local log_file="$1"
        if [[ "$HAS_PYTHON" -eq 1 && -f "$log_file" ]]; then
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
Exec="$WINE_CMD" '$GAMES_DIR/$GAME/$EXE_NAME.exe'
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
if [[ "$NON_INTERACTIVE" -eq 1 || "$SETUP_DELETE" -eq 1 ]]; then
    CLEANUP="y"
else
    echo "Cleanup options:"
    echo "  y : Remove .mui folders, temporary files, and uninstall Resource Hacker"
    echo "  p : Remove .mui folders and temporary files only (keep Resource Hacker)"
    echo "  n : Skip cleanup"
    read -rp "Choice? [y/p/N] " CLEANUP
fi

if [[ "$CLEANUP" =~ ^[YyPp]$ ]]; then
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
        RESHACKER_DIR="$PREFIX/drive_c/Program Files (x86)/Resource Hacker"
        UNINSTALLER=$(find "$RESHACKER_DIR" -maxdepth 1 -name "unins*.exe" 2>/dev/null | head -n1)
        if [[ -n "$UNINSTALLER" ]]; then
            WINEDEBUG=-all "$WINE_CMD" "$UNINSTALLER" /SILENT 2>/dev/null
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
        echo "No Wine menu shortcuts to remove."
    fi
fi

echo "Done."
