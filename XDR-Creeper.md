# XDR CREEPER — CORE LINUX — Dokumentacja

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
  CORE LINUX | 20 wbudowanych technik ataku + DLC Loader
  Wersja: 1.0-XDR-CREEPER | Kolor: Linux Green
```

**Autor:** Daniel Budyn | daniel.budyn@greeneris.com | Greeneris  
**Wersja:** 1.0-XDR-CREEPER  
**Platforma:** Linux (bash, wymaga root)  
**Plik:** `XDR-Creeper.sh`

---

## Co to jest

`XDR-Creeper.sh` to główny launcher frameworku XDR Creeper. Zawiera: animację logo (tatuaż + robaczek), 20 wbudowanych technik ataku, interaktywne menu z numerowanym wyborem, DLC loader, CSV timeline, findings.jsonl engine i mission report.

---

## Uruchomienie

```bash
chmod +x XDR-Creeper.sh
sudo ./XDR-Creeper.sh            # Interaktywne menu
sudo ./XDR-Creeper.sh --all        # Wszystkie 20 core attacks
sudo ./XDR-Creeper.sh --dlc 01-iam-abuse  # Konkretne DLC
sudo ./XDR-Creeper.sh--list-dlc   # Lista DLC
sudo ./XDR-Creeper.sh --no-animate # Pomiń animację logo
sudo ./XDR-Creeper.sh --menu       # Wymuś menu
```

---

**Menu jest pętlą** — po zakończeniu dowolnej akcji wraca do głównego menu. Nie trzeba uruchamiać skryptu od nowa.

**Opcja 3 (DLC)** otwiera submenu z numerowaną listą:
```
   1)  IAM Abuse              (TA0001,TA0003)
   2)  Privilege Escalation   (TA0004)
   3)  Credential Harvesting  (TA0006)
   ...
  1)   Auditor — Security Report  (N/A)
   2)  ← Back to main menu
```

Wystarczy wpisać numer (np. `3`) 

---

## 20 wbudowanych ataków

| # | Atak | MITRE |
|---|------|-------|
| 01 | Preflight & Environment Profiling | N/A |
| 02 | Arsenal Setup — Tool Installation | T1588 |
| 03 | System Fingerprinting | T1082 |
| 04 | User & Group Enumeration | T1087 |
| 05 | Network Discovery (ARP + Nmap) | T1046 |
| 06 | Service & Port Enumeration | T1046 |
| 07 | Cron Job Persistence | T1053 |
| 08 | Systemd Service Persistence | T1543 |
| 09 | Backdoor User Creation | T1136 |
| 10 | Shadow File Credential Access | T1003 |
| 11 | SSH Key Harvesting | T1552 |
| 12 | Payload Download Simulation | T1105 |
| 13 | Bash History Clearing | T1070 |
| 14 | Auditd / Rsyslog Disruption | T1562 |
| 15 | Log Truncation & Poisoning | T1070 |
| 16 | Firewall Rule Modification | T1562 |
| 17 | Network Share Scanning | T1135 |
| 18 | SSH Brute Force Simulation | T1110 |
| 19 | DNS Enumeration & OSINT | T1596 |
| 20 | C2 Beaconing & Exfiltration | T1071/T1041 |

---

## Architektura plików

```
XDR Creeper/
├── linux/
│   ├── XDR-Creeper.sh        ← TEN PLIK (launcher + 20 ataków)
│   └── dlc/
│       ├── dlc-01-iam-abuse.sh      ← 15 ataków IAM
│       ├── dlc-02-privesc.sh        ← 15 ataków PrivEsc
│       ├── dlc-03-credential-harvest.sh
│       ├── dlc-04-lateral-movement.sh
│       ├── dlc-05-persistence.sh
│       ├── dlc-06-defense-evasion.sh
│       ├── dlc-07-exfiltration.sh
│       ├── dlc-08-c2-simulation.sh
│       ├── dlc-09-ad-attacks.sh
│       ├── dlc-10-cloud-azure.sh
│       ├── dlc-11-impact-destruction.sh
│       ├── dlc-12-auditor.sh        ← raport bezpieczeństwa
│       └── dlc-TEMPLATE.sh
└── docs/
    ├── XDR-Creeper.md                ← TEN DOKUMENT
    ├── DLC-01-IAM-ABUSE.md
    ├── ... (12 dokumentów DLC)
    └── DLC-12-AUDITOR.md
