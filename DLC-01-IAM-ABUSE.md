# DLC-01: IAM ABUSE — Dokumentacja modułu

```
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

  XDR CREEPER — Offensive Simulation Framework
  DLC-01: IAM ABUSE | Identity & Access Management
  Kolor akcentu: Fioletowy (Purple) | MITRE: TA0001 TA0003 TA0004 TA0006
```

**Autor:** Daniel Budyn | newlife-org@proton.me | NEWLIFE  
**Wersja:** 2.0 (z findings.jsonl )  
**Platforma:** Linux (bash, wymaga root)  
**Uruchomienie:** `sudo ./newlife-core-linux.sh --dlc 01-iam-abuse`

---

## Cel modułu

Moduł IAM Abuse testuje bezpieczeństwo zarządzania tożsamością i uprawnieniami na systemach Linux. Symuluje **15 technik ataku** skupionych na tworzeniu kont, eskalacji uprawnień, manipulacji poświadczeniami i rekonesansie tożsamości.

Każdy atak:
- Wyświetla **edukacyjny blok 📖** tłumaczący co robi i dlaczego jest niebezpieczny
- Generuje **telemetrię** widoczną dla Microsoft Sentinel i Defender for Endpoint
- Zapisuje **structured finding** do `findings.jsonl` (z severity, rekomendacją, MITRE ID)
- Wyświetla **ocenę severity** na ekranie (⛔ CRITICAL, 🔴 HIGH, 🟡 MEDIUM, 🔵 LOW)
- **Sprząta po sobie** — wszystkie zmiany są odwracalne w sekundach

Atak 15 oblicza **IAM POSTURE SCORE** (0-5) — sumaryczną ocenę bezpieczeństwa tożsamości.

---

## Raportowanie — findings.jsonl

Każdy atak zapisuje wynik do `/tmp/xdr-creeper/findings.jsonl` w formacie JSON Lines:

```json
{"module":"DLC-01-IAM","timestamp":"2026-04-09T12:00:00Z","attack_id":"IAM-03",
 "technique":"UID-0 Clone","mitre_id":"T1078.003","result":"EXECUTED",
 "severity":"CRITICAL","details":"xdr_shadow_root created with UID=0",
 "recommendation":"Monitor UID-0 accounts other than root"}
```

Plik jest **append-only** — wszystkie moduły (DLC-01 do DLC-11) dopisują swoje wyniki. Moduł **DLC-12 Auditor** agreguje je w raport z checkboxami, scoringiem i priorytetami, generując zarówno kolorowy output terminalowy jak i HTML raport do wysłania klientowi.

---

## Opis ataków

### 01. Tworzenie kont lokalnych
**MITRE:** T1136.001 | **Severity:** HIGH  
**Co robi:** Tworzy 3 konta testowe z `/bin/bash` i hasłem `Password123!`. Usuwa po 3s.  
**Dlaczego:** Atakujący tworzą konta żeby przetrwać załatanie wektora wejścia. Nazwa naśladująca serwis (`svc_admin`, `backup_op`) wygląda legitnie.  
**Co dalej:** Konto → SSH login → persistence → eskalacja → lateral movement.

### 02. Injekcja do grup uprzywilejowanych
**MITRE:** T1098.001 | **Severity:** HIGH  
**Co robi:** Dodaje test user do 8 grup: sudo, wheel, adm, docker, lxd, shadow, disk, root.  
**Dlaczego:** docker = root escape, lxd = privileged container, shadow = offline crack, disk = raw read.  
**Co dalej:** `docker run -v /:/host` = root na hoście.

### 03. UID-0 Clone — Shadow Root
**MITRE:** T1078.003 | **Severity:** CRITICAL  
**Co robi:** Tworzy konto z UID=0 (identyczne uprawnienia co root, inna nazwa).  
**Dlaczego:** Narzędzia szukające "root" nie znajdą "xdr_shadow_root". Technika rootkitów.  
**Finding:** CRITICAL jeśli system pozwolił, LOW jeśli zablokował.

### 04. Osłabienie polityki haseł
**MITRE:** T1201 / T1556 | **Severity:** CRITICAL  
**Co robi:** Zmienia PASS_MIN_LEN=1, PASS_MAX_DAYS=99999. Przywraca natychmiast.  
**Dlaczego:** Słaba polityka → hasła "a" akceptowalne, nigdy nie wygasają.

### 05. Sondowanie PAM
**MITRE:** T1556.003 | **Severity:** MEDIUM/LOW  
**Co robi:** Enumeruje PAM. Szuka pam_permit.so i nullok. Symulacja w /tmp.  
**Dlaczego:** `pam_permit.so` w sshd = login bez hasła.

