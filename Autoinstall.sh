#!/bin/bash
SCRIPT_START=$(date +%s)
# Unified helper: find a file or folder by name/glob in Downloads or next to the script
# Usage: find_asset <name_or_glob> [f|d]  — prints the path and returns 0 on success
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
LOG_FILE="$(dirname "$0")/install_$(date +%Y%m%d_%H%M%S).log"
if [[ ! -t 1 ]]; then
    NON_INTERACTIVE=1
    exec > "$LOG_FILE" 2>&1
    echo "Running in non-interactive mode. Log: $LOG_FILE"
fi
#Table of: Folder_name = exe_name|display_name|icon_name (when installed by wine)
declare -A GAMES=(
    ["Chess"]="chess|Chess Titans|74F7"
    ["FreeCell"]="FreeCell|FreeCell|585B"
    ["Hearts"]="Hearts|Hearts|B17D"
    ["Mahjong"]="Mahjong|Mahjong Titans|BD78"
    ["Minesweeper"]="Minesweeper|Minesweeper|5687"
    ["Purble Place"]="PurblePlace|Purble Place|ED83"
    ["Solitaire"]="Solitaire|Solitaire|468A"
    ["SpiderSolitaire"]="SpiderSolitaire|Spider Solitaire|D17D"
)
#All languages supported by the installer, and their codes for the reshacker scripts
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
# Parse setup.txt for keywords: generate, clean-all, clean-keep, <lang-code>
SETUP_TXT=$(find_asset "setup.txt") || true
SETUP_GENERATE=0
SETUP_LANG=""
SETUP_CLEANUP=""
if [[ -n "$SETUP_TXT" ]]; then
    echo "setup.txt detected: $SETUP_TXT"
    while IFS= read -r line; do
        line="${line// /}"          # strip spaces
        [[ -z "$line" || "$line" == \#* ]] && continue
        lower="${line,,}"
        if [[ "$lower" == "generate" ]]; then
            SETUP_GENERATE=1
            echo "  setup.txt: generate -> script regeneration forced"
        elif [[ "$lower" == "clean-all" ]]; then
            SETUP_CLEANUP="y"
            echo "  setup.txt: clean-all -> cleanup will remove temp files and uninstall Resource Hacker"
        elif [[ "$lower" == "clean-keep" ]]; then
            SETUP_CLEANUP="r"
            echo "  setup.txt: clean-keep -> cleanup will remove temp files, but keep Resource Hacker"
        else
            # Check if line matches a known language code (case-insensitive)
            MATCHED_LANG=""
            for LANG_CODE in "${!LCID[@]}"; do
                if [[ "$lower" == "${LANG_CODE,,}" ]]; then
                    MATCHED_LANG="$LANG_CODE"
                    break
                fi
            done
            if [[ -n "$MATCHED_LANG" ]]; then
                SETUP_LANG="$MATCHED_LANG"
                echo "  setup.txt: $SETUP_LANG -> language use forced"
            else
                echo "  setup.txt: unrecognised entry '$line', ignoring" >&2
            fi
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
# Decide which wine to use, kron4ek is default when tar is found
WINE_CMD="wine"
WINE_USE_KRON4EK=0
PREFIX="$HOME/.wine"
# system or kron4ek wine tree: if both found choose, if one found select, if none found error and exit
if [[ "$SYSTEM_WINE" -eq 0 && -z "$WINE_TAR" ]]; then
    echo "WARNING: No wine installation found." >&2
    MISSING=1
elif [[ -n "$WINE_TAR" ]]; then
    if [[ "$SYSTEM_WINE" -eq 1 ]]; then
        if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
            WINE_USE_KRON4EK=1
            echo "kron4ek tar found: kron4ek wine will be used over system wine."
        else
            read -rp "Both system wine $SYS_WINE_VERSION and kron4ek tar were found. Use kron4ek? [Y/n] " KRON4EK_CHOICE
            [[ ! "$KRON4EK_CHOICE" =~ ^[Nn]$ ]] && WINE_USE_KRON4EK=1 || echo "System wine $SYS_WINE_VERSION will be used."
        fi
    else
        WINE_USE_KRON4EK=1
    fi
else
    echo "Detected system wine $SYS_WINE_VERSION will be used."
fi
# Set up kron4ek wine if selected
if [[ "$WINE_USE_KRON4EK" -eq 1 ]]; then
    tarfile=$(basename "$WINE_TAR")
    winever="${tarfile%.tar.xz}"
    TAR_WINE_VERSION=$(echo "$winever" | grep -oP '\d+\.\d+' | head -n1)
    TAR_WINE_MAJOR=$(echo "$TAR_WINE_VERSION" | cut -d. -f1)
    #version warnings tree
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
#kron4ek tar extract, set up .kron4ek location, make "krowine" sript shortcut, use to start directly in separate prefix with kron4ek-wine
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
#check 7zip availability, only needed for manual language selection (extracts from installer directly)
HAS_7Z=0
if ! command -v 7z &>/dev/null; then
    echo "WARNING: 7z is not installed. Manual language selection will be disabled." >&2
else
    HAS_7Z=1
fi
GAMES_DIR="$PREFIX/drive_c/Program Files/Microsoft Games"
#Running installers silently or not
SKIP_INSTALL=0
if [[ -f "$GAMES_DIR/unwin7games.exe" ]]; then
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        echo "Games already installed, skipping installation..."
        SKIP_INSTALL=1
    else
        echo "Windows 7 Games detected to already be installed."
        echo "  u: Uninstall and quit (run uninstaller, delete games folder)"
        echo "  d: Uninstall and quit, also delete desktop and menu shortcuts"
        echo "  s: Skip installation and patch already-installed games"
        echo "  n: Continue with installation anyway"
        read -rp "Choice? [u/d/s/N] " ALREADY_INSTALLED
        case "${ALREADY_INSTALLED,,}" in
            u|d)
                echo "Uninstalling existing games..."
                if [[ "$WINE_USE_KRON4EK" -eq 1 ]]; then
                    echo "Deleting kron4ek wine folder..."
                    rm -rf "$HOME/.kron4ek-wine"
                else
                    WINEDEBUG=-all "$WINE_CMD" "$GAMES_DIR/unwin7games.exe" /S
                    wait
                    echo "Deleting games folder..."
                    rm -rf "$GAMES_DIR"
                fi
                if [[ "${ALREADY_INSTALLED,,}" == "d" ]]; then
                    echo "Removing game shortcuts..."
                    for _GAME in "${!GAMES[@]}"; do
                        IFS="|" read -r _EXE _DISPLAY _ <<< "${GAMES[$_GAME]}"
                        rm -f "$HOME/Desktop/${_GAME// /_}.desktop"
                        rm -f "$HOME/.local/share/applications/${_GAME// /_}.desktop"
                    done
                fi
                echo "Done."
                exit 0
                ;;
            s)
                SKIP_INSTALL=1
                ;;
        esac
    fi
