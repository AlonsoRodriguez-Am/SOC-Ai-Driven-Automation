# n8n Module

<div align="center">

**Workflow Automation Engine for SOC**

</div>

## Overview

n8n is the workflow orchestration engine for the SOC Automation system:
- **Workflow Creation** - Visual automation pipelines
- **Webhook Triggers** - Receive Wazuh alerts in real-time
- **API Integration** - Connect to Wazuh, Zammad, Groq AI
- **Schedule Triggers** - Poll for alerts if webhooks unavailable
- **Autonomous Response** - AI-driven CVE analysis and auto-resolution

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

1. **Option A: Standalone n8n deployment:**
```bash
cd SOC-Ai-Driven-Automation/n8n

# Copy environment template
cp ../.env.example .env
# Edit .env and set N8N_* variables

# Create directories
mkdir -p ./data

# Start n8n
docker-compose up -d
```

2. **Option B: Full SOC deployment (recommended):**
```bash
cd SOC-Ai-Driven-Automation

# Copy and configure environment
cp .env.example .env
# Edit .env with all credentials

# Deploy all services at once
./scripts/deploy.sh

# Or manually
docker-compose up -d
```

3. **Access n8n:**
- URL: http://localhost:5678
- Credentials: Set via `N8N_BASIC_AUTH_USER` and `N8N_BASIC_AUTH_PASSWORD` in .env

4. **Configure credentials:**
   See [CREDENTIALS.md](./CREDENTIALS.md) for setting up API keys and tokens.

---

## Configuration