### 06. Sudoers NOPASSWD Injection
**MITRE:** T1548.003 | **Severity:** HIGH  
**Co robi:** Tworzy drop-in NOPASSWD. Skanuje istniejące reguły. Usuwa po 4s.  
**Dlaczego:** NOPASSWD = root bez pytania. Przetrwa zmianę hasła.

### 07. SSH Key Injection
**MITRE:** T1098.004 | **Severity:** HIGH  
**Co robi:** Inject fałszywego klucza, restore po 1s.  
**Dlaczego:** SSH key backdoor przetrwa zmianę hasła, lockout, nawet MFA.

### 08. Service Account Creation
**MITRE:** T1136.001 | **Severity:** MEDIUM  
**Co robi:** Konto z nologin + demo `su -s /bin/bash` bypass.  
**Dlaczego:** "nologin" nie chroni — cron i su go obchodzą.

### 09. Account Lock/Unlock
**MITRE:** T1531 | **Severity:** MEDIUM  
**Co robi:** Lock → status → unlock → usunięcie.  
**Dlaczego:** Atakujący blokuje WSZYSTKICH oprócz swojego backdoora.

### 10. /etc/passwd Analysis
**MITRE:** T1087.001 | **Severity:** zależy od UID-0 count  
**Co robi:** Read-only diagnostyka: accounts, shells, UID-0, perms.

### 11. NSSwitch Tampering
**MITRE:** T1556 | **Severity:** HIGH  
**Co robi:** Dodaje `ldap` do nsswitch. Przywraca natychmiast.  
**Dlaczego:** Rogue LDAP = phantom users kontrolowani przez atakującego.

### 12. Kerberos Harvest
**MITRE:** T1558 | **Severity:** HIGH jeśli znaleziono  
**Co robi:** Skanuje .keytab i krb5cc_*. Read-only.

### 13. SSSD/LDAP/AD Enumeration
**MITRE:** T1087.002 | **Severity:** HIGH jeśli domain-joined  
**Co robi:** Sprawdza SSSD, LDAP, Samba, realm. Zasilaj DLC-09 AD.

### 14. Token & Credential Cache
**MITRE:** T1528 | **Severity:** HIGH jeśli cache znaleziony  
**Co robi:** Skanuje ~/.azure, ~/.aws, ~/.kube, ~/.docker, ~/.netrc.

### 15. IAM Posture Score
**MITRE:** T1087 | **Severity:** wyliczany  
**Co robi:** Pełny audyt. Score 0-5 na podstawie: UID-0, NOPASSWD, PermitRootLogin, shadow perms, shell count.

---

## Macierz wpływu

| # | Atak | Severity | Modyfikuje? | Czas | Odwracalny? |
|---|------|----------|-------------|------|-------------|
| 01 | Konta lokalne | HIGH | /etc/passwd | 3s | ✅ userdel |
| 02 | Grupy | HIGH | /etc/group | 4s | ✅ userdel |
| 03 | UID-0 clone | CRITICAL | /etc/passwd | 4s | ✅ backup |
| 04 | Policy | CRITICAL | /etc/login.defs | 3s | ✅ backup |
| 05 | PAM | MEDIUM | /tmp only | 2s | ✅ rm |
| 06 | Sudo | HIGH | /etc/sudoers.d | 4s | ✅ rm |
| 07 | SSH keys | HIGH | authorized_keys | 1s | ✅ backup |
| 08 | Service acct | MEDIUM | /etc/passwd | 2s | ✅ userdel |
| 09 | Lock/unlock | MEDIUM | /etc/shadow | 2s | ✅ userdel |
| 10 | Passwd scan | varies | **nic** | — | ✅ read-only |
| 11 | NSSwitch | HIGH | nsswitch.conf | 3s | ✅ backup |
| 12 | Kerberos | varies | **nic** | — | ✅ read-only |
| 13 | SSSD/AD | varies | **nic** | — | ✅ read-only |
| 14 | Tokens | varies | **nic** | — | ✅ read-only |
| 15 | Audit | varies | **nic** | — | ✅ read-only |

---

## Co zostanie po teście

**Trwałe (celowe):** findings.jsonl, CSV timeline, wpisy syslog (useradd/userdel/logger).  
**Tymczasowe:** Nic — wszystkie artefakty usunięte automatycznie.

---

## Czyszczenie awaryjne (Ctrl+C)

