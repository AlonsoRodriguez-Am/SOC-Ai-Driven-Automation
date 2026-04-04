# Troubleshooting Guide

## Overview

This guide covers general troubleshooting steps for the SOC Automation system.

---

## Table of Contents

1. [General Diagnostics](#general-diagnostics)
2. [Service-Specific Issues](#service-specific-issues)
3. [Network Issues](#network-issues)
4. [Data Flow Issues](#data-flow-issues)
5. [Performance Issues](#performance-issues)

---

## General Diagnostics

### Check All Services

```bash
# Docker containers
docker ps -a

# System services
systemctl status wazuh-manager

# Port availability
ss -tlnp
```

### View All Logs

```bash
# All Docker containers
docker-compose logs -f

# Specific service
docker-compose logs -f n8n
```

### Check Resources

```bash
# CPU and memory
top -bn1 | head -15

# Disk space
df -h

# Docker resources
docker system df
```

---

## Service-Specific Issues

### Wazuh

**Service not starting:**
```bash
systemctl status wazuh-manager
journalctl -xe -u wazuh-manager
tail -100 /var/ossec/logs/ossec.log
```

**API not responding:**
```bash
curl -k https://localhost:55000/
systemctl status wazuh-api
```

**No alerts generating:**
```bash
tail -20 /var/ossec/logs/alerts/alerts.json
/var/ossec/bin/wazuh-control rules
```

### n8n

**UI not accessible:**
```bash
docker logs soc-n8n
docker exec soc-n8n curl localhost:5678
```

**Workflow not triggering:**
- Check workflow is ACTIVE
- Check webhook URL

**Credentials not working:**
- Verify credentials exist in Settings → Credentials
- Test API manually

### Zammad

**Initialization taking too long:**
```bash
docker-compose logs -f zammad-railsserver
docker logs soc-zammad-zammad-init-1
```

**API returning 401:**
```bash
# Verify token
curl -H "Authorization: Token token=YOUR_TOKEN" \
  http://localhost:8080/api/v1/users/me
```

**Assets returning 404:**
```bash
# Wait for initialization or restart
docker-compose restart zammad-railsserver
```

---

## Network Issues

### Container Network

```bash
# Check network
docker network ls
docker network inspect soc-net

# Test connectivity between containers
docker exec soc-n8n curl -s http://zammad-nginx:8080
```

### Port Conflicts

```bash
# Find what's using a port
ss -tlnp | grep <port>

# Common ports
# 443 - Wazuh Dashboard
# 5678 - n8n
# 8080 - Zammad
# 9200 - Elasticsearch
# 55000 - Wazuh API
```

---

## Data Flow Issues

### Wazuh → n8n

**Alert not reaching n8n:**
```bash
# Check forwarder
python3 /opt/soc-automation/scripts/wazuh-alert-forwarder.py

# Check cron
crontab -l | grep wazuh

# Check logs
tail -50 /opt/soc-automation/logs/forwarder.log
```

### n8n → Zammad

**Ticket not created:**
- Check Zammad API credentials
- Verify group exists (SOC-Alerts)
- Check n8n execution logs

### n8n → Gemini

**AI not responding:**
- Verify API key is valid
- Check API quota
- Check network connectivity

---

## Performance Issues

### High CPU Usage

```bash
# Find process
top -bn1

# Docker stats
docker stats
```

### High Memory Usage

```bash
# Check memory
free -h

# Docker memory
docker stats --no-stream
```

### Disk Full

```bash
# Find large files
du -sh /var/*

# Clean logs
docker system prune -a
```

---

## Emergency Recovery

### Complete System Restart

```bash
# Stop all
docker-compose down
systemctl stop wazuh-manager

# Wait 10 seconds
sleep 10

# Start all
systemctl start wazuh-manager
docker-compose up -d
```

### Reset Everything (CAUTION!)

```bash
# This deletes all data
docker-compose down -v
rm -rf ./data/*
docker-compose up -d
```

---

## Get Help

If issues persist after troubleshooting:

1. Review service-specific documentation:
   - [Wazuh Troubleshooting](../wazuh/troubleshooting.md)
   - [Zammad Troubleshooting](../zammad/troubleshooting.md)
   - [n8n Troubleshooting](../n8n/troubleshooting.md)

2. Check logs for detailed error messages

3. Verify all configuration files are correct