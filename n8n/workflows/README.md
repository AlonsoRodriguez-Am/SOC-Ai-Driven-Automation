# n8n Workflows Guide

## Overview

This guide covers the workflow templates for the SOC Automation system. These workflows automate the entire alert-to-response pipeline.

---

## Available Workflows

### 1. Agent 1: The Dispatcher

**File:** `agent1-dispatcher.json`

**Purpose:** 
- Receive Wazuh alerts via webhook
- Parse alert details
- Generate human-readable alert brief using Gemini AI
- Create Zammad ticket
- Send email notification to analyst

**Trigger:** Webhook (POST /wazuh-alert)

**Flow Diagram:**
```
┌──────────────┐
│    Webhook   │ (POST /wazuh-alert)
└──────┬───────┘
       ▼
┌──────────────┐
│   Function   │ (Parse JSON)
└──────┬───────┘
       ▼
┌──────────────┐
│   HTTP Req   │ (Get more context from Wazuh API)
└──────┬───────┘
       ▼
┌──────────────┐
│   HTTP Req   │ (Call Gemini AI for alert brief)
└──────┬───────┘
       ▼
┌──────────────┐
│   Function   │ (Format ticket payload)
└──────┬───────┘
       ▼
┌──────────────┐
│   HTTP Req   │ (Create Zammad ticket)
└──────┬───────┘
       ▼
┌──────────────┐
│  Email Node  │ (Send notification)
└──────┬───────┘
       ▼
┌──────────────┐
│   Respond    │ (200 OK)
└──────────────┘
```

**Import Instructions:**
1. Open n8n at http://localhost:5678
2. Go to **Workflows → Import from File**
3. Select `agent1-dispatcher.json`
4. Configure credentials
5. Activate workflow

---

### 2. Agent 2: The Responder

**File:** `agent2-responder.json`

**Purpose:**
- Poll Zammad for pending tickets
- Deep threat analysis
- MITRE ATT&CK mapping
- Generate remediation proposal
- Wait for analyst approval (HITL)
- Execute approved remediation
- Update ticket with results

**Trigger:** Schedule (Every 5 minutes)

**Flow Diagram:**
```
┌──────────────┐
│   Schedule   │ (Every 5 minutes)
└──────┬───────┘
       ▼
┌──────────────┐
│   HTTP Req   │ (Get pending tickets)
└──────┬───────┘
       ▼
┌──────────────┐
│    Split     │ (Loop over tickets)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   HTTP Req   │ (Get alert details from Wazuh)
└──────┬───────┘
       ▼
┌──────────────┐
│   HTTP Req   │ (Call Gemini for analysis)
└──────┬───────┘
       ▼
┌──────────────┐
│   Function   │ (Format analysis results)
└──────┬───────┘
       ▼
┌──────────────┐
│   HTTP Req   │ (Update Zammad ticket)
└──────┬───────┘
       ▼
┌──────────────┐
│    IF        │ (Confidence > 80%?)
└──────┬───────┘
       │
   ┌───┴───┐
   │ Yes   │ No
   ▼       ▼
┌──────┐ ┌──────────┐
│ Wait │ │ Update   │ (Manual review)
│      │ │ Ticket   │
│ (HITL)│ └──────────┘
│       │
│  ┌────┴────┐
│  ▼         ▼
│ Approve Reject
│   │         │
│   ▼         ▼
│ Execute  Update Ticket
│ Action   (rejected)
│   │
│   ▼
│ Update Ticket
│ (executed)
```

**Import Instructions:**
1. Open n8n at http://localhost:5678
2. Go to **Workflows → Import from File**
3. Select `agent2-responder.json`
4. Configure credentials
5. Activate workflow

---

## Workflow Node Details

### Webhook Node

```json
{
  "node": "Webhook",
  "parameters": {
    "httpMethod": "POST",
    "path": "wazuh-alert",
    "responseMode": "onReceived",
    "responseData": "allEntries"
  }
}
```

### Function Node - Alert Parser

```javascript
// Parse Wazuh alert JSON
const alert = $json;

const parsed = {
  timestamp: alert.timestamp,
  rule_id: alert.rule?.id,
  rule_level: alert.rule?.level,
  rule_description: alert.rule?.description,
  rule_groups: alert.rule?.groups,
  mitre_id: alert.rule?.mitre?.id?.[0] || '',
  mitre_tactic: alert.rule?.mitre?.tactic?.[0] || '',
  agent_id: alert.agent?.id,
  agent_name: alert.agent?.name,
  manager: alert.manager?.name,
  full_log: alert.full_log,
  data: alert.data,
  location: alert.location
};

return parsed;
```

### HTTP Request - Gemini AI