fi
#check file availability
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

if [[ "$MISSING" -eq 1 ]]; then
    echo "One or more requirements are missing. Aborting." >&2
    exit 1
fi
# Check whether pre-built reshacker scripts cover all games
BASE_SCRIPT_DIR="$(dirname "$0")/reshacker_scripts"
SCRIPT_DIR="$BASE_SCRIPT_DIR"
HAS_SCRIPTS=0
FORCE_GENERATE=0
if [[ -d "$BASE_SCRIPT_DIR" ]]; then
    ALL_PRESENT=1
    for _GAME in "${!GAMES[@]}"; do
        IFS="|" read -r _EXE _ _ <<< "${GAMES[$_GAME]}"
        [[ ! -f "$BASE_SCRIPT_DIR/$_EXE-script.txt" ]] && ALL_PRESENT=0 && break
    done
    [[ "$ALL_PRESENT" -eq 1 ]] && HAS_SCRIPTS=1
fi
[[ "$SETUP_GENERATE" -eq 1 ]] && FORCE_GENERATE=1
# Ask whether to use existing scripts or generate, then check pe_tools only if needed
if [[ "$HAS_SCRIPTS" -eq 1 && "$NON_INTERACTIVE" -eq 0 && "$FORCE_GENERATE" -eq 0 ]]; then
    echo "Pre-built reshacker scripts found."
    read -rp "Use existing scripts or regenerate? [u/g, default: u] " SCRIPT_CHOICE
    [[ "${SCRIPT_CHOICE,,}" == "g" ]] && FORCE_GENERATE=1
elif [[ "$HAS_SCRIPTS" -eq 0 && "$FORCE_GENERATE" -eq 0 ]]; then
    echo "WARNING: No reshacker scripts found in reshacker_scripts/." >&2
    if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
        echo "Scripts can be generated automatically using pe_tools."
        read -rp "Generate scripts now? [Y/n] " GEN_CHOICE
        [[ ! "$GEN_CHOICE" =~ ^[Nn]$ ]] && FORCE_GENERATE=1
    fi