### Docker Compose (Standalone)

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
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER:-admin}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=${N8N_WEBHOOK_URL:-http://localhost:5678/}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE:-America/New_York}
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168
      - NODE_ENV=production
    volumes:
      - ./data:/home/node/.n8n
    networks:
      - soc-net
```

### Environment Variables

See `.env.example` for all available variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `N8N_BASIC_AUTH_ACTIVE` | Enable authentication | true |
| `N8N_BASIC_AUTH_USER` | Admin username | admin |
| `N8N_BASIC_AUTH_PASSWORD` | Admin password | *(required)* |
| `N8N_HOST` | Listen host | 0.0.0.0 |
| `N8N_PORT` | Listen port | 5678 |
| `N8N_PROTOCOL` | HTTP/HTTPS | http |
| `N8N_WEBHOOK_URL` | Public webhook URL | *(required)* |
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

**Important:** See [CREDENTIALS.md](./CREDENTIALS.md) for complete setup instructions.

Create these in **Settings → Credentials**:

#### 1. Wazuh API

| Field | Value |
|-------|-------|
| Name | `wazuh-api` |
| Type | HTTP Request |
| Auth | Header |
| Header Name | `Authorization` |
| Header Value | `Bearer YOUR_TOKEN` (from WAZUH_API_PASSWORD in .env) |
| URL | `https://localhost:55000` |

#### 2. Zammad API

| Field | Value |
|-------|-------|
| Name | `zammad-api` |
| Type | HTTP Request |
| Auth | Header |
| Header Name | `Authorization` |
| Header Value | `Token token=YOUR_TOKEN` (from ZAMMAD_TOKEN in .env) |
| URL | `http://zammad:8080/api/v1` |

#### 3. Groq API

| Field | Value |
|-------|-------|
| Name | `groq-api` |
| Type | HTTP Request |
| Auth | Header |
| Header Name | `Authorization` |
| Header Value | `Bearer YOUR_GROQ_API_KEY` (from GROQ_API_KEY in .env) |
| URL | `https://api.groq.com/openai/v1/chat/completions` |

### Get Groq API Key

1. Go to [Groq Cloud](https://console.groq.com/keys)
2. Create API key
3. Copy the key to `GROQ_API_KEY` in .env

---

## Workflow Overview

### Agent 1: The Dispatcher

**Purpose:** Receive Wazuh alerts, generate summaries with CVE analysis, create tickets

**Flow:**
```
1. Webhook Trigger (POST /agent1-dispatcher)
2. Function Node (Parse alert, calculate priority)
3. HTTP Request (Call Groq AI for alert summary + CVE identification)
4. Function Node (Extract JSON from AI response)
5. HTTP Request (Create Zammad ticket with host tagging: `[WAZUH] [hostname] desc`)
6. Respond to Webhook
```

**Key Features:**
- AI identifies related CVEs for each alert type
- Provides CVE explanations and mitigations
- Uses Zammad API v2 format (group_id, customer_id, priority_id)
- Priority: ≥12 severity = P1, ≥7 = P2, else P3

### Agent 2: The Responder

**Purpose:** Deep analysis, CVE correlation, autonomous remediation

**Flow:**
```
1. Webhook Trigger (POST /agent2-responder)
2. Function Node (Parse alert data)
3. HTTP Request (Call Groq AI for deep threat analysis)
4. Function Node (Extract analysis with confidence score)
5. Function Node (Format HTML report with CVEs)
6. HTTP Request (Create/update Zammad ticket with analysis)
7. Auto-close if confidence >= 90% and not inconclusive
```

**Key Features:**
- Confidence score determines automation level
- Auto-resolves when confidence ≥80% and conclusive
- CVE analysis with host-specific mitigations
- Remediation options with confidence percentages

---

## Autonomous Response Configuration

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

### v2.x Critical Requirements

**IMPORTANT:** n8n v2.x has breaking changes from v1.x:

1. **Webhook Nodes Must Use `typeVersion: 2`**
   ```json
   {
     "type": "n8n-nodes-base.webhook",
     "typeVersion": 2,  // MUST be 2, not 1
     ...
   }
   ```

2. **API Limitations**
   - Cannot set `active`, `tags`, `updatedAt`, `versionId` via API
   - Use `/activate` endpoint to activate workflows
   - Webhook paths should be configured in the UI (keep path empty in JSON)

3. **File Access Restrictions**
   - Read Binary File node restricted to paths in `N8N_RESTRICT_FILE_ACCESS_TO`
   - Set environment variable to allow file access:
     ```yaml
     environment:
       - N8N_RESTRICT_FILE_ACCESS_TO=/home/node/.n8n-files
     ```

4. **Database Schema Changes**
   - User table requires `role` column
   - Add with: `ALTER TABLE user ADD COLUMN role varchar;`

5. **Duplicate Webhook Paths**
   - Each workflow must have unique webhook path
   - Multiple workflows with same path causes registration conflicts

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

### "Unknown resource ticket" Error

This error occurs when using the old Zammad API v1 format. The v2 format does NOT use the `ticket: {}` wrapper.

**Incorrect (v1):**
```json
{ "ticket": { "title": "Alert", "group": "Users", ... } }
```

**Correct (v2):**
```json
{ "title": "Alert", "group_id": 1, "customer_id": 2, "priority_id": 2, ... }
```

In workflow JSON files, ensure the jsonBody follows the v2 format without the `ticket` wrapper.

### Docker Network Connectivity

When n8n runs in Docker and needs to reach Zammad (also in Docker), use the host machine's Docker bridge IP instead of `localhost`:

- **Working:** `http://172.19.0.1:8080/api/v1/tickets.json`
- **Fails:** `http://localhost:8080/api/v1/tickets.json`

Find your bridge IP with: `ip addr show docker0 | grep inet`

### Database Lock Issues

If you see "Driver has already been released" errors:
1. Stop n8n: `docker stop soc-n8n`
2. Remove locks: `rm -f ./data/database.sqlite-shm ./data/database.sqlite-wal`
3. Start n8n: `docker start soc-n8n`

### API Key Placeholders

All workflow JSON files use placeholders. Configure credentials in n8n UI (see [CREDENTIALS.md](./CREDENTIALS.md)):

| Placeholder | Configure In |
|-------------|--------------|
| `INSERT_YOUR_GROQ_API_KEY` | n8n Credentials → groq-api (or set via GROQ_API_KEY in .env) |
| `INSERT_YOUR_ZAMMAD_API_TOKEN` | n8n Credentials → zammad-api (or set via ZAMMAD_TOKEN in .env) |

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

## Testing & Verification

The SOAR pipeline can be verified using the automated test suite:

```bash
python3 workflows/soc_test_suite.py
```

This suite tests:
1. **Critical CVE Auto-resolution** (Confidence threshold check)
2. **Suspicious Sudo Escalation** (Conservatism Clause check)
3. **Authentication Failure Elevation** (Priority & Host-Tagging check)

---

## Additional Resources

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Community](https://community.n8n.io/)
- [n8n Nodes](https://nodes.n8n.io/)
- [Antigravity History](workflows/antigravity_history.md)