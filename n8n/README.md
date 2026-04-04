# n8n Module

<div align="center">

**Workflow Automation Engine for SOC**

</div>

## Overview

n8n is the workflow orchestration engine for the SOC Automation system:
- **Workflow Creation** - Visual automation pipelines
- **Webhook Triggers** - Receive Wazuh alerts in real-time
- **API Integration** - Connect to Wazuh, Zammad, Gemini
- **Schedule Triggers** - Poll for alerts if webhooks unavailable

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Credentials](#credentials)
5. [Workflow Overview](#workflow-overview)
6. [Webhook Configuration](#webhook-configuration)
7. [Troubleshooting](#troubleshooting)
8. [Backup & Restore](#backup--restore)

---

## Prerequisites

### System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 2 GB | 4 GB |
| CPU | 1 core | 2 cores |
| Disk | 10 GB | 20 GB |

### Software

- Docker Engine 20.10+
- Docker Compose v2+

### Required Ports

| Port | Service |
|------|---------|
| 5678 | n8n HTTP |

---

## Installation

### Quick Start (Docker)

1. **Navigate to n8n module:**
```bash
cd SOC-Ai-Driven-Automation/n8n
```

2. **Create directories:**
```bash
mkdir -p ./data
```

3. **Start n8n:**
```bash
docker-compose up -d
```

4. **Access n8n:**
- URL: http://localhost:5678
- Credentials: Set via environment variables

---

## Configuration

### Docker Compose

```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: soc-n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=SOC_Automation_2026!
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://localhost:5678/
      - GENERIC_TIMEZONE=America/New_York
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168
      - NODE_ENV=production
    volumes:
      - ./data:/home/node/.n8n
    networks:
      - soc-net
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `N8N_BASIC_AUTH_ACTIVE` | Enable authentication | true |
| `N8N_BASIC_AUTH_USER` | Admin username | admin |
| `N8N_BASIC_AUTH_PASSWORD` | Admin password | *(required)* |
| `N8N_HOST` | Listen host | 0.0.0.0 |
| `N8N_PORT` | Listen port | 5678 |
| `N8N_PROTOCOL` | HTTP/HTTPS | http |
| `WEBHOOK_URL` | Public webhook URL | *(required)* |
| `GENERIC_TIMEZONE` | Timezone | America/New_York |
| `EXECUTIONS_DATA_PRUNE` | Auto-prune logs | true |
| `EXECUTIONS_DATA_MAX_AGE` | Log retention (hours) | 168 |

### SSL Configuration (Production)

```yaml
# Add SSL volumes
volumes:
  - ./ssl:/home/node/.n8n/ssl

# Add environment
environment:
  - N8N_PROTOCOL=https
  - WEBHOOK_URL=https://your-domain.com/
```

---

## Credentials

### Required Credentials in n8n

Create these in **Settings → Credentials**:

#### 1. Wazuh API

| Field | Value |
|-------|-------|
| Name | `wazuh-api` |
| Type | HTTP Request |
| Auth | Header |
| Header Name | `Authorization` |
| Header Value | `Bearer YOUR_TOKEN` |
| URL | `https://localhost:55000` |

#### 2. Zammad API

| Field | Value |
|-------|-------|
| Name | `zammad-api` |
| Type | HTTP Request |
| Auth | Header |
| Header Name | `Authorization` |
| Header Value | `Token token=YOUR_TOKEN` |
| URL | `http://localhost:8080/api/v1` |

#### 3. Gemini API

| Field | Value |
|-------|-------|
| Name | `gemini-api` |
| Type | HTTP Request |
| Auth | Query Parameter |
| Query Parameter Name | `key` |
| Query Parameter Value | `YOUR_API_KEY` |
| URL | `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent` |

#### 4. Gmail SMTP

| Field | Value |
|-------|-------|
| Name | `gmail-smtp` |
| Type | Email (SMTP) |
| Host | `smtp.gmail.com` |
| Port | `587` |
| User | `your-email@gmail.com` |
| Password | `YOUR_APP_PASSWORD` |
| TLS | `true` |

### Get Wazuh API Token

```bash
TOKEN=$(curl -s -k -X POST "https://localhost:55000/security/user/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"YOUR_PASSWORD"}' | jq -r '.token')

echo $TOKEN
```

### Get Zammad API Token

1. Login to Zammad
2. Go to **Settings → API**
3. Click **Add Token**
4. Copy the generated token

### Get Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create API key
3. Copy the key

---

## Workflow Overview

### Agent 1: The Dispatcher

**Purpose:** Receive Wazuh alerts, generate summaries, create tickets

**Flow:**
```
1. Webhook Trigger (POST /wazuh-alert)
2. Function Node (Parse alert)
3. HTTP Request (Get additional context from Wazuh API)
4. HTTP Request (Call Gemini AI for alert summary)
5. Function Node (Format ticket data)
6. HTTP Request (Create Zammad ticket)
7. Email Node (Send notification)
8. Respond to Webhook
```

### Agent 2: The Responder

**Purpose:** Deep analysis, MITRE mapping, remediation proposal

**Flow:**
```
1. Schedule Trigger (Every 5 minutes)
2. HTTP Request (Get pending tickets from Zammad)
3. Loop over tickets
4. HTTP Request (Get alert details from Wazuh)
5. HTTP Request (Call Gemini for analysis)
6. Function Node (Format analysis results)
7. HTTP Request (Update Zammad ticket)
8. If Confidence > 80%: Wait for approval
9. IF Approved: Execute remediation
10. Update ticket with results
```

---

## Webhook Configuration

### Create Webhook

1. Open n8n UI
2. Create new workflow
3. Add **Webhook** node
4. Set:
   - **Path:** `wazuh-alert`
   - **Method:** `POST`
   - **Response Mode:** "on received"
5. Click **Create Webhook**
6. Copy the webhook URL

### Test Webhook

```bash
# Send test alert
curl -X POST http://localhost:5678/webhook/wazuh-alert \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2026-04-04T00:00:00-0500",
    "rule": {
      "level": 10,
      "description": "Test Alert",
      "id": "999999",
      "groups": ["test"],
      "mitre": {"id": ["T1110"], "tactic": ["Brute Force"]}
    },
    "agent": {"id": "001", "name": "test-agent"},
    "full_log": "Test alert for webhook verification"
  }'
```

### Alternative: Schedule Trigger

If webhooks don't work:

1. Add **Schedule Trigger** node
2. Set to run every 1-5 minutes
3. Add **Read Binary File** node (for alerts.json)
4. Process alerts in a loop

---

## Troubleshooting

### n8n Not Starting

```bash
# Check logs
docker logs soc-n8n

# Check volume
ls -la ./data

# Fix permissions
chmod -R 777 ./data
```

### Webhook Not Found

```bash
# Make sure workflow is ACTIVE
# In n8n UI: Toggle workflow ON

# Restart n8n
docker restart soc-n8n
```

### v2.x API Issues

Important notes for n8n v2.x:
- Cannot set `active`, `tags`, `updatedAt`, `versionId` via API
- Use node type `n8n-nodes-base.webhook`
- Create workflows via UI, not API import

### File Access Issues

In n8n v2.x, Read Binary File only accesses:
```
/home/node/.n8n-files
```

**Solution:**
```bash
mkdir -p ./data/n8n-files
cp /var/ossec/logs/alerts/alerts.json ./data/n8n-files/
```

### Memory Issues

```yaml
# Add to docker-compose
environment:
  - NODE_OPTIONS=--max-old-space-size=2048
```

### Timeout Issues

```yaml
environment:
  - EXECUTIONS_TIMEOUT=600
  - EXECUTIONS_TIMEOUT_MAX=3600
```

---

## Backup & Restore

### Backup

```bash
# Stop n8n
docker stop soc-n8n

# Backup data directory
tar -czvf n8n-backup-$(date +%Y%m%d).tar.gz ./data

# Start n8n
docker start soc-n8n
```

### Restore

```bash
# Stop n8n
docker stop soc-n8n

# Restore data
rm -rf ./data/*
tar -xzvf n8n-backup-YYYYMMDD.tar.gz -C ./

# Start n8n
docker start soc-n8n
```

---

## Workflow Templates

### Agent 1: Basic Alert Dispatcher

See: [`workflows/agent1-dispatcher.json`](workflows/agent1-dispatcher.json)

### Agent 2: Deep Analysis Responder

See: [`workflows/agent2-responder.json`](workflows/agent2-responder.json)

---

## Next Steps

1. [Configure Credentials](#credentials)
2. [Import Workflow Templates](workflows/README.md)
3. [Test Webhook Integration](#webhook-configuration)
4. [Integrate with Wazuh Alerts](../wazuh/integration/README.md)
5. [Integrate with Zammad Tickets](../zammad/README.md)

---

## Additional Resources

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Community](https://community.n8n.io/)
- [n8n Nodes](https://nodes.n8n.io/)