fi
[[ "$SETUP_GENERATE" -eq 1 ]] && echo "Script generation option overridden by setup.txt, regenerating."
#python script generation, check if python3 is installed
HAS_PYTHON=0
HAS_PETOOLS=0
GEN_SCRIPT="$(dirname "$0")/gen_reshacker_script.py"
if [[ "$HAS_SCRIPTS" -eq 0 || "$FORCE_GENERATE" -eq 1 ]]; then
    if command -v python3 &>/dev/null; then
        HAS_PYTHON=1
    else
        echo "WARNING: python3 is not installed. Log files from Resource Hacker will be garbled." >&2
    fi
#see if pe_tools it installed with pip, prompt to install it or warn that manual language selection will be unavailable
    if [[ "$HAS_PYTHON" -eq 1 ]]; then
        if pip show pe_tools &>/dev/null; then
            HAS_PETOOLS=1
            PERESED=$(python3 -c "import sysconfig; print(sysconfig.get_path('scripts', 'posix_user'))")/peresed
        else
            echo "WARNING: pe_tools is not installed." >&2
            if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
                read -rp "Install pe_tools via pip now? [Y/n] " PIP_CHOICE
                if [[ ! "$PIP_CHOICE" =~ ^[Nn]$ ]]; then
                    if pip install pe_tools --break-system-packages; then
                        HAS_PETOOLS=1
                        PERESED=$(python3 -c "import sysconfig; print(sysconfig.get_path('scripts', 'posix_user'))")/peresed
                    else
                        echo "WARNING: pip install failed. Script generation will be unavailable." >&2
                    fi
                fi
            fi
            if [[ "$HAS_PETOOLS" -eq 0 ]]; then
                if [[ "$HAS_SCRIPTS" -eq 0 ]]; then
                    echo "ERROR: No scripts found and pe_tools could not be installed." >&2
                    echo "       Either install pe_tools (pip install pe_tools) or place pre-built" >&2
                    echo "       scripts in a reshacker_scripts/ folder next to the script." >&2
                    exit 1
                fi
                echo "         Script generation disabled. Pre-existing scripts will be used." >&2
                FORCE_GENERATE=0
            fi
        fi
    else
        FORCE_GENERATE=0
    fi
#create python script, reusable
    if [[ "$HAS_PETOOLS" -eq 1 ]]; then
        cat > "$GEN_SCRIPT" <<'PYEOF'
import subprocess
import sys

def get_reshack_lines(mui_path, win_game_dir, exe_name, peresed, skip_types=('MUI',)):
    result = subprocess.run([peresed, '--print-tree', mui_path], capture_output=True, text=True)
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

if len(sys.argv) < 5:
    print("Usage: gen_reshacker_script.py <mui_path> <game_folder> <exe_name> <peresed_path>", file=sys.stderr)
    sys.exit(1)

MUI_FILE  = sys.argv[1]
GAME      = sys.argv[2]
EXE_NAME  = sys.argv[3]
PERESED   = sys.argv[4]

WIN_BASE     = r"C:\Program Files\Microsoft Games"
WIN_GAME_DIR = f"{WIN_BASE}\\{GAME}"
WIN_EXE      = f"{WIN_GAME_DIR}\\{EXE_NAME}.exe"

commands = get_reshack_lines(MUI_FILE, WIN_GAME_DIR, EXE_NAME, PERESED)

print('[FILENAMES]')
print(f'Open= "{WIN_EXE}"')
print(f'SaveAs= "{WIN_EXE}"')
print(f'Log= "logs\\{EXE_NAME}-log.log"')
print('[COMMANDS]')
print('\n'.join(commands))
PYEOF
    fi
fi
# setup.txt generate overrides pe_tools gate only if pe_tools is available
if [[ "$SETUP_GENERATE" -eq 1 && "$HAS_PETOOLS" -eq 0 ]]; then
    echo "WARNING: generate requested in setup.txt but pe_tools is not available; ignoring." >&2
