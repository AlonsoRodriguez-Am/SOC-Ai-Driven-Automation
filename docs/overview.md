# SOC Automation Project Overview

## Project Name

**SOC-Ai-Driven-Automation** - Autonomous AI-driven Security Operations Center

---

## Purpose

Build an autonomous SOC system that performs:
- Contextual log analysis
- Risk assessment
- Threat response proposal
- Human-in-the-Loop (HITL) approval for high-impact actions

---

## Current Stage

**Phase 6: Production-Ready** (Complete)

### Completed Phases

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 0 | ✅ | Infrastructure Preparation |
| Phase 1 | ✅ | n8n Installation |
| Phase 2 | ✅ | Zammad Installation |
| Phase 3 | ✅ | Wazuh Integration |
| Phase 4 | ✅ | Agent 1 Workflow (Dispatcher) |
| Phase 5 | ✅ | Agent 2 Workflow (Responder) |
| Phase 6 | ✅ | HITL Decision Gate |
| Phase 7 | ✅ | Active Response |
| Phase 8 | ✅ | End-to-End Testing |

---

## Tech Stack

### Core Components

| Component | Version | Purpose |
|-----------|---------|---------|
| **Wazuh** | 4.14.3 | SIEM/XDR - Source of Truth |
| **n8n** | Latest | Workflow Orchestration Engine |
| **Zammad** | 7.0+ | Ticketing & Case Management |
| **Groq (Llama 3.3 70B)** | Latest | AI Reasoning Engine |

### Infrastructure

| Component | Technology |
|-----------|------------|
| OS | Kali Linux 2026.1 |
| Container | Docker |
| Network | Docker Bridge (soc-net) |

---

## System Requirements

### Hardware

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 16 GB | 32 GB |
| Disk | 100 GB | 200 GB |
| CPU | 4 cores | 8 cores |

### Software

| Requirement | Version |
|-------------|---------|
| Docker Engine | 20.10+ |
| Docker Compose | v2+ |
| Python | 3.x |

---

## Network Configuration

| Service | Port | Protocol |
|---------|------|----------|
| n8n | 5678 | HTTP |
| Zammad | 8080 | HTTP |
| Wazuh Dashboard | 443 | HTTPS |
| Wazuh API | 55000 | HTTPS |

---

## Project Structure

```
SOC-Ai-Driven-Automation/
├── docs/                           # Documentation
│   ├── overview.md                 # This file
│   ├── architecture.md             # System architecture
│   ├── quick-reference.md          # Command reference
│   ├── troubleshooting.md          # Troubleshooting guide
│   ├── credentials-guide.md        # Credential management
│   ├── setup-checklist.md          # Installation checklist
│   ├── ai-integration.md           # Groq AI configuration
│   ├── custom-fields.md            # Zammad custom fields
│   └── diagrams/                  # Architecture diagrams
│       ├── system-flow.md
│       ├── alert-processing.md
│       └── decision-engine.md
├── wazuh/                         # Wazuh SIEM module
│   ├── README.md                   # Wazuh configuration
│   ├── docker-compose.yml
│   ├── agents/                     # Agent deployment
│   ├── integration/                 # Alert forwarding
│   └── troubleshooting.md
├── n8n/                           # n8n SOAR module
│   ├── README.md                   # n8n configuration
│   ├── MANAGEMENT.md               # Workflow management
│   ├── docker-compose.yml
│   ├── workflows/                  # Workflow definitions
│   │   ├── wazuh-alert-poller.json
│   │   ├── agent1-dispatcher.json
│   │   ├── agent2-responder.json
│   │   └── soc_test_suite.py
│   └── troubleshooting.md
├── zammad/                        # Zammad ticketing module
│   ├── README.md                   # Zammad configuration
│   ├── docker-compose.yml
│   ├── api/                        # API integration
│   └── troubleshooting.md
├── scripts/                       # Automation scripts
│   ├── start-services.sh          # Service lifecycle
│   └── wazuh-alert-forwarder.py   # Alert forwarder
└── LICENSE
```

---

