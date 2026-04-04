# Wazuh Agent Deployment Guide

## Overview

Wazuh agents are deployed on endpoints to collect security data and forward it to the Wazuh manager for analysis. This guide covers deployment on Linux, Windows, and macOS.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Prerequisites](#prerequisites)
3. [Linux Deployment](#linux-deployment)
4. [Windows Deployment](#windows-deployment)
5. [macOS Deployment](#macos-deployment)
6. [Agent Management](#agent-management)
7. [Configuration Options](#configuration-options)
8. [Security Hardening](#security-hardening)
9. [Troubleshooting](#troubleshooting)

---

## Architecture

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│   Endpoint   │         │   Wazuh      │         │    Wazuh     │
│   (Agent)    │────────▶│   Manager    │────────▶│   Indexer    │
│              │  TLS    │              │  API   │              │
│              │  1514   │              │  55000 │              │
└──────────────┘         └──────────────┘         └──────────────┘
```

### Agent Functions

- **Log Collection**: Gather logs from files, syslog, Windows Event Log
- **File Integrity Monitoring**: Detect file changes
- **Rootkit Detection**: Identify rootkits and malware
- **System Auditing**: Monitor commands and user activity
- **Vulnerability Detection**: Scan for known vulnerabilities
- **Configuration Assessment**: Check security compliance

---

## Prerequisites

### Manager Requirements

1. Wazuh Manager must be running
2. Agent registration port (1515) must be accessible
3. Agent communication port (1514) must be accessible

### Network Requirements

| Port | Protocol | Purpose |
|------|----------|---------|
| 1514/UDP | Agent-Mgr | Agent data |
| 1515/TCP | Agent-Mgr | Agent registration |
| 22/TCP | SSH | Remote management |

### Verify Manager Readiness

```bash
# Check Wazuh is running
systemctl status wazuh-manager

# Verify ports are listening
ss -tlnp | grep -E '1514|1515'

# Check registration is enabled
cat /var/ossec/etc/ossec.conf | grep -A5 "<auth"
```

---

## Linux Deployment

### Option 1: Automated Script (Recommended)

```bash
# Download and run deployment script
curl -sO https://raw.githubusercontent.com/wazuh/wazuh/master/packages/generators/agent-install.sh
chmod +x agent-install.sh
./agent-install.sh -m MANAGER_IP -a
```

### Option 2: Manual Installation

#### Step 1: Add Wazuh Repository

**Debian/Ubuntu:**
```bash
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
apt-get update
```

**RHEL/CentOS/AlmaLinux:**
```bash
cat > /etc/yum.repos.d/wazuh.repo << 'EOF'
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
priority=1
EOF
yum install epel-release -y
```

#### Step 2: Install Agent

**Debian/Ubuntu:**
```bash
apt-get install wazuh-agent
```

**RHEL/CentOS:**
```bash
yum install wazuh-agent
```

#### Step 3: Configure Agent

Edit `/var/ossec/etc/ossec.conf`:

```xml
<ossec_config>
  <client>
    <server>
      <address>MANAGER_IP_ADDRESS</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
  </client>
</ossec_config>
```

#### Step 4: Register Agent

**On Manager:**
```bash
# Add agent
/var/ossec/bin/manage_agents -a

# List agents to get ID
/var/ossec/bin/manage_agents -l
```

**On Agent:**
```bash
# Register with manager
/var/ossec/bin/agent-auth -m MANAGER_IP -p 1515
```

#### Step 5: Start Agent

```bash
systemctl enable wazuh-agent
systemctl start wazuh-agent
systemctl status wazuh-agent
```

---

## Windows Deployment

### System Requirements

| Requirement | Minimum |
|-------------|---------|
| OS | Windows 10/11, Server 2016+ |
| RAM | 512 MB |
| Disk | 1 GB |
| CPU | 1 core |

### Installation Methods

#### Method 1: GUI Installer

1. **Download Agent:**
   - From Wazuh Dashboard: Agents → Deploy new agent
   - Direct: https://packages.wazuh.com/4.x/windows/wazuh-agent.msi

2. **Run Installer:**
   - Double-click `wazuh-agent.msi`
   - Follow the wizard

3. **Configure:**
   - Manager IP: `YOUR_MANAGER_IP`
   - Agent Name: `HOSTNAME`

4. **Start Service:**
   - Open Services
   - Find "Wazuh"
   - Start service

#### Method 2: Command Line (Silent Install)

```powershell
# Download agent
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent.msi" -OutFile "wazuh-agent.msi"

# Install silently
msi.exe /i wazuh-agent.msi /quiet WAZUH_MANAGER_IP=192.168.1.100 WAZUH_MANAGER_PORT=1514 WAZUH_AGENT_NAME=windows-client

# Start service
Start-Service Wazuh
```

#### Method 3: PowerShell Script

```powershell
# Create install script
$managerIP = "192.168.1.100"
$agentName = $env:COMPUTERNAME

# Download and install
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent.msi" -OutFile "$env:TEMP\wazuh-agent.msi"
Start-Process msiexec -Wait -ArgumentList "/i $env:TEMP\wazuh-agent.msi /qn WAZUH_MANAGER_IP=$managerIP WAZUH_MANAGER_PORT=1514 WAZUH_AGENT_NAME=$agentName"

# Start
Start-Service Wazuh
```

### Post-Installation

```powershell
# Check status
Get-Service Wazuh

# View logs
Get-Content C:\Program Files (x86)\ossec-agent\logs\ossec.log

# Restart if needed
Restart-Service Wazuh
```

---

## macOS Deployment

### System Requirements

- macOS 10.13 (High Sierra) or later
- Intel or Apple Silicon (M1/M2)

### Installation

```bash
# Download agent
curl -o wazuh-agent.pkg https://packages.wazuh.com/4.x/macos/wazuh-agent.pkg

# Install
sudo installer -pkg wazuh-agent.pkg -target /

# Configure
sudo /Library/Ossec/bin/wazuh-control stop

# Edit configuration
sudo vim /var/ossec/etc/ossec.conf

# Set manager address:
# <server>
#   <address>MANAGER_IP</address>
#   <port>1514</port>
# </server>

# Register
sudo /Library/Ossec/bin/agent-auth -m MANAGER_IP -p 1515

# Start
sudo /Library/Ossec/bin/wazuh-control start
```

### Commands

```bash
# Status
sudo /Library/Ossec/bin/wazuh-control info
sudo /Library/Ossec/bin/wazuh-control status

# Stop/Start
sudo /Library/Ossec/bin/wazuh-control stop
sudo /Library/Ossec/bin/wazuh-control start

# Restart
sudo /Library/Ossec/bin/wazuh-control restart
```

---

## Agent Management

### On Manager - List Agents

```bash
# Via CLI
/var/ossec/bin/manage_agents -l

# Via API
TOKEN=$(curl -s -k -X POST "https://localhost:55000/security/user/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"PASS"}' | jq -r '.token')

curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:55000/agents | jq
```

### Restart Agent

**Linux:**
```bash
systemctl restart wazuh-agent
```

**Windows (PowerShell):**
```powershell
Restart-Service Wazuh
```

**macOS:**
```bash
sudo /Library/Ossec/bin/wazuh-control restart
```

### Remove Agent

**On Manager:**
```bash
# Remove by ID
/var/ossec/bin/manage_agents -r 001

# Remove all
for id in $(/var/ossec/bin/manage_agents -l | grep "ID:" | awk '{print $2}'); do
  /var/ossec/bin/manage_agents -r $id
done
```

### Upgrade Agent

**Linux:**
```bash
apt-get update
apt-get install wazuh-agent
```

**Windows:**
```powershell
# Download and run MSI (same as install)
```

---

## Configuration Options

### File Integrity Monitoring (FIM)

```xml
<syscheck>
  <disabled>no</disabled>
  <frequency>43200</frequency>
  <scan_on_start>yes</scan_on_start>
  
  <!-- Directories to monitor -->
  <directories>/etc,/usr/bin,/usr/sbin</directories>
  <directories>/bin,/sbin</directories>
  
  <!-- Real-time monitoring -->
  <directories realtime="yes">/etc,/var/www</directories>
  
  <!-- Ignore files -->
  <ignore>/etc/mtab</ignore>
  <ignore>/etc/hosts.deny</ignore>
</syscheck>
```

### Rootkit Detection

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
  <frequency>43200</frequency>
</rootcheck>
```

### Log Collection

```xml
<!-- Syslog -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/syslog</location>
</localfile>

<!-- Apache -->
<localfile>
  <log_format>apache</log_format>
  <location>/var/log/apache2/access.log</location>
</localfile>

<!-- Command output -->
<localfile>
  <log_format>command</log_format>
  <command>df -P</command>
  <frequency>360</frequency>
</localfile>

<!-- Windows Event Log -->
<localfile>
  <log_format>eventlog</log_format>
  <location>Security</location>
</localfile>
```

### Agent Buffer

```xml
<buffer>
  <disabled>no</disabled>
  <queue_size>131072</queue_size>
  <events_per_second>500</events_per_second>
</buffer>
```

---

## Security Hardening

### SSL/TLS Encryption

```xml
<crypto_control>
  <type>aes</type>
  <size>256</size>
</crypto_control>
```

### Agent Authentication

On manager, enable password authentication:

```xml
<auth>
  <disabled>no</disabled>
  <port>1515</port>
  <use_source_ip>no</use_source_ip>
  <purge>yes</purge>
  <use_password>yes</use_password>
  <ciphers>HIGH:!ADH:!EXP:!MD5:!RC4</ciphers>
</auth>
```

Then set agent password:
```bash
/var/ossec/bin/manage_agents -e
```

### Firewall Rules

```bash
# Allow agent communication (on manager)
iptables -A INPUT -p tcp --dport 1514 -j ACCEPT
iptables -A INPUT -p tcp --dport 1515 -j ACCEPT

# Or firewalld
firewall-cmd --permanent --add-port=1514/tcp
firewall-cmd --permanent --add-port=1515/tcp
```

---

---

## Testing Machine: vulnerable-machine

This is a designated vulnerable machine for security testing and stress testing.

### Agent Details

| Field | Value |
|-------|-------|
| Agent ID | 004 |
| Hostname | vulnerable-machine |
| IP | 100.70.191.1 (Tailscale) |
| Agent Key | `38f74b8717ac74d5dfab0eb087b173d9213c948ef27f886226fef919ddef5598` |

### Connection Steps

On the vulnerable-machine:

```bash
# Install Wazuh agent (if not installed)
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
apt-get update
apt-get install -y wazuh-agent
```

Configure `/var/ossec/etc/ossec.conf` with manager IP:

```xml
<client>
  <server>
    <address>MANAGER_TAILSALE_IP</address>
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
</client>
```

Register and start:

```bash
/var/ossec/bin/agent-auth -m <MANAGER_IP> -p 1515
systemctl enable wazuh-agent
systemctl start wazuh-agent
/var/ossec/bin/wazuh-control status
```

### Quick Connect Script

Use the provided scripts:
- `install-vulnerable-machine.sh` - Full installation
- `connect-agent.sh` - Quick connection

### Verification

On manager:
```bash
/var/ossec/bin/manage_agents -l
```

Should show: `ID: 004, Name: vulnerable-machine, IP: any`

---

## Troubleshooting

### Agent Not Connecting

**Check network:**
```bash
telnet MANAGER_IP 1514
telnet MANAGER_IP 1515
```

**Check logs:**
```bash
# Linux
tail -50 /var/ossec/logs/ossec.log

# Windows
Get-Content C:\Program Files (x86)\ossec-agent\logs\ossec.log | Select -Last 50
```

**Verify configuration:**
```bash
/var/ossec/bin/wazuh-control info
```

### Registration Failed

```bash
# On manager - check auth is enabled
cat /var/ossec/etc/ossec.conf | grep -A3 "<auth>"

# On agent - try manual registration
/var/ossec/bin/agent-auth -m MANAGER_IP -p 1515 -v
```

### High Memory Usage

Reduce buffer size:
```xml
<buffer>
  <queue_size>65536</queue_size>
  <events_per_second>200</events_per_second>
</buffer>
```

### Agent Crashing

Enable debug mode:
```bash
echo "1" > /var/ossec/etc/debug
systemctl restart wazuh-agent
tail -100 /var/ossec/logs/ossec.log
```

---

## Groups and Configuration

### Create Agent Group

```bash
# Create group
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"web-servers"}' \
  https://localhost:55000/groups
```

### Assign Agent to Group

```bash
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  https://localhost:55000/groups/web-servers/agents/001
```

### Group-Specific Configuration

Create shared configuration in `/var/ossec/etc/shared/`:

```xml
<!-- /var/ossec/etc/shared/web-servers/syscheck.xml -->
<ossec_config>
  <syscheck>
    <frequency>21600</frequency>
    <directories>/var/www/html</directories>
  </syscheck>
</ossec_config>
```

---

## Auto-Deployment (Mass)

### Using Ansible

```yaml
- name: Deploy Wazuh Agent
  hosts: all
  tasks:
    - name: Add Wazuh repo
      apt_repository:
        repo: "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main"
        state: present

    - name: Install Wazuh Agent
      apt:
        name: wazuh-agent
        update_cache: yes

    - name: Configure Agent
      template:
        src: ossec.conf.j2
        dest: /var/ossec/etc/ossec.conf

    - name: Register Agent
      command: /var/ossec/bin/agent-auth -m {{ manager_ip }} -p 1515

    - name: Start Wazuh Agent
      service:
        name: wazuh-agent
        state: started
        enabled: yes
```

---

## Next Steps

1. [Configure Custom Agent Settings](#configuration-options)
2. [Set up Agent Groups](#groups-and-configuration)
3. [Configure Active Response](active-response.md)
4. [Integrate with SOC Automation](integration/README.md)