fi
#installation of installers, silent or otherwise
if [[ "$SKIP_INSTALL" -eq 0 ]]; then
    SILENT_INSTALL=0
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        SILENT_CHOICE="y"
    else
        echo "Install games silently? All 8 offline games will be installed automatically."
        read -rp "Silent install? [Y/n] " SILENT_CHOICE
    fi
    if [[ ! "$SILENT_CHOICE" =~ ^[Nn]$ ]]; then
        SILENT_INSTALL=1
        echo "Silent mode enabled. Installing games..."
        WINEDEBUG=-all "$WINE_CMD" "$GAMES_INSTALLER" /S
        wait
        echo "Games installed."
        echo "Installing Resource Hacker..."
        WINEDEBUG=-all "$WINE_CMD" "$RESHACKER_INSTALLER" /SILENT
        wait
        echo "Resource Hacker installed."
    else
        SILENT_INSTALL=0
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
#Manual installer allows Resource Hacker to  be installed anywhere, but .lnk in the start menu always points to it, so no need to force it to be installed in one place
RE_HACKER_LNK="$PREFIX/drive_c/ProgramData/Microsoft/Windows/Start Menu/Programs/Resource Hacker.lnk"
RE_HACKER=$(strings "$RE_HACKER_LNK" | grep -i '\\ResourceHacker\.exe' | head -n1)
RE_HACKER="$PREFIX/drive_c/${RE_HACKER#?:\\}"
RE_HACKER="${RE_HACKER//\\//}"
# Fallback, default installation location
[[ ! -f "$RE_HACKER" ]] && RE_HACKER="$PREFIX/drive_c/Program Files (x86)/Resource Hacker/ResourceHacker.exe"
#Default language for scripts
LCID_USED=1033
LANG_USED="en-US"
LANG_FORCED=0
# Check for language code override from setup.txt
if [[ -n "$SETUP_LANG" ]]; then
    LANG_USED="$SETUP_LANG"
    LCID_USED="${LCID[$SETUP_LANG]}"
    LANG_FORCED=1
    echo "Language menu overridden by setup.txt: using $LANG_USED (LCID: $LCID_USED)"
fi
#Language code detected by folder name of the .mui files
if [[ "$LANG_FORCED" -eq 0 ]]; then
    for LANG_CODE in "${!LCID[@]}"; do
        if find "$GAMES_DIR" -maxdepth 2 -type d -name "$LANG_CODE" -print -quit | grep -q .; then
            LCID_USED="${LCID[$LANG_CODE]}"
            LANG_USED="$LANG_CODE"
            break
        fi
    done
fi
#Language selection menu
if [[ "$LANG_FORCED" -eq 1 || "$NON_INTERACTIVE" -eq 1 ]]; then
    echo "Using language: $LANG_USED (LCID: $LCID_USED)"
else
    echo "Detected language: $LANG_USED (LCID: $LCID_USED)"
    read -rp "Use this language for patching? [Y/n] " LANG_CONFIRM
    if [[ "$LANG_CONFIRM" =~ ^[Nn]$ ]]; then
        if [[ "$HAS_7Z" -eq 0 ]]; then
            echo "Manual language selection requires 7z, which is not installed." >&2
        else
            echo "Available languages:"
            mapfile -t SORTED_LANGS < <(printf '%s\n' "${!LCID[@]}" | sort)
            select CHOSEN_LANG in "${SORTED_LANGS[@]}"; do
                if [[ -n "$CHOSEN_LANG" ]]; then
                    LANG_USED="$CHOSEN_LANG"
                    LCID_USED="${LCID[$CHOSEN_LANG]}"
                    echo "Selected: $LANG_USED (LCID: $LCID_USED)"
                    break
                else
                    echo "Invalid selection, please try again."
                fi
            done
        fi
    fi