```json
{
  "node": "HTTP Request",
  "method": "POST",
  "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent",
  "authentication": {
    "type": "queryAuth",
    "addTokenTo": "url",
    "key": "key",
    "value": "{{$credentials.gemini_api_key}}"
  },
  "body": {
    "contents": [{
      "parts": [{
        "text": "Analyze this Wazuh security alert and generate a brief summary.\n\nAlert: {{$json.rule_description}}\nLevel: {{$json.rule_level}}\nAgent: {{$json.agent_name}}\nMITRE: {{$json.mitre_id}} - {{$json.mitre_tactic}}\n\nProvide:\n1. Severity assessment (Critical/High/Medium/Low)\n2. Brief explanation\n3. Recommended first response"
      }]
    }]
  }
}
```

### HTTP Request - Create Zammad Ticket

```json
{
  "node": "HTTP Request",
  "method": "POST",
  "url": "http://localhost:8080/api/v1/tickets",
  "authentication": {
    "type": "headerAuth",
    "addAuthHeader": true,
    "headerName": "Authorization",
    "headerValue": "Token token={{$credentials.zammad_api_token}}"
  },
  "body": {
    "title": "Alert: {{$json.rule_description}}",
    "group": "SOC-Alerts",
    "state": "new",
    "priority": "{{$json.rule_level >= 10 ? '4' : '3'}}",
    "article": {
      "body": "{{$json.gemini_summary}}",
      "type": "note",
      "sender": "System"
    }
  }
}
```

---

## Testing Workflows

### Test Agent 1 (Dispatcher)

```bash
# Send test alert to webhook
curl -X POST http://localhost:5678/webhook/wazuh-alert \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2026-04-04T00:00:00-0500",
    "rule": {
      "level": 10,
      "description": "SSH brute force attack detected",
      "id": "100001",
      "groups": ["authentication", "sshd"],
      "mitre": {"id": ["T1110"], "tactic": ["Brute Force"]}
    },
    "agent": {
      "id": "001",
      "name": "web-server-01"
    },
    "manager": {
      "name": "wazuh-manager"
    },
    "full_log": "Apr  4 00:00:00 web-server-01 sshd[1234]: Failed password for invalid user admin from 192.168.1.100 port 22 ssh2"
  }'
```

### Check Execution

1. Open n8n UI
2. Go to **Executions** tab
3. Find your test execution
4. Check for errors or successful completion

### View Created Ticket

1. Open Zammad at http://localhost:8080
2. Go to **Tickets**
3. Find the new ticket with your test alert

---

## Configuration Required

Before activating workflows, ensure these credentials are configured:

### 1. wazuh-api
- Token from Wazuh API

### 2. zammad-api
- API Token from Zammad

### 3. gemini-api
- API Key from Google AI Studio

### 4. gmail-smtp (optional)
- App password for email notifications

---

## Customization

### Modify Alert Level Threshold

In the workflow, find the decision node that checks alert level:

```javascript
// Change threshold as needed
const threshold = 7;  // Forward only level 7+ alerts
return $json.rule_level >= threshold;
```

### Add Custom Fields

Add custom fields to the ticket payload:

```javascript
// In the function node before creating ticket
const customFields = {
  soc_alert_level: parsed.rule_level,
  soc_agent_id: parsed.agent_id,
  soc_rule_id: parsed.rule_id,
  soc_mitre_id: parsed.mitre_id,
  soc_mitre_tactic: parsed.mitre_tactic,
  soc_action: "pending",
  soc_confidence: 0
};

return { ...ticketData, custom_fields: customFields };
```

### Modify Gemini Prompt

Edit the prompt in the HTTP Request node to customize the AI analysis:

```javascript
// Current prompt generates:
// - Severity assessment
// - Brief explanation
// - Recommended first response

// Add more:
// - Blast radius assessment
// - MITRE mapping details
// - Remediation steps
```

---

## Monitoring

### Execution History

1. In n8n UI, go to **Executions**
2. Filter by workflow name
3. Check success/failure rates

### Error Handling

Each workflow includes error handling:

```json
{
  "node": "Error Workflow",
  "parameters": {
    "errorOutput": "error"
  }
}
```

### Notifications

Add an email notification node at the end to notify on failures:

```json
{
  "node": "Email",
  "parameters": {
    "to": "soc-team@company.com",
    "subject": "Workflow Error: Agent 1",
    "body": "Error in wazuh-alert workflow: {{$json.error}}"
  }
}
```

---

## Performance Tips

1. **Batch processing:** Process multiple alerts in batches
2. **Cache:** Cache API responses where possible
3. **Timeouts:** Set appropriate timeouts for API calls
4. **Pruning:** Enable execution data pruning

---

## Troubleshooting

### Workflow Not Triggering

1. Check webhook URL is correct
2. Ensure workflow is ACTIVE
3. Check n8n logs

### Ticket Not Created

1. Verify Zammad credentials
2. Check API token permissions
3. Verify group exists in Zammad

### Gemini Not Responding

1. Verify API key is valid
2. Check API quota
3. Verify network connectivity

---

## Next Steps

1. [Import workflows into n8n](#import-instructions)
2. [Configure credentials](#configuration-required)
3. [Test with sample alerts](#testing-workflows)
4. [Monitor execution](#monitoring)
5. [Customize as needed](#customization)