# n8n Workflows Guide

## Overview

This guide covers the workflow templates for the SOC Automation system. These workflows automate the entire alert-to-response pipeline using n8n v2.x.

---

## Available Workflows

### 1. Wazuh Alert Poller

**File:** `wazuh-alert-poller.json`

**Purpose:**
- Receive Wazuh alerts via webhook (POST endpoint)
- Parse and normalize alert data
- Generate AI-powered alert briefing with Gemini
- Create Zammad ticket with formatted report

**Trigger:** Webhook (POST `/webhook/wazuh-alert`)

**Flow:**
```
Webhook → Parse Alert → Prepare Gemini → Gemini AI → Parse Response → Create Zammad Ticket
```

**Webhook Path:** Configure in n8n UI after import (keep empty in JSON)

---

### 2. Agent 1: Alert Dispatcher

**File:** `agent1-dispatcher.json`

**Purpose:**
- Receive alerts from external sources
- Parse alert data with severity calculation
- Generate concise AI summary using Gemini
- Create Zammad ticket with priority and details

**Trigger:** Webhook (POST `/webhook/agent1-dispatcher`)

**Flow:**
```
Webhook → Parse Alert → Gemini AI → Parse Response → Create Zammad Ticket
```

**Webhook Path:** Configure in n8n UI after import

---

### 3. Agent 2: Threat Responder

**File:** `agent2-responder.json`

**Purpose:**
- Deep threat analysis for escalated alerts
- MITRE ATT&CK mapping and blast radius assessment
- Generate detailed remediation options
- Create comprehensive analysis report in Zammad

**Trigger:** Webhook (POST `/webhook/agent2-responder`)

**Flow:**
```
Webhook → Parse Alert → Deep Analysis Prompt → Gemini Deep Analysis → Parse Analysis → Format Report → Create Zammad Ticket
```

**Webhook Path:** Configure in n8n UI after import

---

## Installation Instructions

### Step 1: Import Workflow

1. Open n8n at http://localhost:5678
2. Go to **Workflows → Import from File**
3. Select the workflow JSON file
4. Click **Import**

### Step 2: Configure Webhook Path

**IMPORTANT:** Webhook paths must be configured in the UI after import:

1. Open the imported workflow
2. Click on the **Webhook** node
3. Set the **Path** field (e.g., `wazuh-alert`, `agent1-dispatcher`, etc.)
4. Save the workflow

### Step 3: Update Zammad Token

1. Click on the **Create Zammad Ticket** node
2. Find the Authorization header
3. Replace `YOUR_ZAMMAD_TOKEN` with your actual Zammad API token

### Step 4: Activate Workflow

1. Toggle the workflow to **Active**
2. The webhook URL will be displayed (e.g., `http://localhost:5678/webhook/wazuh-alert`)

---

## Testing Workflows

### Test Wazuh Alert Poller

```bash
curl -X POST http://localhost:5678/webhook/wazuh-alert \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2026-04-05T00:00:00-0500",
    "rule": {
      "level": 10,
      "description": "SSH brute force attack detected",
      "id": "100001",
      "groups": ["authentication", "sshd"],
      "mitre": {"id": ["T1110"], "tactic": ["Brute Force"]}
    },
    "agent": {"id": "001", "name": "web-server-01"},
    "data": {"srcip": "192.168.1.100"},
    "full_log": "Failed password for invalid user admin from 192.168.1.100 port 22 ssh2"
  }'
```

### Verify in Zammad

1. Open Zammad at http://localhost:8080
2. Go to **Tickets**
3. Verify new ticket with `[WAZUH]` prefix was created

---

## Configuration

### Required: Zammad API Token

1. Login to Zammad
2. Go to **Settings → API**
3. Create new token with permissions
4. Copy token and update in workflow nodes

### Optional: Gemini API Key

The workflows use Gemini 2.0 Flash via HTTP Request. For production:
1. Get API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Add to HTTP Request header or use environment variable

---

## n8n v2.x Notes

### Critical Settings

1. **Webhook typeVersion must be 2**
   ```json
   {
     "type": "n8n-nodes-base.webhook",
     "typeVersion": 2
   }
   ```

2. **Code nodes use `jsCode` instead of `functionCode`**
   ```json
   {
     "type": "n8n-nodes-base.code",
     "parameters": {
       "jsCode": "// JavaScript code here"
     }
   }
   ```

3. **HTTP Request typeVersion 4.2 recommended**

---

## Troubleshooting

### Workflow Not Triggering

1. Verify workflow is **Active** (toggled on)
2. Check webhook path matches in curl/forwarder
3. Restart n8n: `docker restart soc-n8n`

### Zammad Ticket Not Created

1. Verify Zammad is running: `curl http://localhost:8080/api/v1/tickets`
2. Check API token has correct permissions
3. Verify group "Users" exists in Zammad

### Gemini API Errors

1. Check API key is valid
2. Verify API quota/billing
3. Check network connectivity to Google APIs

---

## Customization

### Modify Severity Thresholds

In any Parse Alert node, modify:
```javascript
let priority = 1;
if (severityLevel >= 12) priority = 3;  // Critical
else if (severityLevel >= 7) priority = 2;  // High
```

### Change Zammad Group

Update the ticket creation body:
```javascript
group: 'Users'  // Change to your Zammad group name
```

### Add Additional Alert Sources

Duplicate the webhook workflow and modify:
1. New webhook path
2. Alert parsing logic for source format
3. Ticket title prefix (e.g., `[ESTHEROIDS]`, `[CUSTOM]`)

---

## Next Steps

1. [Import workflows into n8n](#installation-instructions)
2. [Configure webhook paths](#step-2-configure-webhook-path)
3. [Update Zammad token](#step-3-update-zammad-token)
4. [Activate workflows](#step-4-activate-workflow)
5. [Test with sample alerts](#testing-workflows)