fi
#Modifies scripts if language is not en-US
if [[ "$LCID_USED" -ne 1033 ]]; then
    # Extract language folders from installer if 7z is available
    if [[ "$HAS_7Z" -eq 1 ]]; then
        echo "Extracting $LANG_USED language files from installer..."
        for GAME in "${!GAMES[@]}"; do
            IFS="|" read -r EXE_NAME DESKTOP_NAME ICON_NAME <<< "${GAMES[$GAME]}"
            GAME_DIR="$GAMES_DIR/$GAME"

            if [[ ! -d "$GAME_DIR" ]]; then
                echo "  $DESKTOP_NAME install folder not found, skipping language extraction..."
                continue
            fi
            #7z extract the exact folders for the language chosen for each game
            TMPDIR_LANG=$(mktemp -d)
            if 7z e "$GAMES_INSTALLER" -ir!"${GAME}/${LANG_USED}/*" -o"$TMPDIR_LANG" -y &>/dev/null; then
                if [[ -n "$(ls -A "$TMPDIR_LANG" 2>/dev/null)" ]]; then
                    mkdir -p "$GAME_DIR/$LANG_USED"
                    cp -r "$TMPDIR_LANG/." "$GAME_DIR/$LANG_USED/"
                    echo "  Extracted $LANG_USED files for $DESKTOP_NAME."
                else
                    echo "  No $LANG_USED files found in installer for $DESKTOP_NAME."
                fi
            else
                echo "  Could not extract $LANG_USED files for $DESKTOP_NAME."
            fi
            rm -rf "$TMPDIR_LANG"
        done
    fi
    echo "Patching reshacker scripts for locale $LANG_USED (LCID: $LCID_USED)..."
    LANG_SCRIPT_DIR="$(dirname "$0")/reshacker_${LANG_USED}_scripts"
else
    echo "Locale is en-US (1033) — no script patching needed."
    LANG_SCRIPT_DIR=""
fi
# When generating: write directly into the language folder if set, otherwise into the base folder
GEN_WILL_RUN=0
[[ "$HAS_PETOOLS" -eq 1 && ( "$HAS_SCRIPTS" -eq 0 || "$FORCE_GENERATE" -eq 1 ) ]] && GEN_WILL_RUN=1
if [[ "$GEN_WILL_RUN" -eq 1 ]]; then
    if [[ -n "$LANG_SCRIPT_DIR" ]]; then
        mkdir -p "$LANG_SCRIPT_DIR"
        SCRIPT_DIR="$LANG_SCRIPT_DIR"
    else
        mkdir -p "$BASE_SCRIPT_DIR"
    fi
fi
#just in case
mkdir -p "$HOME/.local/share/applications"
# If using pre-built scripts and a non-English language is needed, copy and patch the base folder
if [[ -n "$LANG_SCRIPT_DIR" && "$GEN_WILL_RUN" -eq 0 ]]; then
    cp -r "$BASE_SCRIPT_DIR" "$LANG_SCRIPT_DIR"
    while IFS= read -r -d '' script_file; do
        sed -i "s/1033/$LCID_USED/g" "$script_file"
        sed -i "s/en-US/$LANG_USED/g" "$script_file"
    done < <(find "$LANG_SCRIPT_DIR" -maxdepth 1 -type f -name "*.txt" -print0)
    SCRIPT_DIR="$LANG_SCRIPT_DIR"
    echo "Language-patched scripts saved to: $LANG_SCRIPT_DIR"
fi
#The main games patching loop
for GAME in "${!GAMES[@]}"; do
    IFS="|" read -r EXE_NAME DESKTOP_NAME ICON_NAME <<< "${GAMES[$GAME]}"
    #searches if game is installed eachtime, skiped if silently installed
    if [[ "$SILENT_INSTALL" -eq 0 && ! -f "$GAMES_DIR/$GAME/$EXE_NAME.exe" ]]; then
        echo "$DESKTOP_NAME not installed, skipping..."
        continue
    fi
    echo "Processing $DESKTOP_NAME..."
    # find MUI file, look in language subfolder first when a non-English language is selected
    MUI_FILE=""
    if [[ "$LANG_USED" != "en-US" ]]; then
        MUI_FILE=$(find "$GAMES_DIR/$GAME/$LANG_USED" -type f -name "*.mui" 2>/dev/null | head -n 1)
    fi
    [[ -z "$MUI_FILE" ]] && MUI_FILE=$(find "$GAMES_DIR/$GAME" -type f -name "*.mui" | head -n 1)

    if [[ ! -f "$MUI_FILE" ]]; then
        echo "No MUI file found for $DESKTOP_NAME, skipping..."
        continue
    fi
    #the first patching function, turns .mui into .res files
    WINEDEBUG=-all "$WINE_CMD" "$RE_HACKER" -open "$MUI_FILE" -save "$GAMES_DIR/$GAME/$EXE_NAME.res" -action extract -mask ",,," -log "logs/$EXE_NAME-extract.log"
    # Generate reshacker script directly into target dir, with language substitution if needed
    if [[ "$GEN_WILL_RUN" -eq 1 ]]; then
        python3 "$GEN_SCRIPT" "$MUI_FILE" "$GAME" "$EXE_NAME" "$PERESED" > "$SCRIPT_DIR/$EXE_NAME-script.txt"
        if [[ -n "$LANG_SCRIPT_DIR" ]]; then
            sed -i "s/1033/$LCID_USED/g" "$SCRIPT_DIR/$EXE_NAME-script.txt"
            sed -i "s/en-US/$LANG_USED/g" "$SCRIPT_DIR/$EXE_NAME-script.txt"
        fi
    fi
    #second patching function, uses generated scripts to add the .res file contents to the executable for each game that has been installed
    WINEDEBUG=-all "$WINE_CMD" "$RE_HACKER" -script "$SCRIPT_DIR/$EXE_NAME-script.txt"
