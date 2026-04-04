# Zammad API Integration Guide

## Overview

This guide covers integrating Zammad with the SOC Automation system via its REST API. The API allows automated ticket creation, updates, and monitoring from n8n workflows.

---

## Table of Contents

1. [Authentication](#authentication)
2. [API Endpoints](#api-endpoints)
3. [Ticket Operations](#ticket-operations)
4. [User & Group Management](#user--group-management)
5. [Custom Fields](#custom-fields)
6. [n8n Integration](#n8n-integration)
7. [Error Handling](#error-handling)
8. [Examples](#examples)

---

## Authentication

### Method 1: API Token (Recommended)

**Create API Token:**

1. Login to Zammad as admin
2. Navigate to: **Settings → API**
3. Click "Add Token"
4. Set name: "SOC Automation"
5. Select permissions (admin for full access)
6. Copy the generated token

**Using the Token:**

```bash
# All requests include this header
curl -H "Authorization: Token token=YOUR_API_TOKEN" \
  http://localhost:8080/api/v1/endpoint
```

### Method 2: Session-Based Auth

```bash
# Step 1: Get CSRF token and session cookie
curl -s -c cookies.txt http://localhost:8080/ | grep -oP 'name="csrf-token" content="\K[^"]+'

# Step 2: Login with credentials
curl -s -X POST http://localhost:8080/api/v1/signin \
  -H "Content-Type: application/json" \
  -H "X-CSRF-Token: YOUR_CSRF_TOKEN" \
  -b cookies.txt \
  -d '{
    "username": "admin@zammad.local",
    "password": "SOC_Admin_2026!",
    "fingerprint": "soc-bot-001"
  }'

# Step 3: Use session cookie for subsequent requests
curl -b cookies.txt http://localhost:8080/api/v1/tickets
```

---

## API Endpoints

### Base URL

```
http://localhost:8080/api/v1
```

### Headers Required

```http
Authorization: Token token=YOUR_TOKEN
Content-Type: application/json
```

### Available Endpoints

| Resource | Methods | Description |
|----------|---------|-------------|
| `/tickets` | GET, POST | List/Create tickets |
| `/tickets/{id}` | GET, PUT, DELETE | Read/Update/Delete ticket |
| `/tickets/{id}/articles` | GET, POST | Ticket articles/notes |
| `/users` | GET, POST | User management |
| `/groups` | GET, POST | Group management |
| `/roles` | GET | Role listing |
| `/states` | GET | Ticket states |
| `/priorities` | GET | Priority levels |
| `/organizations` | GET, POST | Organizations |
| `/object_manager_attributes` | GET | Custom fields |
| `/search` | GET | Search tickets |

---

## Ticket Operations

### Create Ticket

```bash
# Basic ticket
curl -X POST http://localhost:8080/api/v1/tickets \
  -H "Authorization: Token token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Security Alert: SSH Brute Force",
    "group": "SOC-Alerts",
    "state": "new",
    "priority": "3"
  }'
```

**Response:**
```json
{
  "id": 123,
  "title": "Security Alert: SSH Brute Force",
  "group": "SOC-Alerts",
  "state": "new",
  "priority": "3",
  "created_at": "2026-04-04T00:00:00Z",
  "updated_at": "2026-04-04T00:00:00Z"
}
```

### Create Ticket with Initial Article

```bash
curl -X POST http://localhost:8080/api/v1/tickets \
  -H "Authorization: Token token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Alert: Possible Intrusion",
    "group": "SOC-Alerts",
    "state": "new",
    "priority": "4",
    "article": {
      "body": "Alert Details:\n- Rule ID: 100001\n- Level: 12\n- Source: 192.168.1.100\n- Time: 2026-04-04 00:00:00\n\nMITRE ATT&CK:\n- Technique: T1110 (Brute Force)\n- Tactic: Credential Access",
      "type": "note",
      "sender": "System"
    }
  }'
```

### Get Ticket

```bash
curl -X GET http://localhost:8080/api/v1/tickets/123 \
  -H "Authorization: Token token=YOUR_TOKEN"
```

### Update Ticket

```bash
# Change state and assign group
curl -X PUT http://localhost:8080/api/v1/tickets/123 \
  -H "Authorization: Token token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "group": "SOC-Approved",
    "state": "open",
    "priority": "2"
  }'
```

### Update Ticket with Custom Fields

```bash
curl -X PUT http://localhost:8080/api/v1/tickets/123 \
  -H "Authorization: Token token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "custom_fields": {
      "soc_proposal": "Block IP 192.168.1.100 via firewall",
      "soc_confidence": 85,
      "soc_action": "approved",
      "soc_mitre_id": "T1110",
      "soc_mitre_tactic": "Brute Force"
    }
  }'
```

### Add Article/Note to Ticket

```bash
curl -X POST http://localhost:8080/api/v1/tickets/123/articles \
  -H "Authorization: Token token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "body": "Analysis Complete:\n\nRecommendation: APPROVED\n\nAction: Block source IP at firewall\nConfidence: 85%",
    "type": "note",
    "sender": "System"
  }'
```

### List Tickets

```bash
# All tickets
curl -X GET http://localhost:8080/api/v1/tickets \
  -H "Authorization: Token token=YOUR_TOKEN"

# Filter by state
curl -X GET "http://localhost:8080/api/v1/tickets?state=new" \
  -H "Authorization: Token token=YOUR_TOKEN"

# Filter by group
curl -X GET "http://localhost:8080/api/v1/tickets?group=SOC-Alerts" \
  -H "Authorization: Token token=YOUR_TOKEN"

# Pagination
curl -X GET "http://localhost:8080/api/v1/tickets?limit=50&page=1" \
  -H "Authorization: Token token=YOUR_TOKEN"
```

### Delete Ticket

```bash
curl -X DELETE http://localhost:8080/api/v1/tickets/123 \
  -H "Authorization: Token token=YOUR_TOKEN"
```

---

## User & Group Management

### List Users

```bash
curl -X GET http://localhost:8080/api/v1/users \
  -H "Authorization: Token token=YOUR_TOKEN"
```

### Get Current User

```bash
curl -X GET http://localhost:8080/api/v1/users/me \
  -H "Authorization: Token token=YOUR_TOKEN"
```

### List Groups

```bash
curl -X GET http://localhost:8080/api/v1/groups \
  -H "Authorization: Token token=YOUR_TOKEN"
```

### Create User

```bash
curl -X POST http://localhost:8080/api/v1/users \
  -H "Authorization: Token token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "login": "analyst",
    "email": "analyst@soc.local",
    "firstname": "Security",
    "lastname": "Analyst",
    "password": "SecurePassword123!",
    "role": "agent",
    "group_ids": [1, 2, 3]
  }'
```

---

## Custom Fields

### List Custom Fields

```bash
curl -X GET http://localhost:8080/api/v1/object_manager_attributes \
  -H "Authorization: Token token=YOUR_TOKEN"
```

### Get Ticket with Custom Fields

```bash
curl -X GET http://localhost:8080/api/v1/tickets/123 \
  -H "Authorization: Token token=YOUR_TOKEN" | jq '.custom_fields'
```

---

## n8n Integration

### HTTP Request Node Configuration

```json
{
  "node": "HTTP Request",
  "method": "POST",
  "url": "http://localhost:8080/api/v1/tickets",
  "authentication": "customHeader",
  "sendHeaders": true,
  "headerParameters": {
    "parameters": [
      {
        "name": "Authorization",
        "value": "Token token={{$credentials.zammad_api_token}}"
      },
      {
        "name": "Content-Type",
        "value": "application/json"
      }
    ]
  },
  "bodyParameters": {
    "parameters": [
      {
        "name": "title",
        "value": "{{json.alert_title}}"
      },
      {
        "name": "group",
        "value": "SOC-Alerts"
      },
      {
        "name": "state",
        "value": "new"
      },
      {
        "name": "priority",
        "value": "{{json.alert_level}}"
      }
    ]
  }
}
```

### Complete Workflow Example

```
Webhook (Wazuh Alert)
    │
    ▼
Function Node (Format Alert)
    │
    ▼
HTTP Request (Create Zammad Ticket)
    │
    ▼
IF (Confidence > 80)
    │
    ├─▶ Wait Node (Wait for Approval)
    │       │
    │       ▼
    │   IF (Approved)
    │       │
    │       ├─▶ HTTP Request (Execute Remediation)
    │       └─▶ HTTP Request (Update Ticket: executed)
    │
    └─▶ HTTP Request (Update Ticket: manual review)
```

---

## Error Handling

### Common Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 200 | Success | Normal response |
| 201 | Created | New resource created |
| 400 | Bad Request | Check JSON syntax |
| 401 | Unauthorized | Check API token |
| 403 | Forbidden | Check permissions |
| 404 | Not Found | Check resource ID |
| 422 | Unprocessable | Check validation |
| 500 | Server Error | Check Zammad logs |

### Error Response Example

```json
{
  "error": "Unable to create ticket - validation error",
  "details": {
    "title": ["is required"]
  }
}
```

### Retry Logic

```javascript
// n8n Function node retry logic
let retries = 3;
let delay = 1000;

for (let i = 0; i < retries; i++) {
  try {
    // Make API call
    const response = await makeApiCall();
    return response;
  } catch (error) {
    if (i === retries - 1) throw error;
    await sleep(delay);
    delay *= 2;
  }
}
```

---

## Examples

### Create Alert Ticket from n8n

```javascript
// n8n Function node to prepare ticket payload
const alertData = $json;

const ticket = {
  title: `Security Alert: ${alertData.rule.description}`,
  group: "SOC-Alerts",
  state: "new",
  priority: alertData.rule.level >= 10 ? "4" : "3",
  article: {
    body: `
Alert Details:
- Rule ID: ${alertData.rule.id}
- Level: ${alertData.rule.level}
- Description: ${alertData.rule.description}
- Agent: ${alertData.agent.name}
- Time: ${alertData.timestamp}

MITRE ATT&CK:
- Technique ID: ${alertData.rule.mitre?.id?.[0] || 'N/A'}
- Tactic: ${alertData.rule.mitre?.tactic?.[0] || 'N/A'}

Source IP: ${alertData.data?.srcip || 'N/A'}
Full Log: ${alertData.full_log}
    `.trim(),
    type: "note",
    sender: "System"
  },
  custom_fields: {
    soc_alert_level: alertData.rule.level,
    soc_agent_id: alertData.agent.id,
    soc_rule_id: alertData.rule.id,
    soc_mitre_id: alertData.rule.mitre?.id?.[0] || '',
    soc_mitre_tactic: alertData.rule.mitre?.tactic?.[0] || '',
    soc_action: "pending",
    soc_confidence: 0
  }
};

return ticket;
```

### Update Ticket After Analysis

```javascript
// Update ticket with AI analysis results
const update = {
  group: "SOC-Triage",
  state: "open",
  custom_fields: {
    soc_confidence: $json.ai_confidence,
    soc_proposal: $json.remediation_proposal,
    soc_action: $json.analyst_approved ? "approved" : "pending",
    soc_mitre_id: $json.mitre_technique,
    soc_mitre_tactic: $json.mitre_tactic
  },
  article: {
    body: `
AI Analysis Results:

Confidence: ${$json.ai_confidence}%
MITRE Technique: ${$json.mitre_technique}
Tactic: ${$json.mitre_tactic}

Recommendation: ${$json.remediation_proposal}

Rationale:
${$json.analysis_rationale}
    `.trim(),
    type: "note",
    sender: "AI Analysis"
  }
};

return update;
```

### Poll for Pending Approvals

```javascript
// n8n recurring workflow to check for approved tickets
const query = {
  params: {
    group: "SOC-Approved",
    state: "open",
    "custom_fields.soc_action": "approved"
  }
};

// Make GET request to /api/v1/tickets
// Process each ticket for remediation
```

---

## Rate Limits

- **No hard limits** for authenticated API users
- **Recommended:** Add 100-200ms delay between requests
- **Batch operations:** Use bulk endpoints where available

---

## Security Best Practices

1. **Token Storage:** Store tokens in n8n credentials, not in code
2. **HTTPS:** Use HTTPS in production
3. **IP Allowlist:** Configure in Zammad settings
4. **Audit Logs:** Check Zammad audit log for API activity
5. **Token Rotation:** Rotate tokens regularly

---

## Next Steps

1. [Configure Zammad Installation](README.md)
2. [Set up Email Notifications](email-notifications.md)
3. [Create n8n Workflows](../n8n/workflows/README.md)
4. [Configure Gemini Integration](gemini-integration.md)