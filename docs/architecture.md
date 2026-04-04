# SOC Automation System Architecture

## Overview

The SOC-Ai-Driven-Automation system is designed to provide autonomous security operations center capabilities using AI-driven analysis and human-in-the-loop approval workflows.

---

## System Components

### 1. Wazuh (SIEM/XDR)

**Purpose:** Source of Truth for security events

**Components:**
- Wazuh Manager - Central analysis engine
- Wazuh Indexer - Log storage and search
- Wazuh Dashboard - Security UI
- Wazuh API - Programmatic access

**Ports:**
| Service | Port | Protocol |
|---------|------|----------|
| Agent Communication | 1514 | TCP/UDP |
| Agent Registration | 1515 | TCP |
| Wazuh API | 55000 | HTTPS |
| Wazuh Dashboard | 443 | HTTPS |
| Indexer | 9200 | HTTP |

### 2. n8n (Workflow Engine)

**Purpose:** Orchestrate automation pipelines

**Function:**
- Receive Wazuh alerts
- Call Gemini AI for analysis
- Create Zammad tickets
- Execute remediation

**Ports:**
| Service | Port | Protocol |
|---------|------|----------|
| n8n UI | 5678 | HTTP |

### 3. Zammad (Ticketing)

**Purpose:** Human-in-the-loop interface

**Function:**
- Ticket creation and management
- Analyst approval workflows
- Audit trail

**Ports:**
| Service | Port | Protocol |
|---------|------|----------|
| Zammad UI | 8080 | HTTP |

### 4. Gemini AI

**Purpose:** Threat analysis and recommendations

**Function:**
- Alert summarization
- Deep threat analysis
- Remediation proposals

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SOC Automation System                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                      EXTERNAL INPUTS                         │   │
│  │  - Security Logs    - Network Events    - Endpoint Data    │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                │                                   │
│                                ▼                                   │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                        WAZUH                                │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │   │
│  │  │  Manager    │  │  Indexer    │  │  Dashboard  │         │   │
│  │  │  (Analysis) │  │  (Storage)  │  │    (UI)     │         │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │   │
│  │         │                │                │                 │   │
│  │         │                │                │                 │   │
│  │  ┌──────┴────────────────┴────────────────┴──────┐         │   │
│  │  │              Wazuh API (55000)                │         │   │
│  │  └───────────────────────────────────────────────┘         │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                │                                   │
│                    ┌───────────┴───────────┐                      │
│                    │   Alert Forwarder     │                      │
│                    │   (Python + Cron)    │                      │
│                    └───────────┬───────────┘                      │
│                                │                                   │
│                                ▼                                   │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                          n8n                                  │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │   │
│  │  │   Agent 1  │  │   Agent 2   │  │  Webhooks   │           │   │
│  │  │  Dispatcher│  │  Responder  │  │   Triggers  │           │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘           │   │
│  │         │                │                │                   │   │
│  │         └────────────────┼────────────────┘                   │   │
│  │                          │                                    │   │
│  │                    ┌─────┴─────┐                             │   │
│  │                    │  Gemini   │                             │   │
│  │                    │    AI     │                             │   │
│  │                    └─────┬─────┘                             │   │
│  └──────────────────────────┼───────────────────────────────────┘   │
│                             │                                      │
│                             ▼                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                        ZAMMAD                                 │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │   │
│  │  │   Tickets  │  │   Groups    │  │   Custom    │           │   │
│  │  │            │  │             │  │   Fields   │           │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘           │   │
│  │                                                              │   │
│  │  ┌────────────────────────────────────────────────────────┐ │   │
│  │  │              Analyst Approval (HITL)                   │ │   │
│  │  └────────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Alert Processing Flow

```
1. SECURITY EVENT
   - Endpoint generates log
   - Agent forwards to Wazuh Manager
   │
2. WAZUH PROCESSING
   - Decoder parses log
   - Rule engine evaluates
   - Alert generated
   │
3. ALERT FORWARDER
   - Cron triggers every minute
   - Reads new alerts from alerts.json
   - Forwards to n8n webhook
   │
4. n8n AGENT 1 (DISPATCHER)
   - Receives webhook payload
   - Parses alert JSON
   - Calls Gemini for summary
   - Creates Zammad ticket
   - Sends email notification
   │
5. ANALYST REVIEW
   - Analyst reviews ticket
   - Approves or rejects remediation
   │
6. n8n AGENT 2 (RESPONDER)
   - Polls for approved tickets
   - Deep analysis with Gemini
   - Executes remediation
   - Updates ticket status
```