#clean that log
    LOG_DIR="$(dirname "$0")/logs"
    clean_log() {
        local log_file="$1"
        if [[ -f "$log_file" ]]; then
            if command -v python3 &>/dev/null; then
                python3 -c "
import sys
path = sys.argv[1]
data = open(path, 'rb').read()
open(path, 'wb').write(data[::2])
" "$log_file"
            fi
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
Icon=${ICON_NAME}_${EXE_NAME}.0
Categories=Game;
Terminal=false
EOF
    chmod +x "$HOME/Desktop/${GAME// /_}.desktop"
    cp "$HOME/Desktop/${GAME// /_}.desktop" "$HOME/.local/share/applications/"
done
#Cleanup menu
echo ""
if [[ -n "$SETUP_CLEANUP" ]]; then
    CLEANUP="$SETUP_CLEANUP"
    echo "Cleanup menu overridden by setup.txt: using '$CLEANUP'."
elif [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    CLEANUP="n"
    echo "Non-interactive mode: skipping cleanup (add clean-all or clean-keep to setup.txt to change)."
else
    echo "Cleanup options:"
    echo "  y: Remove temp files, uninstall Resource Hacker and its shortcut"
    echo "  r: Remove temp files only, keep Resource Hacker and its shortcut"
    echo "  c: Remove only .res files created by the script"
    echo "  n: Skip cleanup"
    read -rp "Choice? [y/r/c/N] " CLEANUP
fi
#resource hacker directory for unistallation
if [[ "$SILENT_INSTALL" -eq 1 ]]; then
    RESHACKER_DIR="$PREFIX/drive_c/Program Files (x86)/Resource Hacker"
else
    RESHACKER_DIR="$(dirname "$RE_HACKER")"
fi
#cleanup tree, will not remove .exe installers since they are big files, too much responsibility
if [[ "$CLEANUP" =~ ^[YyRrCc]$ ]]; then
    if [[ "$CLEANUP" =~ ^[Cc]$ ]]; then
        echo "Removing .res files created by the script..."
        find "$GAMES_DIR" -maxdepth 2 -type f -name "*.res" -delete
    else
        echo "Removing .mui folders..."
        find "$GAMES_DIR" -type f -name "*.mui" -exec dirname {} \; | sort -u | while read -r dir; do
            echo "  Deleting: $dir"
            rm -rf "$dir"
        done
        #for some reason the installr includes .png screenshots of desktop shortucts in some of the folders, this cleans it up
        echo "Removing leftover .png and .res files from game folders..."
        find "$GAMES_DIR" -maxdepth 2 -type f -name "*.png" -delete
        find "$GAMES_DIR" -maxdepth 2 -type f -name "*.res" -delete
        if [[ "$CLEANUP" =~ ^[Yy]$ ]]; then
            echo "Uninstalling Resource Hacker..."
            UNINSTALLER=$(find "$RESHACKER_DIR" -maxdepth 1 -name "unins*.exe" 2>/dev/null | head -n1)
            if [[ -n "$UNINSTALLER" ]]; then
                WINEDEBUG=-all "$WINE_CMD" "$UNINSTALLER" /SILENT 2>/dev/null
            else
                rm -rf "$RESHACKER_DIR"
            fi
            if [[ -d "$RESHACKER_DIR" ]]; then
                echo "Removing leftover Resource Hacker files..."
                rm -rf "$RESHACKER_DIR"
            fi
            rm -f "$RE_HACKER_LNK"
        else
            echo "Keeping Resource Hacker installed."
        fi
    fi
    echo "Cleanup complete."
fi
# Remove any shortcuts Wine created in its programs menu during the script running
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
#visual way of telling if script is done
echo "Done."
if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    touch "$(dirname "$0")/DONE"
    sleep 2
    rm -f "$(dirname "$0")/DONE"
fi
