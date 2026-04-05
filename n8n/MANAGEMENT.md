# n8n Workflow Management Guide

This document describes how to properly manage, test, and deploy n8n workflow JSON files for the SOC Automation project.

## Overview

The SOC Automation project uses n8n to orchestrate alerts from Wazuh SIEM through AI analysis (Groq) and ticketing (Zammad).

### Workflow Files Location
```
/home/blueteam/repositories/SOC-Ai-Driven-Automation/n8n/workflows/
```

### Workflow Files
- `wazuh-alert-poller.json` - Main webhook receiving Wazuh alerts
- `agent1-dispatcher.json` - First tier AI analysis (summarization)
- `agent2-responder.json` - Second tier AI analysis (deep threat analysis)

---

## Making Changes to Workflow JSON Files

### 1. Edit the JSON File

```bash
# Navigate to workflow folder
cd /home/blueteam/repositories/SOC-Ai-Driven-Automation/n8n/workflows/

# Edit with your preferred editor
nano wazuh-alert-poller.json
# or
vim wazuh-alert-poller.json
```

### 2. Important: Add HTTP Method to HTTP Request Nodes

When adding or modifying HTTP Request nodes, you MUST include the `method` parameter:

```json
{
  "parameters": {
    "method": "POST",
    "url": "https://api.groq.com/openai/v1/chat/completions",
    ...
  }
}
```

Without `method: "POST"`, n8n defaults to GET, causing "Unknown request URL" errors.

### 3. Re-import Workflow

1. Open n8n UI: http://localhost:5678
2. Navigate to Workflows
3. Delete the existing workflow
4. Import the modified JSON file
5. Activate the workflow

---

## Testing Webhooks

### Start n8n (if stopped)
```bash
cd /home/blueteam/repositories/SOC-Ai-Driven-Automation/n8n/
docker-compose up -d
```

### Stop n8n
```bash
cd /home/blueteam/repositories/SOC-Ai-Driven-Automation/n8n/
docker-compose down
```

### Test Webhook via curl

**Wazuh Alert Poller:**
```bash
curl -X POST http://localhost:5678/webhook/wazuh-alert \
  -H "Content-Type: application/json" \
  -d '{
    "rule": {"level": 7, "id": "100", "description": "Test Alert"},
    "agent": {"name": "test-host"},
    "data": {"srcip": "1.1.1.1"}
  }'
```

**Agent 1 Dispatcher:**
```bash
curl -X POST http://localhost:5678/webhook/agent1-dispatcher \
  -H "Content-Type: application/json" \
  -d '{
    "rule": {"level": 7, "id": "100", "description": "Test Alert"},
    "agent": {"name": "test-host"},
    "data": {"srcip": "1.1.1.1"}
  }'
```

**Agent 2 Responder:**
```bash
curl -X POST http://localhost:5678/webhook/agent2-responder \
  -H "Content-Type: application/json" \
  -d '{
    "rule": {"level": 7, "id": "100", "description": "Test Alert"},
    "agent": {"name": "test-host"},
    "data": {"srcip": "1.1.1.1"}
  }'
```

### Check Execution Status

```bash
# View n8n logs
docker logs soc-n8n --tail 50

# Check database for execution status
sqlite3 /opt/soc-automation/n8n/data/database.sqlite \
  "SELECT id, workflowId, status, startedAt FROM execution_entity ORDER BY id DESC LIMIT 5;"
```

---

## Troubleshooting

### "Error in workflow"

Check n8n logs for specific error:
```bash
docker logs soc-n8n --tail 30
```

### "Active version not found"

This usually means the workflow database is out of sync. Fix by:
1. Deactivate workflow in n8n UI
2. Delete workflow
3. Re-import JSON file
4. Activate workflow

### "Unknown request URL: GET /..."

The HTTP Request node is missing `method: "POST"`. Edit the JSON file and add the method parameter.

### Database issues

Clean the database (remove all workflows):
```bash
sqlite3 /opt/soc-automation/n8n/data/database.sqlite "
DELETE FROM webhook_entity;
DELETE FROM workflow_published_version;
DELETE FROM workflow_entity;
DELETE FROM workflow_history;
DELETE FROM shared_workflow;
"
docker restart soc-n8n
```

---

## Groq API Configuration

The workflows use the Groq API for AI analysis. API key is stored in each workflow JSON file:

```json
{
  "headerParameters": {
    "parameters": [
      {"name": "Content-Type", "value": "application/json"},
      {"name": "Authorization", "value": "Bearer gsk_YOUR_KEY_HERE"}
    ]
  }
}
```

To update the API key, edit each workflow JSON file and replace the Bearer token.

**Current working key:** `INSERT_YOUR_GROQ_API_KEY`

---

## Zammad Configuration

Tickets are created via Zammad API:

- **URL:** `http://localhost:8080/api/v1/tickets.json`
- **Token:** `INSERT_YOUR_ZAMMAD_API_TOKEN`

---

## Docker Commands Reference

```bash
# Start n8n
docker start soc-n8n

# Stop n8n
docker stop soc-n8n

# Restart n8n
docker restart soc-n8n

# View logs
docker logs soc-n8n -f

# Check status
docker ps | grep soc-n8n
```

---

## File Structure

```
/home/blueteam/repositories/SOC-Ai-Driven-Automation/n8n/
├── docker-compose.yml    # n8n + SQLite configuration
├── README.md            # Project overview
├── troubleshooting.md  # Common issues and solutions
├── MANAGEMENT.md        # This file
└── workflows/
    ├── wazuh-alert-poller.json
    ├── agent1-dispatcher.json
    └── agent2-responder.json
```

---

## Best Practices

1. **Always add `method: "POST"`** to HTTP Request nodes in JSON
2. **Test after every change** using curl before trusting the workflow
3. **Check n8n logs** for error details - they usually explain what's wrong
4. **Keep database clean** - delete old workflows before importing new ones
5. **Version control** - commit changes to workflows folder after modifications
6. **Test webhook paths** - verify webhook paths match between database and JSON

---

*Last updated: 2026-04-05*
