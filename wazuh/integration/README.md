# Wazuh Alert Integration Guide

## Overview

This guide explains how to integrate Wazuh alerts with the SOC Automation system (n8n workflow engine). The integration forwards alerts from Wazuh to n8n for automated processing.

---

## Table of Contents

1. [Integration Architecture](#integration-architecture)
2. [Alert Forwarder Script](#alert-forwarder-script)
3. [n8n Webhook Configuration](#n8n-webhook-configuration)
4. [Alternative Integration Methods](#alternative-integration-methods)
5. [Testing the Integration](#testing-the-integration)
6. [Troubleshooting](#troubleshooting)

---

## Integration Architecture

```
┌──────────────┐      ┌─────────────────┐      ┌─────────────┐
│    WAZUH     │      │  Alert Forwarder │     │     n8n     │
│   (Source)   │─────▶│  (Python Script) │────▶│   Webhook   │
│              │      │    + Cron        │     │   Trigger   │
│ alerts.json  │      │                  │     │             │
└──────────────┘      └─────────────────┘      └─────────────┘
                                                         │
                                                         ▼
                                                 ┌─────────────┐
                                                 │   Process   │
                                                 │  Alert + AI │
                                                 └─────────────┘
```

### Data Flow

1. **Wazuh** generates security alerts and writes to `alerts.json`
2. **Alert Forwarder** (cron job) reads new alerts since last position
3. **Forwarder** sends JSON payload to n8n webhook endpoint
4. **n8n** receives alert, processes through workflow
5. **Workflow** creates Zammad ticket, sends notifications

---

## Alert Forwarder Script

### Location

`SOC-Ai-Driven-Automation/scripts/wazuh-alert-forwarder.py`

### Features

- Tracks last processed position in alerts.json
- Only forwards new alerts (non-duplicate)
- Configurable via environment variables
- Handles connection errors gracefully
- Logs all actions for debugging

### Configuration

Edit these variables in the script:

```python
# n8n webhook URL (required)
N8N_WEBHOOK_URL = 'http://localhost:5678/webhook/wazuh-alert'

# Wazuh alerts file location
WAZUH_ALERTS_FILE = '/var/ossec/logs/alerts/alerts.json'

# State file (tracks last processed position)
STATE_FILE = '/opt/soc-automation/logs/last_processed_pos'

# Log file
LOG_FILE = '/opt/soc-automation/logs/forwarder.log'

# Alert level threshold (only forward >= this level)
MIN_ALERT_LEVEL = 5

# HTTP timeout (seconds)
HTTP_TIMEOUT = 30
```

### Installation

1. **Copy script to appropriate location:**
```bash
mkdir -p /opt/soc-automation/scripts
cp wazuh-alert-forwarder.py /opt/soc-automation/scripts/
chmod +x /opt/soc-automation/scripts/wazuh-alert-forwarder.py
```

2. **Test script manually:**
```bash
python3 /opt/soc-automation/scripts/wazuh-alert-forwarder.py
```

3. **Set up cron job:**
```bash
# Add to crontab - runs every minute
crontab -e

# Add this line:
* * * * * /usr/bin/python3 /opt/soc-automation/scripts/wazuh-alert-forwarder.py >> /var/log/wazuh-forwarder.log 2>&1
```

4. **Verify cron is running:**
```bash
crontab -l | grep wazuh
```

---

## n8n Webhook Configuration

### Create Webhook Trigger

1. **Open n8n** at http://localhost:5678
2. **Create new workflow**
3. **Add Webhook node:**
   - Set Webhook URL path (e.g., `wazuh-alert`)
   - Set HTTP Method to `POST`
   - Set Response Mode to "on received"
4. **Test webhook** - n8n will provide a test URL
5. **Activate** the workflow

### Sample Workflow Flow

```
Webhook Trigger (POST /wazuh-alert)
    │
    ▼
HTTP Request Node (Fetch additional data from Wazuh API)
    │
    ▼
Function Node (Parse and format alert)
    │
    ▼
HTTP Request (Call Gemini AI for analysis)
    │
    ▼
Function Node (Generate alert brief)
    │
    ▼
HTTP Request (Create Zammad ticket)
    │
    ▼
HTTP Request (Send email notification)
    │
    ▼
Respond to Webhook (200 OK)
```

### Webhook Payload Example

The forwarder sends this JSON to n8n:

```json
{
  "timestamp": "2026-04-03T19:02:59.062-0500",
  "rule": {
    "level": 7,
    "description": "Host-based anomaly detection event (rootcheck)",
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
  "location": "/var/log/syslog",
  "source": "wazuh-forwarder"
}
```

---

## Alternative Integration Methods

### Method 1: n8n Schedule Trigger (Polling)

If webhooks are problematic, use schedule trigger:

1. **Create workflow with Schedule Trigger**
   - Set to run every 1-5 minutes
2. **Read alerts file:**
   ```json
   {
     "n8n": {
       "node": "Read Binary File",
       "parameters": {
         "filePath": "/path/to/alerts.json"
       }
     }
   }
   ```
3. **Compare with last run** to find new alerts
4. **Process each new alert**

### Method 2: Wazuh Integration Module

Use Wazuh's built-in webhook integration:

1. **Configure ossec.conf:**
```xml
<integration>
  <name>webhook</name>
  <hook_url>http://n8n-host:5678/webhook/wazuh-alert</hook_url>
  <level>7</level>
  <alert_format>json</alert_format>
</integration>
```

2. **Restart Wazuh:**
```bash
systemctl restart wazuh-manager
```

### Method 3: Wazuh API Polling

Use n8n to poll Wazuh API directly:

1. **Get API token:**
```bash
TOKEN=$(curl -s -k -X POST "https://localhost:55000/security/user/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"PASS"}' | jq -r '.token')
```

2. **Query events:**
```bash
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://localhost:55000/events?search=rule.level:>5&limit=100"
```

---

## Testing the Integration

### 1. Test Forwarder Script

```bash
# Run manually
python3 /opt/soc-automation/scripts/wazuh-alert-forwarder.py

# Check logs
tail -50 /opt/soc-automation/logs/forwarder.log
```

### 2. Test n8n Webhook

```bash
# Send test alert
curl -X POST http://localhost:5678/webhook/wazuh-alert \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2026-04-04T00:00:00.000-0500",
    "rule": {
      "level": 10,
      "description": "Test alert",
      "id": "999999",
      "groups": ["test"]
    },
    "agent": {
      "id": "000",
      "name": "test-agent"
    },
    "full_log": "Test alert for integration verification"
  }'
```

### 3. Check n8n Executions

1. Open n8n UI
2. Go to **Executions** tab
3. Find your webhook execution
4. Check for errors

### 4. Generate Test Alert in Wazuh

```bash
# Trigger a test rule
logger -p auth.alert "Test alert from logger - authentication failure"

# Or use the Wazuh testing tool
/var/ossec/bin/wazuh-testing-tool --help
```

---

## Troubleshooting

### Forwarder Not Sending Alerts

**Symptoms:** No alerts forwarded to n8n

**Solutions:**
```bash
# 1. Check cron is running
systemctl status cron
crontab -l | grep wazuh

# 2. Verify alerts file exists
ls -la /var/ossec/logs/alerts/alerts.json

# 3. Check forwarder logs
tail -50 /opt/soc-automation/logs/forwarder.log

# 4. Test forwarder manually
python3 /opt/soc-automation/scripts/wazuh-alert-forwarder.py -v

# 5. Verify n8n is reachable from script
curl -I http://localhost:5678
```

### n8n Webhook Not Found

**Symptoms:** "Webhook not found" error

**Solutions:**
```bash
# 1. Check workflow is ACTIVE in n8n UI
# Workflow toggle must be ON

# 2. Verify webhook path matches
# Forwarder URL: http://localhost:5678/webhook/wazuh-alert
# n8n Webhook path: wazuh-alert

# 3. Restart n8n to ensure webhook registered
docker restart soc-n8n
```

### Alerts Not Processing

**Symptoms:** Alerts received but not creating tickets

**Solutions:**
1. Check n8n workflow is correct
2. Verify credentials (Zammad API token, Gmail SMTP)
3. Check execution logs in n8n UI
4. Test API endpoints manually

### Memory/Performance Issues

**Symptoms:** Forwarder slow or timing out

**Solutions:**
```python
# Reduce batch size in forwarder
MAX_BATCH_SIZE = 10  # Process 10 alerts at a time

# Increase HTTP timeout
HTTP_TIMEOUT = 60

# Add rate limiting
TIME_BETWEEN_REQUESTS = 1.0  # seconds
```

---

## Alert Level Mapping

| Level | Description | Forward to n8n? |
|-------|-------------|-----------------|
| 0 | Debug | No |
| 1-3 | Informational | No |
| 4 | Low | Optional |
| 5-7 | Medium | Yes (Recommended) |
| 8-12 | High | Yes |
| 13-15 | Critical | Yes (Immediate) |

Configure `MIN_ALERT_LEVEL` in forwarder script to filter.

---

## Log Files

| File | Location | Purpose |
|------|----------|---------|
| Forwarder log | `/opt/soc-automation/logs/forwarder.log` | Forwarder activity |
| Wazuh main log | `/var/ossec/logs/ossec.log` | All Wazuh events |
| Wazuh alerts | `/var/ossec/logs/alerts/alerts.json` | Alert data |
| n8n executions | n8n UI → Executions | Workflow runs |

---

## Security Considerations

1. **HTTPS for Production:** Use HTTPS for n8n webhook URL in production
2. **API Token Security:** Store Wazuh API token securely
3. **Network Segmentation:** Keep services on isolated network
4. **Log Rotation:** Configure log rotation for forwarder logs
5. **Rate Limiting:** Prevent alert flooding with rate limits

---

## Next Steps

After configuring alert integration:

1. [Set up Agent 1 workflow in n8n](../n8n/workflows/README.md)
2. [Configure Zammad for ticket creation](../zammad/README.md)
3. [Set up email notifications](email-notifications.md)
4. [Configure Gemini AI integration](gemini-integration.md)