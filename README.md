# SOC-Ai-Driven-Automation

<div align="center">

**AI-Driven Security Operations Center Automation**

A modular, Docker-based SOC automation system that autonomously detects, analyzes, and responds to security threats using AI.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue)](https://www.docker.com/)
[![Wazuh](https://img.shields.io/badge/Wazuh-4.14.3-green)](https://wazuh.com/)
[![n8n](https://img.shields.io/badge/n8n-Latest-green)](https://n8n.io/)
[![Zammad](https://img.shields.io/badge/Zammad-7.0-green)](https://zammad.org/)

</div>

---

## Overview

SOC-Ai-Driven-Automation is a comprehensive security operations center automation platform that combines:

- **Wazuh** - SIEM/XDR for threat detection and log analysis
- **n8n** - Workflow orchestration for automation pipelines
- **Zammad** - Ticketing system for Human-in-the-Loop (HITL) approval
- **Gemini AI** - AI-powered threat analysis and response recommendations

### Key Features

- **Automated Alert Processing** - Wazuh alerts trigger automated workflows
- **AI-Powered Analysis** - Gemini AI generates threat assessments and remediation proposals
- **MITRE ATT&CK Mapping** - Automatic technique and tactic correlation
- **Human-in-the-Loop** - Analysts approve high-impact automated responses
- **Complete Audit Trail** - All actions logged in Zammad tickets

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SOC Automation System                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐           │
│  │   WAZUH     │     │     n8n     │     │   ZAMMAD    │           │
│  │  (Source    │────▶│  (Workflow  │────▶│  (Ticketing │           │
│  │   of Truth) │     │   Engine)   │     │   System)   │           │
│  └─────────────┘     └─────────────┘     └─────────────┘           │
│         │                   │                   │                   │
│         │                   │                   │                   │
│         ▼                   ▼                   ▼                   │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐           │
│  │   Alert     │     │   Gemini    │     │   Analyst   │           │
│  │   Forwarder │     │     AI      │     │   Approval  │           │
│  └─────────────┘     └─────────────┘     └─────────────┘           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Version | Purpose |
|-----------|---------|---------|
| Wazuh Manager | 4.14.3 | SIEM/XDR, threat detection |
| Wazuh Indexer | 4.14.3 | Log storage and search |
| Wazuh Dashboard | 4.14.3 | Security dashboard |
| n8n | Latest | Workflow orchestration |
| Zammad | 7.0 | Ticketing & case management |
| Gemini | 1.5 Pro | AI reasoning engine |

---

## Quick Start

### Prerequisites

- **OS**: Kali Linux 2026.1 (or Ubuntu/Debian-based)
- **RAM**: 16 GB minimum
- **Disk**: 100 GB minimum
- **Docker**: Latest version
- **Docker Compose**: v2+

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/AlonsoRodriguez-Am/SOC-Ai-Driven-Automation.git
cd SOC-Ai-Driven-Automation
```

2. **Start all services:**
```bash
chmod +x scripts/start-services.sh
./scripts/start-services.sh start
```

3. **Access the services:**

| Service | URL | Credentials |
|---------|-----|-------------|
| Wazuh Dashboard | https://localhost:443 | Check docs/credentials-guide.md |
| n8n | http://localhost:5678 | admin / *(set during install)* |
| Zammad | http://localhost:8080 | admin / *(set during install)* |

---

## Module Overview

### 1. Wazuh (`/wazuh`)
Enterprise-grade SIEM/XDR platform for security monitoring.

- **What's included:** Docker deployment, agent deployment guides, alert integration
- **Key files:** `docker-compose.yml`, `config/ossec.conf.example`
- **Documentation:** [Wazuh Module README](./wazuh/README.md)

### 2. Zammad (`/zammad`)
Open-source ticketing system with full API access.

- **What's included:** Docker deployment, API integration, custom fields
- **Key files:** `docker-compose.yml`, `config/custom-fields.json`
- **Documentation:** [Zammad Module README](./zammad/README.md)

### 3. n8n (`/n8n`)
Powerful workflow automation tool.

- **What's included:** Docker deployment, workflow templates
- **Key files:** `docker-compose.yml`, `workflows/agent1-dispatcher.json`
- **Documentation:** [n8n Module README](./n8n/README.md)

---

## Project Structure

```
SOC-Ai-Driven-Automation/
├── README.md                    # This file
├── LICENSE                     # MIT License
├── .gitignore                  # Git ignore rules
├── docs/                       # General documentation
│   ├── architecture.md         # System architecture
│   ├── quick-reference.md      # Quick command reference
│   ├── troubleshooting.md      # General troubleshooting guide
│   └── credentials-guide.md   # Credential management
├── wazuh/                      # Wazuh module
│   ├── README.md
│   ├── docker-compose.yml
│   ├── config/
│   │   └── ossec.conf.example
│   ├── integration/
│   │   └── README.md
│   ├── agents/
│   │   └── README.md
│   └── troubleshooting.md
├── zammad/                     # Zammad module
│   ├── README.md
│   ├── docker-compose.yml
│   ├── config/
│   │   └── custom-fields.json
│   ├── api/
│   │   └── README.md
│   └── troubleshooting.md
├── n8n/                        # n8n module
│   ├── README.md
│   ├── docker-compose.yml
│   ├── workflows/
│   │   ├── wazuh-alert-poller.json   # Main alert receiver
│   │   ├── agent1-dispatcher.json      # Alert dispatcher
│   │   └── agent2-responder.json      # Deep analysis responder
│   └── troubleshooting.md
└── scripts/                    # Automation scripts
    ├── wazuh-alert-forwarder.py
    └── start-services.sh
```

---

## Documentation Index

### Getting Started
- [Quick Start Guide](#quick-start)
- [Credentials Guide](./docs/credentials-guide.md)
- [Quick Reference](./docs/quick-reference.md)

### Module Documentation
- [Wazuh Installation](./wazuh/README.md)
- [Wazuh Agent Deployment](./wazuh/agents/README.md)
- [Wazuh Alert Integration](./wazuh/integration/README.md)
- [Zammad Installation](./zammad/README.md)
- [Zammad API Integration](./zammad/api/README.md)
- [n8n Installation](./n8n/README.md)
- [n8n Workflows](./n8n/workflows/README.md)

### Troubleshooting
- [General Troubleshooting](./docs/troubleshooting.md)
- [Wazuh Troubleshooting](./wazuh/troubleshooting.md)
- [Zammad Troubleshooting](./zammad/troubleshooting.md)
- [n8n Troubleshooting](./n8n/troubleshooting.md)

---

## Workflow Overview

### Agent 1: The Dispatcher

Receives Wazuh alerts and performs initial processing:

1. **Trigger**: Wazuh alert via webhook/cron
2. **Parse**: Extract alert details (rule, level, MITRE, agent)
3. **AI Brief**: Generate human-readable alert summary using Gemini
4. **Ticket**: Create Zammad ticket with alert details
5. **Notify**: Send email notification to on-call analyst

### Agent 2: The Responder

Deep threat analysis and remediation proposal:

1. **Trigger**: Ticket created in Zammad
2. **Enrich**: Gather additional context (network, process, file)
3. **MITRE Map**: Correlate with MITRE ATT&CK framework
4. **Analyze**: AI-powered threat assessment
5. **Propose**: Generate remediation recommendation
6. **Wait**: Pause for analyst approval (HITL)
7. **Execute**: Perform approved actions
8. **Log**: Document all actions taken

---

## Support

For issues and questions:

1. Check the [Troubleshooting](./docs/troubleshooting.md) guide
2. Review module-specific documentation
3. Check Docker logs for service-specific errors

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [Wazuh](https://wazuh.com/) - Open source security platform
- [n8n](https://n8n.io/) - Workflow automation
- [Zammad](https://zammad.org/) - Open source ticketing
- [Google Gemini](https://gemini.google.com/) - AI reasoning