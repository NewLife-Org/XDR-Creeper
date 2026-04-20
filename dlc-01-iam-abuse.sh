#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  DLC-01: IAM ABUSE — Identity & Access Management Attack Simulation        ║
# ║  Part of XDR Creeper | Author: Daniel Budyn | NEWLIFE | Purple accent    ║
# ║  Usage: sudo ./newlife-core-linux.sh --dlc 01-iam-abuse                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

DLC_NAME="DLC-01: IAM ABUSE"
DLC_DESC="Identity & Access Management — account manipulation, privilege abuse, credential theft"
DLC_MITRE="T1136 T1098 T1078 T1087 T1069 T1201 T1556 T1548 T1552"
DLC_RISK="HIGH"
DLC_ACCENT="${DLC_COLORS[01]:-\033[38;5;141m}"
DLC_TOTAL=15
IAM_P='\033[38;5;141m'; IAM_PL='\033[38;5;183m'; IAM_PD='\033[38;5;97m'
IAM_PB='\033[1;38;5;141m'; IAM_BG='\033[48;5;53m'

DLC_ATTACKS="Local account creation with shell access
Privileged group injection (sudo/wheel/docker)
UID 0 clone — shadow root account
Password policy weakening (/etc/login.defs)
PAM configuration tampering
Sudoers file NOPASSWD injection
SSH authorized_keys rogue key injection
Service account creation (nologin exploit)
Account lock/unlock manipulation
/etc/passwd direct field analysis
NSSwitch / Name Service tampering
Kerberos keytab & ticket harvesting
SSSD / LDAP / AD integration enumeration
Token & credential cache theft
IAM audit — full identity posture report"

# ── Display helpers ──
iam_phase() { local num=$1; shift; local title="$1"; shift; local mitre="$1"
    echo ""; echo -e "${IAM_BG}${W}                                                                              ${N}"
    echo -e "${IAM_BG}${W}  ◆ IAM ATTACK ${num}/${DLC_TOTAL} : ${title}  ${N}"
    echo -e "${IAM_BG}${W}  ◆ MITRE          : ${mitre}  ${N}"
    echo -e "${IAM_BG}${W}                                                                              ${N}"; echo ""; sleep 1; }