```

---

## Kluczowe komponenty w core

### Findings Engine
Core definiuje `write_finding()` i `show_finding()` — dostępne dla WSZYSTKICH DLC bez potrzeby redefinicji. Findings zapisywane do `/tmp/xdr-creeper/findings.jsonl`.

### DLC Loader
`load_dlc()` source'uje plik DLC, ustawia `MODULE_COLOR` na accent color z `DLC_COLORS[]`, wywołuje `dlc_main()`. Numer DLC mapowany na nazwę pliku przez `dlc_id_by_number()`.

### CSV Timeline
Każdy atak loguje do CSV: timestamp, module, phase, action, detail, status.

### Mission Report
Po zakończeniu core wyświetla: listę MITRE technik, linki do portali (security.microsoft.com, portal.azure.com, Sentinel), ścieżki do CSV + findings.jsonl.

---

## Co zostanie po teście

**Trwałe (celowe output):**
- `/tmp/xdr-creeper/timeline_YYYYMMDD_HHMMSS.csv` — CSV timeline
- `/tmp/xdr-creeper/findings.jsonl` — structured findings (append-only)
- `/tmp/xdr-creeper/loot_*.txt` — discovered credentials/paths
- `/tmp/xdr-creeper/recon_*.txt` — recon report
- Wpisy syslog (`logger -t "xdr-creeper"`)
- Wpisy syslog z useradd/userdel, chmod, setcap, etc.

**Tymczasowe (automatycznie usunięte):**
- Konta testowe (xdr_*, iam_*)
- Reguły sudoers
- Pliki SUID/capability w /tmp
- Cron jobs
- Systemd services
- Firewall rules (przywrócone)

---

## Detekcja w Microsoft Sentinel — KQL

```kusto
// ═══════════════════════════════════════════════════════════════
// WSZYSTKIE events XDR Creeper (master query)
// ═══════════════════════════════════════════════════════════════
Syslog
| where ProcessName == "xdr-creeper"
| order by TimeGenerated desc
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 01-03: Preflight / Arsenal / Fingerprint
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage has_any ("mdatp", "apt install", "nmap", "tcpdump")
| where ProcessName == "xdr-creeper" or SyslogMessage contains "xdr"
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 04: User Enumeration
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage has_any ("getent", "cat /etc/passwd", "lastlog")
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 05-06: Network & Service Discovery
// ═══════════════════════════════════════════════════════════════
SysmonEvent
| where EventID == 1 and Image has_any ("nmap", "arp-scan", "masscan", "fping")
| project TimeGenerated, Computer, CommandLine

// ═══════════════════════════════════════════════════════════════
// ATAK 07-08: Cron & Systemd Persistence
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage has_any ("crontab", "XDR_CREEPER_TEST", "systemd") 
| where SyslogMessage has_any ("REPLACE", "Created", "enable")
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 09: Backdoor User Creation (CRITICAL)
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage has_any ("useradd", "userdel") and SyslogMessage contains "xdr"
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 10: Shadow File Access
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage contains "/etc/shadow" and SyslogMessage has_any ("OPEN", "READ")
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 11: SSH Key Harvesting
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage has_any ("authorized_keys", "id_rsa", "id_ed25519", ".ssh")
| project TimeGenerated, Computer, SyslogMessage

// ═══════════════════════════════════════════════════════════════
// ATAK 12: Payload Download
// ═══════════════════════════════════════════════════════════════
SysmonEvent
| where EventID == 1 and CommandLine has_any ("curl", "wget") and CommandLine has_any ("download", "payload", "-o /tmp")
| project TimeGenerated, Computer, CommandLine

