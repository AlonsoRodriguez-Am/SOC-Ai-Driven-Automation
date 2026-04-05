# Wazuh Module

<div align="center">

**Enterprise-Grade Security Information and Event Management (SIEM)**

</div>

## Overview

Wazuh serves as the **Source of Truth** for the SOC Automation system. It provides:
- Real-time threat detection
- Log analysis and correlation
- File integrity monitoring
- Rootkit detection
- Vulnerability assessment
- Active response capabilities

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Alert Integration](#alert-integration)
5. [Agent Deployment](#agent-deployment)
6. [API Reference](#api-reference)
7. [Active Response](#active-response)
8. [Troubleshooting](#troubleshooting)
9. [Backup & Restore](#backup--restore)

---

## Prerequisites

### System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 4 GB | 8 GB |
| CPU | 2 cores | 4 cores |
| Disk | 40 GB | 100 GB |
| OS | Ubuntu 20.04+ / Kali Linux | Ubuntu 22.04+ |

### Required Ports

| Port | Service | Protocol |
|------|---------|----------|
| 1514 | Agent communication | TCP/UDP |
| 1515 | Agent registration | TCP |
| 443 | Wazuh Dashboard | HTTPS |
| 55000 | Wazuh API | HTTPS |
| 9200 | Wazuh Indexer | HTTP |
| 9300 | Indexer nodes | HTTP |

### Software Dependencies

- Docker Engine 20.10+
- Docker Compose v2+
- 4 GB RAM available

### Lab Target Machine (Vulnerable)

The system is tested against a dedicated vulnerable machine for forensic analysis:

| Field | Value |
|-------|-------|
| IP Address | `192.168.0.15` |
| Agent ID   | `004` |
| Agent Name | `vulnerable` |
| OS         | Ubuntu 22.04 |
| Purpose    | Red Team Testing (Nmap, Brute Force) |

---

## Installation

### Quick Start (Docker Deployment)

1. **Navigate to the wazuh module:**
```bash
cd SOC-Ai-Driven-Automation/wazuh
```

2. **Create required directories:**
```bash
mkdir -p ./data/{indexer,master,worker,etc,certs}
mkdir -p ./logs
```

3. **Start Wazuh stack:**
```bash
docker-compose up -d
```

4. **Verify services:**
```bash
docker ps | grep wazuh
```

5. **Access Wazuh Dashboard:**
- URL: https://localhost:443
- Username: `admin`
- Password: `(see credentials-guide.md)`

### Manual Installation (Non-Docker)

For standalone installation:

1. **Add Wazuh repository:**
```bash
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
apt-get update
```

2. **Install Wazuh Manager:**
```bash
apt-get install wazuh-manager
```

3. **Start services:**
```bash
systemctl start wazuh-manager
systemctl enable wazuh-manager
```

---

## Configuration

### Main Configuration File

Location: `/var/ossec/etc/ossec.conf`

#### Basic Configuration Example

```xml
<ossec_config>
  <!-- Global settings -->
  <global>
    <jsonout_output>yes</jsonout_output>
    <alerts_log>yes</alerts_log>
    <logall>yes</logall>
  </global>

  <!-- Rules configuration -->
  <rules>
    <include>ruleset/rules.xml</include>
    <include>ruleset/rules/*.xml</include>
    <include>etc/rules/*.xml</include>
  </rules>

  <!-- Syscheck configuration -->
  <syscheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>
    <scan_on_start>yes</scan_on_start>
    <directories>/etc,/usr/bin,/usr/sbin</directories>
  </syscheck>

  <!-- Rootcheck configuration -->
  <rootcheck>
    <disabled>no</disabled>
    <check_files>yes</check_files>
    <check_trojans>yes</check_trojans>
    <frequency>43200</frequency>
  </rootcheck>

  <!-- Localfile for logging -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>

  <!-- Active response -->
  <active-response>
    <disabled>no</disabled>
  </active-response>
</ossec_config>
```

### Network Configuration

#### Connecting Agents

```xml
<client>
  <server>
    <address>WAZUH_MANAGER_IP</address>
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
</client>
```

### Alert Severity Levels

| Level | Description | Action |
|-------|-------------|--------|
| 0 | None | Debug logging |
| 1-4 | Low | Informational |
| 5-7 | Medium | Forward to SOC |
| 8-12 | High | Immediate review |
| 13-15 | Critical | Emergency response |

### Custom Rules

Create custom rules in `/var/ossec/etc/rules/local_rules.xml`:

```xml
<group name="soc,custom">
  <!-- SSH brute force detection -->
  <rule id="100001" level="10">
    <if_sid>5716</if_sid>
    <match>authentication failure</match>
    <frequency>5</frequency>
    <time_frame>10m</time_frame>
    <description>Possible SSH brute force attack</description>
    <mitre>
      <id>T1110</id>
      <tactic>Brute Force</tactic>
    </mitre>
  </rule>

  <!-- Suspicious process execution -->
  <rule id="100002" level="12">
    <if_sid>100000</if_sid>
    <match>suspicious</match>
    <description>Suspicious process execution detected</description>
    <mitre>
      <id>T1059</id>
      <tactic>Execution</tactic>
    </mitre>
  </rule>
</group>
```

---

## Alert Integration

### Alert Format

Wazuh generates JSON alerts in `/var/ossec/logs/alerts/alerts.json`:

```json
{
  "timestamp": "2026-04-03T19:02:59.062-0500",
  "rule": {
    "level": 7,
    "description": "Host-based anomaly detection event",
    "id": "510",
    "groups": ["ossec", "rootcheck"],
    "mitre": {
      "id": ["T1548"],
      "tactic": ["Privilege Escalation"],
      "technique": ["Abuse Elevation Control Mechanism"]
    }
  },
  "agent": {
    "id": "000",
    "name": "server-01"
  },
  "manager": {
    "name": "wazuh-manager"
  },
  "full_log": "Trojaned version of file detected...",
  "data": {
    "title": "Trojaned version of file detected",
    "file": "/bin/passwd"
  },
  "location": "/var/log/syslog"
}
```

### Integration Methods

#### Method 1: Cron-Based Forwarding (Recommended)

The `wazuh-alert-forwarder.py` script forwards alerts to n8n:

1. **Configure the forwarder:**
```bash
# Edit the script and set your n8n webhook URL
N8N_WEBHOOK_URL='http://localhost:5678/webhook/your-webhook'
```

2. **Set up cron job:**
```bash
# Add to crontab (runs every minute)
* * * * * /opt/soc-automation/scripts/wazuh-alert-forwarder.py
```

3. **Script location:**
```bash
# See SOC-Ai-Driven-Automation/scripts/wazuh-alert-forwarder.py
```

#### Method 2: Webhook Integration

Configure Wazuh to send alerts via webhook:

```xml
<integration>
  <name>webhook</name>
  <hook_url>http://n8n-host:5678/webhook/wazuh-alerts</hook_url>
  <level>7</level>
  <alert_format>json</alert_format>
</integration>
```

#### Method 3: API Polling

Use n8n to poll the Wazuh API:

```bash
# API endpoint for alerts
GET https://localhost:55000/events?search=rule.level:>5
```

---

## Agent Deployment

### Linux Agent (Debian/Ubuntu)

1. **Add repository:**
```bash
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
apt-get update
```

2. **Install agent:**
```bash
apt-get install wazuh-agent
```

3. **Configure manager:**
```bash
# Edit /var/ossec/etc/ossec.conf
<client>
  <server>
    <address>MANAGER_IP</address>
    <port>1514</port>
  </server>
</client>
```

4. **Register and start:**
```bash
# On manager, generate agent key first
/var/ossec/bin/manage_agents -a

# On agent
/var/ossec/bin/agent-auth -m MANAGER_IP -p 1515
systemctl enable wazuh-agent
systemctl start wazuh-agent
```

### Windows Agent

1. **Download:** Get installer from Wazuh Dashboard
2. **Install:** Run the MSI installer
3. **Configure:** Enter manager IP during installation
4. **Service:** The agent starts automatically

### macOS Agent

```bash
# Download and install
curl -o wazuh-agent.pkg https://packages.wazuh.com/4.x/macos/wazuh-agent.pkg
sudo installer -pkg wazuh-agent.pkg -target /

# Configure
sudo /Library/Ossec/bin/wazuh-control start
```

### Agent Configuration Options

#### File Integrity Monitoring

```xml
<syscheck>
  <disabled>no</disabled>
  <frequency>43200</frequency>
  <scan_on_start>yes</scan_on_start>
  <directories realtime="yes">/etc,/var/www</directories>
  <ignore>/etc/mtab</ignore>
  <file_size_limit>100MB</file_size_limit>
</syscheck>
```

#### Rootkit Detection

```xml
<rootcheck>
  <disabled>no</disabled>
  <check_files>yes</check_files>
  <check_trojans>yes</check_trojans>
  <check_dev>yes</check_dev>
  <check_sys>yes</check_sys>
  <check_pids>yes</check_pids>
  <check_ports>yes</check_ports>
  <check_if>yes</check_if>
</rootcheck>
```

---

## API Reference

### Authentication

```bash
# Get API token
TOKEN=$(curl -s -k -X POST "https://localhost:55000/security/user/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"YOUR_PASSWORD"}' \
  | jq -r '.token')

echo $TOKEN
```

### Key Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/security/user/authenticate` | POST | Get authentication token |
| `/agents` | GET | List all agents |
| `/agents/{id}` | GET | Get agent details |
| `/agents/{id}/key` | GET | Get agent key |
| `/agents/{id}/restart` | PUT | Restart agent |
| `/rules` | GET | List detection rules |
| `/rules/{id}` | GET | Get rule details |
| `/decoders` | GET | List decoders |
| `/active-response` | PUT | Execute active response |
| `/syscheck` | GET | Get file integrity data |
| `/rootcheck` | GET | Get rootcheck results |
| `/stats` | GET | Get system statistics |

### Example Usage

```bash
# List all agents
curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:55000/agents | jq

# Get specific agent
curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:55000/agents/001 | jq

# List rules
curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:55000/rules | jq

# Get security events
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://localhost:55000/events?limit=10" | jq
```

---

## Active Response

### Configuration

Add to `ossec.conf`:

```xml
<active-response>
  <disabled>no</disabled>
  <command>firewall-drop</command>
  <location>local</location>
  <rules_id>1001,1002,1003</rules_id>
</active-response>
```

### Available Commands

| Command | Action | Use Case |
|---------|--------|-----------|
| `firewall-drop` | Block IP via iptables | Network attacks |
| `host-deny` | Add to /etc/hosts.deny | Brute force |
| `disable-account` | Disable user account | Compromised account |
| `restart-wazuh` | Restart Wazuh | Service issues |

### Custom Active Response Script

Create custom script in `/var/ossec/active-response/bin/`:

```bash
#!/bin/bash
# Custom response script
ACTION=$1
USER=$2
IP=$3

case "$ACTION" in
  add)
    # Action when triggered
    logger "Blocking $IP due to suspicious activity"
    ;;
  delete)
    # Action when cleared
    logger "Unblocking $IP"
    ;;
esac
```

---

## Troubleshooting

### Service Not Starting

```bash
# Check service status
systemctl status wazuh-manager

# Check logs
tail -100 /var/ossec/logs/ossec.log

# Verify configuration
/var/ossec/bin/wazuh-control info
```

### Agent Not Connecting

```bash
# Check network connectivity
telnet MANAGER_IP 1514

# Verify agent configuration
cat /var/ossec/etc/ossec.conf | grep -A 5 "<server>"

# Check registration
/var/ossec/bin/manage_agents -l

# View agent logs
tail -50 /var/ossec/logs/ossec.log
```

### API Authentication Failed

```bash
# Test API manually
curl -k -X POST "https://localhost:55000/security/user/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"YOUR_PASSWORD"}'

# Reset admin password
/var/ossec/bin/manage_agents -P
```

### Alerts Not Generating

```bash
# Verify rules are loaded
/var/ossec/bin/wazuh-control rules

# Test rule trigger
logger "test alert from logger"

# Check alert file
tail -20 /var/ossec/logs/alerts/alerts.json
```

### High Memory Usage

```bash
# Check memory
free -h

# Reduce buffer size in ossec.conf
<buffer>
  <queue_size>65536</queue_size>
  <events_per_second>500</events_per_second>
</buffer>

# Restart manager
systemctl restart wazuh-manager
```

---

## Backup & Restore

### Backup

```bash
# Backup configuration
tar -czvf wazuh-config-$(date +%Y%m%d).tar.gz /var/ossec/etc/

# Backup rules
tar -czvf wazuh-rules-$(date +%Y%m%d).tar.gz /var/ossec/ruleset/

# Backup alerts (optional)
cp /var/ossec/logs/alerts/alerts.json /backup/alerts-$(date +%Y%m%d).json
```

### Restore

```bash
# Restore configuration
tar -xzvf wazuh-config-YYYYMMDD.tar.gz -C /

# Restore rules
tar -xzvf wazuh-rules-YYYYMMDD.tar.gz -C /

# Restart services
systemctl restart wazuh-manager
```

---

## Security Considerations

1. **Change default passwords** - Update all default credentials
2. **Enable SSL/TLS** - Use certificates for all communications
3. **Restrict API access** - Limit API access to specific IPs
4. **Regular updates** - Keep Wazuh updated
5. **Log retention** - Configure appropriate log retention
6. **Backup strategy** - Regular automated backups

---

## Next Steps

After installing Wazuh:

1. [Configure Alert Integration](./integration/README.md)
2. [Deploy Wazuh Agents](./agents/README.md)
3. [Set up Custom Rules](#custom-rules)
4. [Configure Active Response](#active-response)
5. [Integrate with n8n workflow](../n8n/README.md)

---

## Additional Resources

- [Official Wazuh Documentation](https://documentation.wazuh.com/)
- [Wazuh RESTful API](https://documentation.wazuh.com/current/user-manual/api/index.html)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [Wazuh Ruleset](https://github.com/wazuh/wazuh/tree/master/ruleset)

---

## 🧪 Custom Rules & Forensic Testing

### Custom Rules Configuration

To detect specific lab activity, add the following to `/var/ossec/etc/rules/local_rules.xml`:

```xml
<!-- Higher frequency detection for SSH brute force -->
<group name="syslog,sshd,">
  <rule id="100001" level="5">
    <if_sid>5710</if_sid>
    <description>Lab: SSH authentication failure frequent.</description>
    <group>authentication_failed,pci_dss_10.2.4,pci_dss_10.2.5,</group>
  </rule>
</group>
```

**Note:** Alerts generated with level 5+ are automatically picked up by the n8n poller and elevated to Priority 2.

### Forensic Simulation

To trigger a forensic investigation in the SOAR pipeline, perform a brute-force simulation against the target machine:

```bash
# Example Hydra attack (external to lab)
hydra -l admin -P /usr/share/wordlists/rockyou.txt ssh://192.168.0.15 -t 4
```

Check the Wazuh Dashboard and Zammad for the incoming `[WAZUH] [vulnerable]` ticket.