iam_th() { echo -e "  ${IAM_P}  ┌── ${1} ──────────────────────────────────────────┐${N}"; }
iam_tr() { echo -e "  ${IAM_P}  │${N} $1"; }
iam_tf() { echo -e "  ${IAM_P}  └──────────────────────────────────────────────────────────────┘${N}"; }
iam_explain() {
    local title="$1"; shift
    echo ""; echo -e "  ${IAM_PL}  ╭── 📖 ${title} ────────────────────────────────────────╮${N}"
    while [[ $# -gt 0 ]]; do echo -e "  ${IAM_PL}  │${N} ${D}$1${N}"; shift; done
    echo -e "  ${IAM_PL}  ╰──────────────────────────────────────────────────────────────╯${N}"; echo ""
}

# ── ATTACK 01: LOCAL ACCOUNT CREATION ──
iam_attack_01() {
    iam_phase 1 "LOCAL ACCOUNT CREATION WITH SHELL ACCESS" "T1136.001 Create Account: Local"
    xdr "New local user creation with interactive shell"
    iam_explain "Why this matters" \
        "Attackers create local accounts to maintain access even if" \
        "the original entry point is patched. Accounts with /bin/bash" \
        "allow interactive login. Weak passwords enable brute-force." \
        "" \
        "What happens: 3 test accounts are created with /bin/bash," \
        "passwords set, then ALL are removed within seconds."

    local accounts=("iam_svc_admin" "iam_backup_op" "iam_helpdesk") created=0
    hack "Creating suspicious local accounts..."; echo ""; iam_th "CREATED ACCOUNTS"
    for acct in "${accounts[@]}"; do
        useradd -M -s /bin/bash -c "XDR IAM Test — ${acct}" "$acct" 2>/dev/null
        if id "$acct" &>/dev/null; then
            local uid; uid=$(id -u "$acct"); iam_tr "$(printf '${R}⚠ %-18s${N} UID:%-6s shell:/bin/bash' "$acct" "$uid")"
            csv_log "IAM" "create_user" "$acct (UID:$uid)" "OK"; created=$((created + 1))
        else iam_tr "$(printf '${D}  %-18s BLOCKED${N}' "$acct")"; fi
    done; iam_tf; result "Created ${created}/${#accounts[@]} accounts"; echo ""
    hack "Setting weak passwords..."
    for acct in "${accounts[@]}"; do echo "${acct}:Password123!" | chpasswd 2>/dev/null && info "Password set: ${acct}"; done
    show_finding "HIGH" "Account creation: ${created} accounts with /bin/bash and weak passwords"
    write_finding "IAM-01" "Local Account Creation" "T1136.001" "EXECUTED" "HIGH" \
        "${created} accounts created with interactive shell + weak password" \
        "Monitor useradd/adduser in syslog. Alert on new accounts with /bin/bash. Enforce password complexity."
    sleep 3; hack "Cleanup: removing test accounts..."
    for acct in "${accounts[@]}"; do userdel -r "$acct" 2>/dev/null || userdel "$acct" 2>/dev/null; done
    ok "All test accounts removed"; csv_log "IAM" "cleanup_users" "removed" "OK"
}

# ── ATTACK 02: PRIVILEGED GROUP INJECTION ──
iam_attack_02() {
    iam_phase 2 "PRIVILEGED GROUP INJECTION" "T1098.001 Account Manipulation"
    xdr "User added to privileged groups — sudo, wheel, docker, adm, lxd"
    iam_explain "Group = Privilege" \
        "Adding a user to certain groups gives immediate power:" \
        "  sudo/wheel  → execute ANY command as root" \
        "  docker      → mount host filesystem → root escape" \
        "  lxd         → create privileged container → root" \
        "  shadow      → read /etc/shadow → offline password crack" \
        "  disk        → raw disk read → extract any file" \
        "" \
        "What happens: test user created, added to groups, then removed."

    hack "Creating test user..."; useradd -M -s /bin/bash -c "XDR Group Test" iam_grp_test 2>/dev/null || true
    local groups=("sudo" "wheel" "adm" "docker" "lxd" "shadow" "disk" "root") injected=0
    hack "Injecting into privileged groups..."; echo ""; iam_th "GROUP INJECTION"
    for grp in "${groups[@]}"; do
        if getent group "$grp" &>/dev/null; then
            usermod -aG "$grp" iam_grp_test 2>/dev/null
            if id -nG iam_grp_test 2>/dev/null | grep -qw "$grp"; then
                iam_tr "$(printf '${R}⚠ %-12s${N} → ${G}ADDED${N}' "$grp")"; injected=$((injected+1))
            else iam_tr "$(printf '${Y}  %-12s${N} → BLOCKED' "$grp")"; fi
            csv_log "IAM" "group_inject" "$grp" "OK"
        else iam_tr "$(printf '${D}  %-12s${N} → not present' "$grp")"; fi
    done; iam_tf; echo ""
    echo -e "  ${IAM_P}  Final membership: $(id iam_grp_test 2>/dev/null)${N}"
    show_finding "HIGH" "Group injection: ${injected} privileged groups granted"
    write_finding "IAM-02" "Group Injection" "T1098.001" "EXECUTED" "HIGH" \
        "${injected} privileged groups added (includes potential root-equivalent)" \
        "Monitor usermod -aG in syslog. Alert on additions to sudo/docker/lxd groups."
    sleep 3; hack "Cleanup..."; userdel -r iam_grp_test 2>/dev/null || userdel iam_grp_test 2>/dev/null
    ok "User removed"; csv_log "IAM" "cleanup_groups" "removed" "OK"
}

# ── ATTACK 03: UID 0 CLONE ──
iam_attack_03() {
    iam_phase 3 "UID 0 CLONE — SHADOW ROOT ACCOUNT" "T1078.003 Valid Accounts / T1136"
    xdr "Account with UID 0 — second root user"
    iam_explain "The Most Dangerous Persistence" \
        "An account with UID=0 has FULL root privileges regardless" \
        "of its name. It bypasses name-based access controls." \
        "Defenders searching for 'root' won't find 'xdr_shadow_root'." \
        "" \
        "What happens: UID-0 clone created, displayed, then removed."

    hack "Creating UID 0 clone..."; warn "This creates a root-level account (UID=0)"
    cp /etc/passwd /etc/passwd.xdr_bak 2>/dev/null
    useradd -o -u 0 -g 0 -M -s /bin/bash -c "XDR Shadow Root" xdr_shadow_root 2>/dev/null
    if id xdr_shadow_root &>/dev/null; then
        echo -e "  ${R}  ⚠ SHADOW ROOT: $(grep '^xdr_shadow_root' /etc/passwd)${N}"
        show_finding "CRITICAL" "UID-0 clone created — full root under different name"
        write_finding "IAM-03" "UID-0 Clone" "T1078.003" "EXECUTED" "CRITICAL" \
            "xdr_shadow_root created with UID=0, full root equivalent" \
            "Monitor for UID=0 accounts other than root. auditd rule on /etc/passwd writes."
        csv_log "IAM" "uid0_clone" "created" "CRITICAL"
    else
        show_finding "INFO" "UID-0 clone blocked by system policy"
        write_finding "IAM-03" "UID-0 Clone" "T1078.003" "BLOCKED" "LOW" \
            "System blocked UID-0 duplicate creation" \
            "Good — system prevents UID-0 duplicates."
        csv_log "IAM" "uid0_clone" "blocked" "BLOCKED"
    fi
    echo ""; run "All UID 0 accounts on system:"
    awk -F: '$3==0' /etc/passwd 2>/dev/null | while read line; do echo -e "  ${R}  ⚠ ${line}${N}"; done
    sleep 3; hack "Cleanup..."
    userdel xdr_shadow_root 2>/dev/null
    [[ -f /etc/passwd.xdr_bak ]] && grep -q "^xdr_shadow_root" /etc/passwd 2>/dev/null && cp /etc/passwd.xdr_bak /etc/passwd
    rm -f /etc/passwd.xdr_bak; ok "Shadow root removed"; csv_log "IAM" "uid0_cleanup" "removed" "OK"
}

# ── ATTACK 04: PASSWORD POLICY WEAKENING ──
iam_attack_04() {
    iam_phase 4 "PASSWORD POLICY WEAKENING" "T1201 Password Policy Discovery / T1556"
    xdr "Password policy modified — complexity reduced"
    iam_explain "Policy Weakening = Easy Brute Force" \
        "Weak password policies allow: short passwords, no expiry," \
        "immediate reuse. An attacker who weakens the policy can:" \
        "  - Set 1-character passwords on compromised accounts" \
        "  - Ensure passwords never expire (persistence)" \
        "  - Disable complexity requirements" \
        "" \
        "What happens: policy read, briefly weakened, then restored."

    run "Current policy..."; echo ""; iam_th "CURRENT POLICY"
    for p in PASS_MAX_DAYS PASS_MIN_DAYS PASS_MIN_LEN PASS_WARN_AGE ENCRYPT_METHOD; do
        local v; v=$(grep "^${p}" /etc/login.defs 2>/dev/null | awk '{print $2}'); [[ -z "$v" ]] && v="(not set)"
        iam_tr "$(printf '%-20s = %s' "$p" "$v")"
    done; iam_tf; csv_log "IAM" "policy_read" "login.defs" "OK"; echo ""
    hack "Weakening policy (backup → modify → restore)..."
    cp /etc/login.defs /etc/login.defs.xdr_bak 2>/dev/null
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   99999/' /etc/login.defs 2>/dev/null
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   0/' /etc/login.defs 2>/dev/null
    sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN    1/' /etc/login.defs 2>/dev/null
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   0/' /etc/login.defs 2>/dev/null
    show_finding "CRITICAL" "Password policy weakened — min length 1, no expiry, no warning"
    write_finding "IAM-04" "Policy Weakening" "T1556" "EXECUTED" "CRITICAL" \
        "PASS_MAX_DAYS=99999, PASS_MIN_LEN=1, PASS_WARN_AGE=0" \
        "Monitor /etc/login.defs changes with auditd. Enforce min 14 chars, 90-day expiry."
    csv_log "IAM" "policy_weaken" "modified" "CRITICAL"
    logger -t "xdr-creeper" "IAM: PASSWORD POLICY WEAKENED"
    sleep 3; hack "Restoring policy from backup..."
    [[ -f /etc/login.defs.xdr_bak ]] && cp /etc/login.defs.xdr_bak /etc/login.defs && rm -f /etc/login.defs.xdr_bak
    ok "Policy restored"; csv_log "IAM" "policy_restore" "restored" "OK"
}

# ── ATTACK 05: PAM TAMPERING ──
iam_attack_05() {
    iam_phase 5 "PAM CONFIGURATION TAMPERING" "T1556.003 Modify Auth: PAM"
    xdr "PAM configuration analyzed for weaknesses"
    iam_explain "PAM — The Authentication Gatekeeper" \
        "Pluggable Authentication Modules control HOW users log in." \
        "A tampered PAM config can: allow login without password" \
        "(pam_permit.so), accept empty passwords (nullok flag)," \
        "or log credentials to a file (pam_exec backdoor)." \
        "" \
        "What happens: PAM configs enumerated, security analyzed." \
        "Simulated backdoor created in /tmp only (not in /etc/pam.d)."

    run "Enumerating PAM configuration..."; echo ""
    iam_th "PAM CONFIGS"
    local pam_count; pam_count=$(ls /etc/pam.d/ 2>/dev/null | wc -l)
    iam_tr "Total PAM files: ${pam_count}"
    for f in common-auth common-password sshd su sudo login; do
        [[ -f "/etc/pam.d/$f" ]] && iam_tr "  ${IAM_PL}${f}${N}  ($(grep -c '^[^#]' "/etc/pam.d/$f" 2>/dev/null) active rules)"
    done; iam_tf; csv_log "IAM" "pam_enum" "${pam_count} files" "OK"; echo ""
    run "Security analysis..."
    local pam_issues=0
    if grep -rq "pam_permit.so" /etc/pam.d/ 2>/dev/null; then
        echo -e "  ${R}  ⚠ pam_permit.so FOUND — allows login without password!${N}"; pam_issues=$((pam_issues+1))
    else echo -e "  ${G}  ✔ No pam_permit.so (good)${N}"; fi
    if grep -rq "nullok" /etc/pam.d/ 2>/dev/null; then
        echo -e "  ${Y}  ⚠ nullok flag — empty passwords accepted${N}"; pam_issues=$((pam_issues+1))
    else echo -e "  ${G}  ✔ No nullok (good)${N}"; fi
    show_finding "$([ $pam_issues -gt 0 ] && echo MEDIUM || echo LOW)" \
        "PAM analysis: ${pam_issues} issue(s) found in ${pam_count} configs"
    write_finding "IAM-05" "PAM Analysis" "T1556.003" "ANALYZED" \
        "$([ $pam_issues -gt 0 ] && echo MEDIUM || echo LOW)" \
        "${pam_issues} PAM issues in ${pam_count} files" \
        "Remove pam_permit.so. Remove nullok flags. Monitor PAM config changes."
    hack "Simulated PAM backdoor (in /tmp only)..."
    echo "# XDR CREEPER — simulated PAM backdoor" > /tmp/.xdr_pam_sim 2>/dev/null
    logger -t "xdr-creeper" "IAM: PAM backdoor simulation"; sleep 2; rm -f /tmp/.xdr_pam_sim
    ok "Simulation file removed"
}

# ── ATTACK 06: SUDO NOPASSWD INJECTION ──
iam_attack_06() {
    iam_phase 6 "SUDOERS NOPASSWD INJECTION" "T1548.003 Abuse Elevation: Sudo"
    xdr "Sudoers drop-in with NOPASSWD rule injected"
    iam_explain "NOPASSWD = Root Without Questions" \
        "A NOPASSWD rule in sudoers allows executing commands as root" \
        "without entering a password. Attackers use this for:" \
        "  - Persistent root access without knowing any password" \
        "  - Backdoor surviving password changes" \
        "  - Stealth — no sudo auth prompts in logs" \
        "" \
        "What happens: drop-in file created, existing rules scanned, removed."

    hack "Injecting NOPASSWD rule..."
    local sf="/etc/sudoers.d/99-xdr-creeper-test"
    printf '# XDR CREEPER TEST — auto-removed\niam_test ALL=(ALL) NOPASSWD: ALL\n' > "$sf" 2>/dev/null
    chmod 440 "$sf" 2>/dev/null
    echo -e "  ${R}  ⚠ CREATED: ${sf}${N}"
    run "Scanning all NOPASSWD rules on system..."
    local nopasswd_count; nopasswd_count=$(grep -rn "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -vc "^#" || echo 0)
    grep -rn "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v "^#" | while read l; do
        [[ "$l" == *xdr* ]] && echo -e "  ${R}  ⚠ INJECTED: ${l}${N}" || echo -e "  ${Y}  ⚠ EXISTING: ${l}${N}"
    done
    show_finding "$([ $nopasswd_count -gt 1 ] && echo HIGH || echo MEDIUM)" \
        "Sudoers: ${nopasswd_count} NOPASSWD rule(s) active"
    write_finding "IAM-06" "Sudo NOPASSWD" "T1548.003" "EXECUTED" "HIGH" \
        "NOPASSWD rule injected + ${nopasswd_count} total NOPASSWD rules found" \
        "Remove unnecessary NOPASSWD rules. Audit /etc/sudoers.d/ regularly. Use sudo with password."
    csv_log "IAM" "sudo_inject" "${nopasswd_count} nopasswd" "OK"
    sleep 3; hack "Cleanup..."; rm -f "$sf"; ok "Sudoers drop-in removed"
}

# ── ATTACK 07: SSH KEY INJECTION ──
iam_attack_07() {
    iam_phase 7 "SSH AUTHORIZED_KEYS INJECTION" "T1098.004 SSH Authorized Keys"
    xdr "Rogue SSH key injected into authorized_keys"
    iam_explain "SSH Key Backdoor" \
        "An attacker who adds their public key to authorized_keys" \
        "can log in anytime without a password. This survives:" \
        "  - Password changes (key auth is separate)" \
        "  - Account lockouts (key auth bypasses pam_tally)" \
        "  - MFA (unless enforced on SSH key auth too)" \
        "" \
        "What happens: fake key injected, immediately restored from backup."

    local rk="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeXDRCreeperKey xdr-creeper@test"
    local injected=0
    hack "Scanning SSH key files..."; echo ""
    for h in /root /home/*; do [[ ! -d "$h" ]] && continue
        local u; u=$(basename "$h"); [[ "$h" == "/root" ]] && u="root"
        local ak="${h}/.ssh/authorized_keys"
        if [[ -f "$ak" ]]; then
            local kc; kc=$(wc -l < "$ak" 2>/dev/null || echo 0)
            cp "$ak" "${ak}.xdr_bak" 2>/dev/null
            echo "$rk" >> "$ak" 2>/dev/null
            if grep -q "xdr-creeper@test" "$ak" 2>/dev/null; then
                echo -e "  ${R}  ⚠ ${u}: ROGUE KEY INJECTED (${kc} existing keys)${N}"
                injected=$((injected+1))
            fi
            sleep 1; mv "${ak}.xdr_bak" "$ak" 2>/dev/null; echo -e "  ${G}  ✔ ${u}: restored${N}"
        else echo -e "  ${D}  ${u}: no authorized_keys${N}"; fi
    done
    show_finding "$([ $injected -gt 0 ] && echo HIGH || echo LOW)" \
        "SSH key injection: ${injected} accounts had keys injected+restored"
    write_finding "IAM-07" "SSH Key Injection" "T1098.004" "EXECUTED" "HIGH" \
        "${injected} authorized_keys modified (immediately restored)" \
        "Monitor authorized_keys changes. Use centralized SSH key management. Enable SSH certificate auth."
    csv_log "IAM" "ssh_inject" "${injected} keys" "OK"
}

# ── ATTACK 08: SERVICE ACCOUNT CREATION ──
iam_attack_08() {
    iam_phase 8 "SERVICE ACCOUNT CREATION — NOLOGIN EXPLOIT" "T1136.001 / T1078.001"
    xdr "Service account with nologin shell but exploitable"
    iam_explain "Service Accounts Are Not Safe" \
        "Accounts with /usr/sbin/nologin can still:" \
        "  - Run cron jobs (cron doesn't check shell)" \
        "  - Be used with su -s /bin/bash (shell override)" \
        "  - Own files and processes" \
        "  - Be targets for privilege escalation"

    hack "Creating service account..."
    useradd -r -M -s /usr/sbin/nologin -c "XDR Service Test" iam_svc_test 2>/dev/null
    if id iam_svc_test &>/dev/null; then
        echo -e "  ${R}  ⚠ Created: iam_svc_test ($(id iam_svc_test))${N}"
        run "Testing su override..."
        echo -e "  ${D}  su -s /bin/bash iam_svc_test -c 'whoami' → would execute as iam_svc_test${N}"
        show_finding "MEDIUM" "Service account created — nologin bypassed with su -s"
        write_finding "IAM-08" "Service Account" "T1136.001" "EXECUTED" "MEDIUM" \
            "Service account with nologin created, su -s bypass possible" \
            "Audit service accounts regularly. Use systemd DynamicUser. Restrict su access."
    else
        show_finding "INFO" "Service account creation blocked"
        write_finding "IAM-08" "Service Account" "T1136.001" "BLOCKED" "LOW" "Creation blocked" "Good."
    fi
    csv_log "IAM" "svc_account" "created" "OK"
    sleep 2; hack "Cleanup..."; userdel iam_svc_test 2>/dev/null; ok "Service account removed"
}

# ── ATTACK 09: ACCOUNT LOCK/UNLOCK MANIPULATION ──
iam_attack_09() {
    iam_phase 9 "ACCOUNT LOCK/UNLOCK MANIPULATION" "T1531 Account Access Removal / T1098"
    xdr "Account locking and unlocking demonstrated"
    iam_explain "Lock as a Weapon" \
        "passwd -l locks an account (adds ! to shadow hash)." \
        "An attacker can lock ALL accounts except their backdoor," \
        "effectively denying access to legitimate administrators." \
        "" \
        "What happens: test account locked, status shown, unlocked, removed."

    hack "Creating + locking test account..."
    useradd -M -s /bin/bash -c "XDR Lock Test" iam_lock_test 2>/dev/null
    echo "iam_lock_test:TestPass1!" | chpasswd 2>/dev/null
    passwd -l iam_lock_test 2>/dev/null
    local status; status=$(passwd -S iam_lock_test 2>/dev/null)
    echo -e "  ${R}  LOCKED: ${status}${N}"
    hack "Unlocking..."
    passwd -u iam_lock_test 2>/dev/null
    status=$(passwd -S iam_lock_test 2>/dev/null)
    echo -e "  ${G}  UNLOCKED: ${status}${N}"
    show_finding "MEDIUM" "Account lock/unlock manipulation demonstrated"
    write_finding "IAM-09" "Account Lock Manipulation" "T1531" "EXECUTED" "MEDIUM" \
        "Account lock/unlock cycle demonstrated" \
        "Monitor passwd -l / -u events. Alert on mass account locking. Maintain break-glass accounts."
    csv_log "IAM" "lock_test" "done" "OK"
    sleep 2; userdel iam_lock_test 2>/dev/null; ok "Test account removed"
}

# ── ATTACK 10: /ETC/PASSWD ANALYSIS ──
iam_attack_10() {
    iam_phase 10 "/ETC/PASSWD DIRECT ANALYSIS" "T1087.001 Account Discovery / T1003"
    xdr "Password file structure and integrity analyzed"
    iam_explain "Why /etc/passwd Matters" \
        "/etc/passwd is world-readable and reveals: all usernames," \
        "UIDs, home directories, shells. Combined with /etc/shadow" \
        "(root-readable), an attacker maps the entire identity surface." \
        "Duplicate UIDs, weak permissions, empty passwords = critical."

    run "Analyzing /etc/passwd..."; echo ""
    local total; total=$(wc -l < /etc/passwd)
    iam_th "PASSWD ANALYSIS"
    iam_tr "Total accounts: ${total}"
    iam_tr "Interactive   : $(grep -cE '/bin/(bash|sh|zsh)' /etc/passwd)"
    iam_tr "System        : $(awk -F: '$3<1000 && $3>0' /etc/passwd | wc -l)"
    iam_tr "UID 0         : $(awk -F: '$3==0' /etc/passwd | wc -l)"
    iam_tr "Dup UIDs      : $(awk -F: '{print $3}' /etc/passwd | sort | uniq -d | wc -l)"
    iam_tr "Empty pass    : $(awk -F: '$2==""' /etc/shadow 2>/dev/null | wc -l)"; iam_tf
    csv_log "IAM" "passwd_analysis" "${total} users" "OK"; echo ""
    local pp; pp=$(stat -c '%a' /etc/passwd 2>/dev/null); local sp; sp=$(stat -c '%a' /etc/shadow 2>/dev/null)
    [[ "$pp" != "644" ]] && echo -e "  ${R}  ⚠ passwd perms: ${pp} (expected 644)${N}" || echo -e "  ${G}  ✔ passwd perms: ${pp}${N}"
    [[ "$sp" != "640" && "$sp" != "600" ]] && echo -e "  ${R}  ⚠ shadow perms: ${sp} (expected 640)${N}" || echo -e "  ${G}  ✔ shadow perms: ${sp}${N}"
    local uid0_count; uid0_count=$(awk -F: '$3==0' /etc/passwd | wc -l)
    show_finding "$([ $uid0_count -gt 1 ] && echo CRITICAL || echo LOW)" \
        "Identity surface: ${total} accounts, ${uid0_count} UID-0, shadow perms=${sp}"
    write_finding "IAM-10" "Passwd Analysis" "T1087.001" "ANALYZED" \
        "$([ $uid0_count -gt 1 ] && echo CRITICAL || echo LOW)" \
        "Total=${total} UID0=${uid0_count} passwd=${pp} shadow=${sp}" \
        "Ensure only root has UID=0. Verify shadow perms=640. Audit /etc/passwd for anomalies."
}

# ── ATTACK 11: NSSWITCH TAMPERING ──
iam_attack_11() {
    iam_phase 11 "NSSWITCH TAMPERING" "T1556 Modify Auth Process"
    xdr "nsswitch.conf modified to add rogue LDAP backend"
    iam_explain "NSSwitch Controls Identity Sources" \
        "nsswitch.conf tells the system WHERE to look for users:" \
        "'files' = /etc/passwd, 'ldap' = LDAP server, 'sss' = SSSD." \
        "An attacker who adds 'ldap' can point auth to their server," \
        "creating phantom users that exist only in the rogue LDAP." \
        "" \
        "What happens: 'ldap' added to passwd/group/shadow, then restored."

    run "Current nsswitch..."; iam_th "NSSWITCH"
    [[ -f /etc/nsswitch.conf ]] && grep -v "^#" /etc/nsswitch.conf | grep -v "^$" | while read l; do iam_tr "${D}${l}${N}"; done
    iam_tf; echo ""
    hack "Tampering..."; cp /etc/nsswitch.conf /etc/nsswitch.conf.xdr_bak 2>/dev/null
    sed -i 's/^passwd:.*/passwd:     files ldap/' /etc/nsswitch.conf 2>/dev/null
    sed -i 's/^group:.*/group:      files ldap/' /etc/nsswitch.conf 2>/dev/null
    sed -i 's/^shadow:.*/shadow:     files ldap/' /etc/nsswitch.conf 2>/dev/null
    show_finding "HIGH" "nsswitch.conf tampered — rogue LDAP backend added"
    write_finding "IAM-11" "NSSwitch Tamper" "T1556" "EXECUTED" "HIGH" \
        "LDAP added to passwd/group/shadow in nsswitch.conf" \
        "Monitor nsswitch.conf with file integrity monitoring. Alert on 'ldap' additions."
    csv_log "IAM" "nsswitch_tamper" "ldap" "OK"; logger -t "xdr-creeper" "IAM: NSSWITCH tampered"
    sleep 3; hack "Restoring..."
    [[ -f /etc/nsswitch.conf.xdr_bak ]] && cp /etc/nsswitch.conf.xdr_bak /etc/nsswitch.conf && rm -f /etc/nsswitch.conf.xdr_bak
    ok "nsswitch restored"
}

# ── ATTACK 12: KERBEROS HARVEST ──
iam_attack_12() {
    iam_phase 12 "KERBEROS KEYTAB & TICKET HARVEST" "T1558 Steal Kerberos Tickets"
    xdr "Kerberos keytabs and ticket caches scanned"
    iam_explain "Kerberos on Linux" \
        "Domain-joined Linux hosts store Kerberos credentials in:" \
        "  /etc/krb5.keytab    — machine account credentials" \
        "  /tmp/krb5cc_*       — user ticket caches (TGT)" \
        "  /var/lib/sss/db/    — SSSD credential cache" \
        "An attacker with these can impersonate the machine or users."

    local findings=0
    [[ -f /etc/krb5.conf ]] && { echo -e "  ${IAM_P}  krb5.conf found — $(grep 'default_realm' /etc/krb5.conf 2>/dev/null)${N}"; findings=$((findings+1)); } || info "No Kerberos config"
    echo ""; hack "Keytab files..."
    find / -name "*.keytab" 2>/dev/null | head -10 | while read k; do echo -e "  ${R}  ⚠ KEYTAB: ${k}${N}"; echo "KEYTAB: ${k}" >> "$LOOT"; findings=$((findings+1)); done
    echo ""; hack "Ticket caches..."
    find /tmp -name "krb5cc_*" 2>/dev/null | while read t; do echo -e "  ${R}  ⚠ TICKET: ${t} ($(stat -c '%U' "$t" 2>/dev/null))${N}"; echo "TICKET: ${t}" >> "$LOOT"; findings=$((findings+1)); done
    show_finding "$([ $findings -gt 0 ] && echo HIGH || echo INFO)" \
        "Kerberos: ${findings} credential artifacts found"
    write_finding "IAM-12" "Kerberos Harvest" "T1558" "SCANNED" \
        "$([ $findings -gt 0 ] && echo HIGH || echo INFO)" \
        "${findings} Kerberos artifacts (keytabs + tickets)" \
        "Restrict keytab permissions (600 root only). Rotate machine passwords. Monitor ticket extraction."
    csv_log "IAM" "krb_harvest" "done" "OK"
}

# ── ATTACK 13: SSSD/LDAP/AD ENUM ──
iam_attack_13() {
    iam_phase 13 "SSSD / LDAP / AD ENUMERATION" "T1087.002 Domain Account Discovery"
    xdr "Domain integration analyzed"
    iam_explain "Linux in Active Directory" \
        "Linux hosts join AD via SSSD, Winbind, or realmd." \
        "An attacker discovers: domain name, DC addresses," \
        "join method, cached credentials, trust relationships." \
        "This info feeds into DLC-09 (AD Attacks) for full exploitation."

    local domain_found=false
    run "SSSD..."
    [[ -f /etc/sssd/sssd.conf ]] && { echo -e "  ${IAM_P}  sssd.conf (perms: $(stat -c '%a' /etc/sssd/sssd.conf 2>/dev/null))${N}"
        grep -E "^(domains|id_provider|ad_domain)" /etc/sssd/sssd.conf 2>/dev/null | while read l; do echo -e "  ${R}  ⚠ ${l}${N}"; done
        domain_found=true; } || info "No SSSD"
    echo ""; run "LDAP..."
    for lc in /etc/ldap/ldap.conf /etc/openldap/ldap.conf; do
        [[ -f "$lc" ]] && echo -e "  ${IAM_P}  ${lc}${N}" && grep -iE "^(URI|BASE)" "$lc" 2>/dev/null | while read l; do echo -e "  ${D}    ${l}${N}"; done
    done
    echo ""; run "Samba..."
    [[ -f /etc/samba/smb.conf ]] && echo -e "  ${IAM_P}  smb.conf${N}" && grep -iE "^(realm|workgroup)" /etc/samba/smb.conf 2>/dev/null | while read l; do echo -e "  ${D}    ${l}${N}"; done || info "No Samba"
    echo ""; run "Domain join..."
    command -v realm &>/dev/null && { local r; r=$(realm list --name-only 2>/dev/null); [[ -n "$r" ]] && { echo -e "  ${R}  ⚠ JOINED: ${r}${N}"; domain_found=true; } || info "Not joined"; }
    show_finding "$(if $domain_found; then echo HIGH; else echo INFO; fi)" \
        "Domain integration: $(if $domain_found; then echo 'AD/LDAP detected'; else echo 'standalone host'; fi)"
    write_finding "IAM-13" "Domain Enumeration" "T1087.002" "ANALYZED" \
        "$(if $domain_found; then echo HIGH; else echo LOW; fi)" \
        "Domain joined: ${domain_found}" \
        "Secure SSSD config (perms 600). Review domain trust. Restrict cached credentials."
    csv_log "IAM" "domain" "done" "OK"
}

# ── ATTACK 14: TOKEN & CREDENTIAL CACHE ──
iam_attack_14() {
    iam_phase 14 "TOKEN & CREDENTIAL CACHE THEFT" "T1528 / T1552"
    xdr "Cloud and application token caches scanned"
    iam_explain "Cached Credentials Everywhere" \
        "Modern systems cache credentials from many services:" \
        "  ~/.azure/    — Azure CLI tokens (plaintext JSON)" \
        "  ~/.aws/      — AWS access keys" \
        "  ~/.kube/     — Kubernetes service tokens" \
        "  ~/.docker/   — Container registry auth" \
        "  ~/.netrc     — FTP/HTTP credentials" \
        "An attacker copies these to impersonate from any machine."

    local f=0; hack "Scanning credential caches..."; echo ""
    for uh in /root /home/*; do [[ ! -d "$uh" ]] && continue
        local u; u=$(basename "$uh"); [[ "$uh" == "/root" ]] && u="root"
        [[ -d "${uh}/.azure" ]] && { echo -e "  ${R}  ⚠ Azure CLI: ${uh}/.azure${N}"; f=$((f+1)); }
        [[ -d "${uh}/.config/gcloud" ]] && { echo -e "  ${R}  ⚠ GCP SDK: ${uh}/.config/gcloud${N}"; f=$((f+1)); }
        [[ -f "${uh}/.aws/credentials" ]] && { echo -e "  ${R}  ⚠ AWS CLI: ${uh}/.aws/credentials${N}"; f=$((f+1)); }
        [[ -f "${uh}/.docker/config.json" ]] && { echo -e "  ${R}  ⚠ Docker: ${uh}/.docker/config.json${N}"; f=$((f+1)); }
        [[ -f "${uh}/.kube/config" ]] && { echo -e "  ${R}  ⚠ Kube: ${uh}/.kube/config${N}"; f=$((f+1)); }
        [[ -f "${uh}/.netrc" ]] && { echo -e "  ${R}  ⚠ .netrc: ${uh}/.netrc${N}"; f=$((f+1)); }
    done
    show_finding "$([ $f -gt 0 ] && echo HIGH || echo INFO)" \
        "Credential caches: ${f} found across all users"
    write_finding "IAM-14" "Token Cache Theft" "T1528" "SCANNED" \
        "$([ $f -gt 0 ] && echo HIGH || echo LOW)" \
        "${f} credential caches found" \
        "Encrypt token caches. Use short-lived tokens. az logout after sessions. Remove unused cloud CLIs."
    csv_log "IAM" "tokens" "${f} caches" "OK"
}

# ── ATTACK 15: IAM FULL AUDIT ──
iam_attack_15() {
    iam_phase 15 "IAM AUDIT — FULL IDENTITY POSTURE" "T1087 Account Discovery"
    xdr "Comprehensive identity and access management audit"

    echo -e "\n  ${IAM_PB}  ┌──────────────────────────────────────────────────────────────┐${N}"
    echo -e "  ${IAM_PB}  │             IDENTITY & ACCESS MANAGEMENT AUDIT               │${N}"
    echo -e "  ${IAM_PB}  └──────────────────────────────────────────────────────────────┘${N}\n"
    local total shell_u uid0 locked nopasswd
    total=$(wc -l < /etc/passwd); shell_u=$(grep -cE '/bin/(bash|sh|zsh)' /etc/passwd)
    uid0=$(awk -F: '$3==0' /etc/passwd | wc -l); locked=$(awk -F: '$2~/^!/' /etc/shadow 2>/dev/null | wc -l)
    nopasswd=$(grep -r "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -vc "^#")
    iam_th "USERS"; iam_tr "Total: ${total} | Shell: ${shell_u} | UID0: ${uid0} | Locked: ${locked}"; iam_tf; echo ""
    iam_th "PRIVILEGED GROUPS"
    for g in sudo wheel adm docker lxd root shadow; do local m; m=$(getent group "$g" 2>/dev/null | cut -d: -f4); [[ -n "$m" ]] && iam_tr "$(printf '${R}%-10s${N}: %s' "$g" "$m")"; done; iam_tf; echo ""
    iam_th "SUID (top 15)"; find / -perm -4000 -type f 2>/dev/null | head -15 | while read b; do iam_tr "${Y}${b}${N}"; done; iam_tf; echo ""
    iam_th "SUDO NOPASSWD"; iam_tr "Rules: ${nopasswd}"
    grep -r "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v "^#" | head -5 | while read l; do iam_tr "${R}⚠ ${l}${N}"; done; iam_tf; echo ""
    iam_th "PASSWORD POLICY"
    for p in PASS_MAX_DAYS PASS_MIN_DAYS PASS_MIN_LEN PASS_WARN_AGE ENCRYPT_METHOD; do
        local v; v=$(grep "^${p}" /etc/login.defs 2>/dev/null | awk '{print $2}'); [[ -z "$v" ]] && v="(default)"
        iam_tr "$(printf '%-20s: %s' "$p" "$v")"; done; iam_tf; echo ""
    iam_th "SSH CONFIG"
    [[ -f /etc/ssh/sshd_config ]] && for p in PermitRootLogin PasswordAuthentication PubkeyAuthentication MaxAuthTries; do
        local v; v=$(grep -i "^${p}" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}'); [[ -z "$v" ]] && v="(default)"
        local cl="${D}"; [[ "$p" == "PermitRootLogin" && "$v" == "yes" ]] && cl="${R}"
        iam_tr "$(printf '%b%-25s%b: %s' "$cl" "$p" "$N" "$v")"; done
    iam_tf

    # Calculate IAM score
    local score=0 max=5
    [[ $uid0 -le 1 ]] && score=$((score+1))
    [[ $nopasswd -eq 0 ]] && score=$((score+1))
    local root_login; root_login=$(grep -i "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    [[ "$root_login" != "yes" ]] && score=$((score+1))
    local sp; sp=$(stat -c '%a' /etc/shadow 2>/dev/null)
    [[ "$sp" == "640" || "$sp" == "600" ]] && score=$((score+1))
    [[ $shell_u -le 3 ]] && score=$((score+1))

    echo ""
    show_finding "$([ $score -ge 4 ] && echo LOW || ([ $score -ge 2 ] && echo MEDIUM || echo HIGH))" \
        "IAM POSTURE SCORE: ${score}/${max} — ${total} users, ${shell_u} shells, ${nopasswd} NOPASSWD"
    write_finding "IAM-15" "IAM Audit" "T1087" "COMPLETE" \
        "$([ $score -ge 4 ] && echo LOW || ([ $score -ge 2 ] && echo MEDIUM || echo HIGH))" \
        "Score=${score}/${max} Users=${total} Shell=${shell_u} UID0=${uid0} NOPASSWD=${nopasswd}" \
        "Review all HIGH/CRITICAL findings. Prioritize: UID-0 accounts, NOPASSWD rules, PermitRootLogin."
    csv_log "IAM" "audit" "score=${score}/${max}" "OK"
}

# ── ENTRY POINT ──
dlc_main() {
    module_splash "$DLC_NAME" "$DLC_DESC" "$DLC_MITRE" "$DLC_ATTACKS" "$DLC_RISK" "$DLC_ACCENT"
    CURRENT_MODULE="DLC-01-IAM"
    iam_attack_01; iam_attack_02; iam_attack_03; iam_attack_04; iam_attack_05
    iam_attack_06; iam_attack_07; iam_attack_08; iam_attack_09; iam_attack_10
    iam_attack_11; iam_attack_12; iam_attack_13; iam_attack_14; iam_attack_15
    echo ""
    echo -e "${IAM_BG}${W}                                                                              ${N}"
    echo -e "${IAM_BG}${W}  ◆ DLC-01 IAM ABUSE — COMPLETE                                              ${N}"
    echo -e "${IAM_BG}${W}                                                                              ${N}"
    local fc; fc=$(grep -c "DLC-01-IAM" "$FINDINGS_FILE" 2>/dev/null || echo 0)
    echo -e "\n  ${IAM_PL}  📊 Findings: ${fc} written to ${FINDINGS_FILE}${N}"
    echo -e "\n                              ${W}${BOLD}— X D R   C R E E P E R —${N}\n"
    csv_log "IAM" "dlc_complete" "DLC-01 finished" "OK"
}