---

## Network Architecture

### Docker Network

```
┌─────────────────────────────────────────────────────┐
│              soc-net (bridge network)              │
│                                                     │
│  ┌─────────────┐    ┌─────────────┐               │
│  │   wazuh-*   │    │  soc-n8n    │               │
│  │   containers│    │             │               │
│  └─────────────┘    └─────────────┘               │
│                                                     │
│  ┌─────────────┐    ┌─────────────┐               │
│  │ soc-zammad-*│    │             │               │
│  │ containers  │    │             │               │
│  └─────────────┘    └─────────────┘               │
│                                                     │
└─────────────────────────────────────────────────────┘
          │                    │
          │                    │
          ▼                    ▼
    Host Network         Host Network
    (ports)              (ports)
```

### Port Mapping

| Container | Internal Port | Host Port | Service |
|-----------|---------------|-----------|---------|
| wazuh-master | 55000 | 55000 | Wazuh API |
| wazuh-dashboard | 5601 | 443 | Dashboard |
| wazuh-indexer | 9200 | 9200 | Indexer |
| soc-n8n | 5678 | 5678 | n8n UI |
| soc-zammad-nginx | 8080 | 8080 | Zammad UI |

---

## Database Architecture

### PostgreSQL (Zammad)

```
┌─────────────────────────────────────────┐
│           zammad_production             │
├─────────────────────────────────────────┤
│ Tables:                                  │
│ - users                                 │
│ - groups                                │
│ - tickets                               │
│ - ticket_articles                       │
│ - object_manager_attributes (custom)   │
│ - states                                │
│ - priorities                            │
│ - archives                              │
└─────────────────────────────────────────┘
```

### Elasticsearch (Zammad Search)

```
Index: zammad
├── Tickets
├── Users
└── Articles (full-text search)
```

---

## Integration Points

### Wazuh → n8n

**Method:** Alert Forwarder Script (Cron)
- Reads: `/var/ossec/logs/alerts/alerts.json`
- Sends to: `http://localhost:5678/webhook/wazuh-alert`
- Frequency: Every minute

### n8n → Zammad

**Method:** REST API
- Endpoint: `http://localhost:8080/api/v1/tickets`
- Auth: Token header
- Operations: Create, Read, Update tickets

### n8n → Gemini AI

**Method:** REST API
- Endpoint: `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent`
- Auth: API key in query parameter

---

## Security Considerations

### Network Isolation
- All services in `soc-net` Docker network
- No direct external access (except via mapped ports)

### API Security
- Token-based authentication
- HTTPS for production

### Credential Management
- Stored in n8n credential store
- Not committed to version control

### Audit Trail
- All ticket changes logged in Zammad
- All workflow executions logged in n8n

---

## Scalability Considerations

### Horizontal Scaling

**Wazuh:**
- Add worker nodes for distributed processing
- Load balance agent connections

**Zammad:**
- Add more Rails servers behind load balancer
- Use read replicas for database

### Vertical Scaling

**Resource Upgrades:**
- Increase RAM for all containers
- Add more CPU cores
- Expand disk for logs/indexer

---

## Backup & Recovery

### Wazuh
- Backup: `/var/ossec/etc/` and `/var/ossec/ruleset/`
- Indexer snapshots

### Zammad
- PostgreSQL dumps
- Elasticsearch snapshots

### n8n
- Backup: `./data/` directory
- Export workflows as JSON

---

## Monitoring

### Health Checks

| Service | Method |
|---------|--------|
| Wazuh | API `/` endpoint |
| n8n | UI login |
| Zammad | UI login |

### Logs

| Service | Location |
|---------|----------|
| Wazuh | `/var/ossec/logs/ossec.log` |
| n8n | `docker logs soc-n8n` |
| Zammad | `docker-compose logs` |

---

## Version Information

| Component | Version |
|-----------|---------|
| Wazuh Manager | 4.14.3 |
| Wazuh Indexer | 4.14.3 |
| Wazuh Dashboard | 4.14.3 |
| n8n | Latest |
| Zammad | 7.0.0-0058 |
| PostgreSQL | 15 |
| Elasticsearch | 7.17.16 |
| Python | 3.x |