## Key Features

### Agent 1: The Dispatcher

**Identity**: `agent1@soc.lab` (Zammad User ID: 78)

**Responsibilities**:
- Receives Wazuh alerts via webhook
- Generates human-readable Alert Briefs using Groq AI
- Identifies related CVEs with explanations
- Creates Zammad tickets with host tagging: `[WAZUH] [hostname] description`
- Sends email notifications to on-call team

**Workflow**:
```
Webhook Trigger → Parse Alert → Groq AI Brief → Create Ticket → Email Notify
```

### Agent 2: The Responder

**Identity**: `agent2@soc.lab` (Zammad User ID: 77)

**Responsibilities**:
- Deep threat analysis
- CVE correlation with host-specific mitigations
- MITRE ATT&CK mapping
- Blast radius assessment
- Remediation proposal generation
- Confidence scoring

**Workflow**:
```
Ticket Created → Deep Analysis → Confidence Check → Auto-Close OR Escalate
```

---

## Autonomous Decision Engine

### Confidence Thresholds

| Confidence | Inconclusive | Action |
|------------|-------------|--------|
| >= 90% | `false` | **Auto-Close** - Ticket resolved with forensic report |
| >= 90% | `true` | **Escalate** - Moved to SOC Escalations group |
| < 90% | Any | **Escalate** - Human review required |

### Conservatism Clause

The AI is explicitly instructed to **always set `inconclusive: true`** for:
- Administrative access anomalies (logins, sudo, user creation)
- Privilege escalation indicators
- Any activity where intent is not 100% verifiable from logs alone

This ensures high-privilege account activity is **never auto-resolved**.

### Authentication Failure Elevation

Authentication failure alerts (typically Wazuh Level 5) are automatically elevated to **Priority 2**.

---

## Identity & Audit Model

The system uses **segregated AI identities** for forensic accountability:

| Identity | Zammad User | ID | Role |
|----------|-------------|-----|------|
| Agent 1 (Dispatcher) | `agent1@soc.lab` | 78 | Creates tickets, initial AI triage |
| Agent 2 (Responder) | `agent2@soc.lab` | 77 | Deep analysis, forensic notes, auto-resolve/escalate |
| Senior Analyst | `admin@soc.local` | 3 | Human-in-the-loop, escalation owner |

Every action is attributed via `created_by_id` and `updated_by_id`.

---

## Security Considerations

| Control | Implementation |
|---------|---------------|
| API Authentication | Token-based for all services |
| AI Identity Segregation | Separate credentials per agent |
| SSL/TLS | HTTPS for external services |
| Credential Storage | n8n credential store (not version controlled) |
| Audit Trail | Complete chain-of-custody in Zammad |
| 2FA | Recommended for all web interfaces |

---

## Testing

### Automated Test Suite

```bash
python3 n8n/workflows/soc_test_suite.py
```

**Scenarios tested:**

| Scenario | Alert | Expected Result |
|----------|-------|-----------------|
| Critical CVE (Log4j) | Level 15, CVE-2021-44228 | Auto-Close (State 4) |
| Sudo Anomaly | Level 10, non-standard sudo | Escalate to Human |
| SSH Auth Failure | Level 5, `sshd: authentication failure` | P2 Priority, Host Tagged |

---

## Lab Environment

### Vulnerable Target Machine

For forensic testing, a dedicated vulnerable machine is used:

| Field | Value |
|-------|-------|
| IP Address | `192.168.0.15` |
| Agent ID | `004` |
| Agent Name | `vulnerable` |
| OS | Ubuntu 22.04 |
| Purpose | Red Team Testing (Nmap, Brute Force) |

---

## Future Enhancements

- Additional MITRE ATT&CK coverage
- Machine learning for anomaly detection
- Integration with threat intelligence feeds
- Automated playbook library
- Multi-tenant support
- Distributed Wazuh deployment

---

## Support

For issues, see:
- [Troubleshooting Guide](./troubleshooting.md)
- [Quick Reference Card](./quick-reference.md)
- Module-specific troubleshooting docs
