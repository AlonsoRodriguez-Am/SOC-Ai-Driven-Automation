# Wazuh Troubleshooting Guide

## Overview

This guide covers common issues and solutions for Wazuh deployment in the SOC Automation system.

---

## Table of Contents

1. [Service Issues](#service-issues)
2. [Agent Connection Issues](#agent-connection-issues)
3. [API Issues](#api-issues)
4. [Alert Issues](#alert-issues)
5. [Performance Issues](#performance-issues)
6. [Installation Issues](#installation-issues)
7. [Log Reference](#log-reference)

---

## Service Issues

### Wazuh Manager Not Starting

**Symptoms:** Service fails to start, no logs generated

**Diagnosis:**
```bash
# Check service status
systemctl status wazuh-manager

# Check detailed logs
journalctl -xe -u wazuh-manager

# Verify configuration syntax
/var/ossec/bin/wazuh-control check
```

**Solutions:**

1. **Check configuration:**
```bash
# Validate XML syntax
xmllint --noout /var/ossec/etc/ossec.conf
```

2. **Check port conflicts:**
```bash
ss -tlnp | grep -E '1514|1515|55000'
```

3. **Check disk space:**
```bash
df -h
```

4. **Reset and restart:**
```bash
/var/ossec/bin/wazuh-control stop
/var/ossec/bin/wazuh-control start
```

### Docker Container Not Starting

**Symptoms:** `docker-compose up` fails, containers exit immediately

**Diagnosis:**
```bash
# Check container logs
docker logs wazuh-master
docker logs wazuh-indexer
docker logs wazuh-dashboard

# Check Docker status
docker ps -a
```

**Solutions:**

1. **Check resource limits:**
```bash
# Increase memory for Docker
docker system info | grep Memory
```

2. **Check port availability:**
```bash
ss -tlnp | grep -E '443|9200|9300|55000'
```

3. **Recreate volumes:**
```bash
docker-compose down -v
docker-compose up -d
```

4. **Check certificate issues:**
```bash
# Regenerate certs
rm -rf ./data/certs/*
# Recreate needed certs or use auto-generated
```

---

## Agent Connection Issues

### Agent Not Connecting to Manager

**Symptoms:** Agent shows "not connected" in dashboard

**Diagnosis:**
```bash
# On agent - check connection
/var/ossec/bin/wazuh-control info

# On manager - check registered agents
curl -k -H "Authorization: Bearer TOKEN" https://localhost:55000/agents | jq

# Check network
telnet MANAGER_IP 1514
```

**Solutions:**

1. **Verify agent configuration:**
```bash
cat /var/ossec/etc/ossec.conf | grep -A3 "<server>"
```

2. **Check firewall on manager:**
```bash
# Allow agent ports
iptables -I INPUT -p tcp --dport 1514 -j ACCEPT
iptables -I INPUT -p tcp --dport 1515 -j ACCEPT

# Or firewalld
firewall-cmd --permanent --add-port=1514/tcp
firewall-cmd --permanent --add-port=1515/tcp
firewall-cmd --reload
```

3. **Re-register agent:**
```bash
# On manager - remove old agent
/var/ossec/bin/manage_agents -r AGENT_ID

# On agent - re-register
/var/ossec/bin/agent-auth -m MANAGER_IP -p 1515
systemctl restart wazuh-agent
```

4. **Check agent logs:**
```bash
tail -100 /var/ossec/logs/ossec.log | grep -i error
```

### Agent Registration Failed

**Symptoms:** Registration timeout or authentication error

**Diagnosis:**
```bash
# On manager - check auth settings
cat /var/ossec/etc/ossec.conf | grep -A10 "<auth>"

# Check auth daemon
ps aux | grep authd
```

**Solutions:**

1. **Enable password authentication:**
```xml
<!-- On manager ossec.conf -->
<auth>
  <use_password>yes</use_password>
  <password>AGENT_PASSWORD</password>
</auth>
```

2. **Set agent key manually:**
```bash
# On manager - get key
/var/ossec/bin/manage_agents -l
/var/ossec/bin/manage_agents -e AGENT_ID

# On agent - paste key
/var/ossec/bin/agent-auth -m MANAGER_IP -p 1515 -k "MANUAL_KEY"
```

3. **Increase timeout:**
```xml
<auth>
  <timeout>60</timeout>
</auth>
```

---

## API Issues

### API Authentication Failed

**Symptoms:** 401 Unauthorized when accessing API

**Diagnosis:**
```bash
# Test authentication
curl -k -X POST "https://localhost:55000/security/user/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"PASS"}'
```

**Solutions:**

1. **Reset admin password:**
```bash
/var/ossec/bin/manage_agents -P
```

2. **Recreate API token:**
```bash
# Login to Dashboard → Settings → API → Generate new token
```

3. **Check API configuration:**
```bash
cat /var/ossec/api/configuration/api.yaml
```

### API Returns 404

**Symptoms:** Endpoint not found

**Solutions:**

1. **Use correct endpoint format:**
```
/agents (not /agent)
/rules (not /rule)
```

2. **Check API version:**
```bash
curl -k https://localhost:55000/ | jq
```

3. **Verify service is running:**
```bash
systemctl status wazuh-api
docker ps | grep wazuh
```

### High API Latency

**Symptoms:** Slow response times

**Solutions:**

1. **Check system resources:**
```bash
top -bn1 | head -20
free -h
```

2. **Limit results:**
```bash
# Add pagination
curl -k "https://localhost:55000/agents?limit=100"
```

3. **Use filtering:**
```bash
# Only get active agents
curl -k "https://localhost:55000/agents?status=active"
```

---

## Alert Issues

### No Alerts Generated

**Symptoms:** Dashboard shows no alerts

**Diagnosis:**
```bash
# Check if alerts file exists
ls -la /var/ossec/logs/alerts/alerts.json

# Check rules are loaded
/var/ossec/bin/wazuh-control rules

# Generate test alert
logger -p auth.alert "Test authentication failure"
```

**Solutions:**

1. **Verify rules are loaded:**
```bash
/var/ossec/bin/wazuh-control rules | head -20
```

2. **Check rule syntax:**
```bash
# Test rule compilation
/var/ossec/bin/wazuh-analysisd -t
```

3. **Enable debugging:**
```bash
# Edit ossec.conf
<global>
  <logall>yes</logall>
</global>

systemctl restart wazuh-manager
```

### Alert Level Too High/Low

**Symptoms:** Too many or too few alerts

**Solutions:**

1. **Adjust rule levels:**
```xml
<!-- Increase level -->
<rule id="1001" level="12">
  <description>Changed from 7 to 12</description>
</rule>
```

2. **Filter in dashboard:**
```bash
# Use Wazuh Dashboard filters
rule.level: > 7
```

3. **Disable noisy rules:**
```xml
<rule id="501" level="0">
  <if_sid>501</if_sid>
  <hidden>yes</hidden>
</rule>
```

---

## Performance Issues

### High Memory Usage

**Symptoms:** System slow, OOM kills

**Diagnosis:**
```bash
# Check memory usage
free -h
ps aux --sort=-%mem | head -10

# Check Wazuh processes
ps aux | grep wazuh
```

**Solutions:**

1. **Reduce scan frequency:**
```xml
<syscheck>
  <frequency>86400</frequency>  <!-- Once per day -->
</syscheck>
```

2. **Reduce buffer size:**
```xml
<buffer>
  <queue_size>65536</queue_size>
  <events_per_second>100</events_per_second>
</buffer>
```

3. **Limit monitored directories:**
```xml
<directories>/etc</directories>
<!-- Remove others -->
```

4. **Disable unused modules:**
```xml
<rootcheck>
  <disabled>yes</disabled>
</rootcheck>

<vulnerability-detector>
  <disabled>yes</disabled>
</vulnerability-detector>
```

### High CPU Usage

**Symptoms:** CPU at 100%

**Solutions:**

1. **Check for rule loops:**
```bash
# Look for recursive rule matches
tail -f /var/ossec/logs/alerts/alerts.json
```

2. **Reduce log monitoring:**
```xml
<!-- Don't monitor high-volume logs -->
<localfile>
  <location>/var/log/kern.log</location>
  <only_use_event_channel>yes</only_use_event_channel>
</localfile>
```

3. **Schedule scans during off-peak:**
```xml
<syscheck>
  <scan_on_start>yes</scan_on_start>
  <frequency>86400</frequency>
  <skip_n_day>yes</skip_n_day>
</syscheck>
```

### Disk Space Full

**Symptoms:** Cannot write alerts, service stops

**Diagnosis:**
```bash
# Check disk usage
df -h

# Find large files
du -sh /var/ossec/*
```

**Solutions:**

1. **Clean old logs:**
```bash
# Archive old alerts
mv /var/ossec/logs/alerts/alerts.json /backup/alerts-$(date +%Y%m%d).json
touch /var/ossec/logs/alerts/alerts.json
chmod 660 /var/ossec/logs/alerts/alerts.json
```

2. **Enable log rotation:**
```xml
<!-- In ossec.conf -->
<global>
  <logall>yes</logall>
  <rotate_log>yes</rotate_log>
</global>
```

3. **Clean old archives:**
```bash
find /var/ossec/archives/ -type f -mtime +30 -delete
```

---

## Installation Issues

### Package Installation Fails

**Symptoms:** apt/yum install fails

**Solutions:**

1. **Update package list:**
```bash
apt-get update  # Debian/Ubuntu
yum clean all   # RHEL/CentOS
```

2. **Check repository:**
```bash
# Verify GPG key
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --import
```

3. **Fix broken packages:**
```bash
apt-get install -f   # Debian/Ubuntu
yum reinstall wazuh-manager  # RHEL
```

### Upgrade Fails

**Symptoms:** Upgrade breaks existing installation

**Solutions:**

1. **Backup before upgrade:**
```bash
tar -czvf wazuh-backup-$(date +%Y%m%d).tar.gz /var/ossec/
```

2. **Use official upgrade path:**
```bash
# Check upgrade docs for version-specific steps
# https://documentation.wazuh.com/current/upgrade-guide/
```

3. **Rollback if needed:**
```bash
# Restore from backup
tar -xzvf wazuh-backup-YYYYMMDD.tar.gz -C /
systemctl restart wazuh-manager
```

---

## Log Reference

### Key Log Locations

| Log | Location | Purpose |
|-----|----------|---------|
| Main log | `/var/ossec/logs/ossec.log` | All events |
| Alert log | `/var/ossec/logs/alerts/alerts.json` | Alert data |
| API log | `/var/ossec/logs/api.log` | API requests |
| Error log | `/var/ossec/logs/error.log` | Errors |
| Audit log | `/var/ossec/logs/audit.log` | Audit events |

### Docker Container Logs

```bash
# All containers
docker-compose logs

# Specific container
docker logs wazuh-master
docker logs -f wazuh-dashboard
```

### Common Log Patterns

**Connection error:**
```
ERROR: Unable to connect to manager
```

**Registration timeout:**
```
2026/04/04 00:00:00 agent-auth: ERROR: Timeout waiting for response
```

**Rule error:**
```
ERROR: (1230): Invalid element in the 'rules' file
```

---

## Emergency Recovery

### Complete Reset

```bash
# Stop all services
systemctl stop wazuh-manager wazuh-agent

# Backup configuration
cp -r /var/ossec/etc /var/ossec/etc.backup
cp -r /var/ossec/ruleset /var/ossec/ruleset.backup

# Clean data (CAUTION!)
rm -rf /var/ossec/var/*
rm -rf /var/ossec/logs/*

# Restart
systemctl start wazuh-manager
```

### Recovery from Backup

```bash
# Stop service
systemctl stop wazuh-manager

# Restore config
rm -rf /var/ossec/etc
cp -r /var/ossec/etc.backup /var/ossec/etc

# Restart
systemctl start wazuh-manager
```

---

## Get Help

If issues persist:

1. Check [Wazuh Documentation](https://documentation.wazuh.com/)
2. Search [Wazuh GitHub Issues](https://github.com/wazuh/wazuh/issues)
3. Check [Wazuh Community Forum](https://forum.wazuh.com/)
4. Review `/var/ossec/logs/ossec.log` for detailed errors