// ═══════════════════════════════════════════════════════════════
// ATAK 13-15: Anti-Forensics (history, auditd, logs)
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage has_any ("history -c", "HISTSIZE=0", "auditd", "rsyslog", "truncat", "log.*clear")
| project TimeGenerated, Computer, SyslogMessage

SysmonEvent
| where EventID == 1 and CommandLine has_any ("history -c", "systemctl stop auditd", "truncate -s 0")
| project TimeGenerated, Computer, CommandLine, User

// ═══════════════════════════════════════════════════════════════
// ATAK 16: Firewall Modification
// ═══════════════════════════════════════════════════════════════
SysmonEvent
| where EventID == 1 and CommandLine has_any ("iptables", "ufw", "firewall-cmd")
| project TimeGenerated, Computer, CommandLine, User

// ═══════════════════════════════════════════════════════════════
// ATAK 17: Network Share Scanning
// ═══════════════════════════════════════════════════════════════
SysmonEvent
| where EventID == 3 and DestinationPort in (445, 139, 2049)
| summarize count() by Computer, DestinationIp, bin(TimeGenerated, 5m)
| where count_ > 3

// ═══════════════════════════════════════════════════════════════
// ATAK 18: SSH Brute Force
// ═══════════════════════════════════════════════════════════════
Syslog
| where SyslogMessage contains "Failed password"
| summarize FailCount=count() by Computer, bin(TimeGenerated, 5m)
| where FailCount > 10

// ═══════════════════════════════════════════════════════════════
// ATAK 19: DNS Enumeration
// ═══════════════════════════════════════════════════════════════
SysmonEvent
| where EventID == 1 and CommandLine has_any ("dig", "nslookup", "host", "dnsenum")
| project TimeGenerated, Computer, CommandLine

// ═══════════════════════════════════════════════════════════════
// ATAK 20: C2 Beaconing & Exfiltration
// ═══════════════════════════════════════════════════════════════
CommonSecurityLog
| where DestinationHostName has_any ("httpbin.org", "example.com", "ifconfig.me", "icanhazip.com")
| summarize count() by DestinationHostName, Computer, bin(TimeGenerated, 10m)
| where count_ > 3

// ═══════════════════════════════════════════════════════════════
// MASTER: Full attack timeline
// ═══════════════════════════════════════════════════════════════
Syslog
| where ProcessName == "xdr-creeper" or SyslogMessage contains "xdr-creeper"
| extend Phase = extract("(PREFLIGHT|ARSENAL|FINGERPRINT|USERS|NETWORK|SERVICE|CRON|SYSTEMD|BACKDOOR|SHADOW|SSH|PAYLOAD|HISTORY|AUDIT|LOG|FIREWALL|SHARE|BRUTE|DNS|C2|COMPLETE)", 1, SyslogMessage)
| project TimeGenerated, Computer, Phase, SyslogMessage
| order by TimeGenerated asc
```

---

## Pełny flow

```
                         ┌─────────────────┐
                         │  ANIMATED INTRO  │
                         │  Tattoo + Bug    │
                         └────────┬────────┘
                                  │
                         ┌────────▼────────┐
                         │ INTERACTIVE MENU │◄────────────┐
                         │  1-5 + Exit(0)  │             │
                         └────────┬────────┘             │
                           ┌──────┼──────┐               │
                     ┌─────▼─┐ ┌──▼──┐ ┌─▼────┐         │
                     │Core 20│ │DLC  │ │Full   │         │
                     │attacks│ │1-12 │ │assault│         │
                     └───┬───┘ └──┬──┘ └───┬───┘         │
                         │        │        │              │
                         ▼        ▼        ▼              │
                    ┌─────────────────────────┐           │
                    │    findings.jsonl        │           │
                    │    (append-only)         │           │
                    └────────────┬────────────┘           │
                                 │                        │
                    ┌────────────▼────────────┐           │
                    │   DLC-12: AUDITOR       │           │
                    │   Terminal + HTML report │           │
                    └─────────────────────────┘           │
                                                          │
                    Press ENTER → back to menu ───────────┘
```

---

**— X D R   C R E E P E R —**