```bash
for u in iam_svc_admin iam_backup_op iam_helpdesk iam_grp_test xdr_shadow_root iam_svc_test iam_lock_test; do
    userdel -r "$u" 2>/dev/null; done
sed -i '/^xdr_\|^iam_/d' /etc/passwd 2>/dev/null
rm -f /etc/sudoers.d/99-xdr-creeper-test /tmp/.xdr_pam_sim
for f in /etc/passwd.xdr_bak /etc/login.defs.xdr_bak /etc/nsswitch.conf.xdr_bak; do
    [[ -f "$f" ]] && mv "$f" "${f%.xdr_bak}"; done
find /home /root -name "*.xdr_bak" 2>/dev/null | while read f; do mv "$f" "${f%.xdr_bak}"; done
```

---

## Detekcja w Microsoft Sentinel — KQL per atak

```kusto
// ═══════════════════════════════════════════════════════════════
// ATAK 01: Tworzenie kont lokalnych
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage has_any ("useradd", "adduser")
| where SyslogMessage has_any ("iam_svc", "iam_backup", "iam_helpdesk")
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 02: Injekcja do grup uprzywilejowanych
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage contains "usermod" and SyslogMessage contains "-aG"
| where SyslogMessage has_any ("sudo", "wheel", "docker", "lxd", "shadow", "disk")
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 03: UID-0 Clone (KRYTYCZNY — drugie konto root)
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage contains "useradd" and SyslogMessage contains "uid=0"
| where SyslogMessage !contains "root"
| project TimeGenerated, Computer, SyslogMessage

// Alternatywnie: szukaj DOWOLNEGO konta z UID=0 w syslog
Syslog
| where SyslogMessage contains "shadow_root" or SyslogMessage contains "xdr_shadow"
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 04: Osłabienie polityki haseł
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage contains "login.defs" or SyslogMessage contains "PASSWORD POLICY"
| project TimeGenerated, Computer, SyslogMessage

// Auditd: modyfikacja pliku
Syslog
| where SyslogMessage contains "login.defs" and SyslogMessage contains "WRITE"
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 05: Sondowanie PAM
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage contains "pam_permit" or SyslogMessage contains "PAM backdoor"
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 06: Sudoers NOPASSWD Injection
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage contains "NOPASSWD" or SyslogMessage contains "sudoers.d"
| project TimeGenerated, Computer, SyslogMessage

// Szukaj nowych plików w sudoers.d
Syslog
| where SyslogMessage contains "/etc/sudoers.d/" and SyslogMessage has_any ("CREATE", "WRITE", "OPEN")
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 07: SSH Authorized Keys Injection
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage contains "authorized_keys"
| project TimeGenerated, Computer, SyslogMessage

// Auditd: modyfikacja authorized_keys
Syslog
| where SyslogMessage contains "authorized_keys" and SyslogMessage has_any ("WRITE", "OPEN")
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 08: Service Account Creation
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage contains "useradd" and SyslogMessage contains "nologin"
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 09: Account Lock/Unlock
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage has_any ("passwd -l", "passwd -u", "account locked", "account unlocked")
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 10: /etc/passwd & /etc/shadow Access
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage has_any ("/etc/shadow", "/etc/passwd") and SyslogMessage contains "OPEN"
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 11: NSSwitch Tampering
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage contains "nsswitch" or SyslogMessage contains "NSSWITCH"
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 12: Kerberos Ticket Harvest
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage has_any ("krb5cc_", "keytab", "kerberos", "kinit", "klist")
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 13: SSSD/LDAP/AD Enumeration
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage has_any ("sssd", "ldap", "realm", "samba", "winbind")
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 14: Token & Credential Cache
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage has_any (".azure", ".aws/credentials", ".kube/config", ".docker/config")
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 15: IAM Audit Summary
// ═══════════════════════════════════════════════════════════════
Syslog
| where ProcessName == "xdr-creeper" and SyslogMessage contains "IAM"
| project TimeGenerated, Computer, SyslogMessage
| order by TimeGenerated desc

// ═══════════════════════════════════════════════════════════════
// MASTER QUERY: Wszystkie findings DLC-01
// ═══════════════════════════════════════════════════════════════
Syslog
| where ProcessName == "xdr-creeper-iam" or (ProcessName == "xdr-creeper" and SyslogMessage contains "IAM")
| order by TimeGenerated desc
| project TimeGenerated, Computer, SyslogMessage
```

---

## Ścieżki eskalacji

```
IAM Abuse (DLC-01) → DLC-02 PrivEsc   (sudo → SUID/capability abuse)
                   → DLC-04 Lateral    (SSH keys → pivot do innych maszyn)
                   → DLC-05 Persist    (konta → cron/systemd persistence)
                   → DLC-09 AD         (SSSD/Kerberos → domain attacks)
                   → DLC-10 Cloud      (token caches → Azure/AWS abuse)
```

---

**— X D R   C R E E P E R —**
