# Antigravity SOC Automation History & Checkpoint

This document tracks the evolution, troubleshooting, and current state of the SOC-Ai-Driven-Automation project.

## 📌 Project Context
- **Objective**: Automate SOC workflows using Wazuh (SIEM), n8n (Orchestrator), Zammad (Ticketing), and Groq AI (Analysis).
- **Status**: **Phase 6 Complete (Host-Aware Alerting & Auth Failure Elevation)**.
- **AI Engine**: Groq — Llama 3.3 70B Versatile
- **Decision Threshold**: 90% confidence (Conservatism Clause active)

---

## 👥 Identity Model

| Role | Email | Zammad ID | Purpose |
|------|-------|-----------|---------|
| Agent 1 (Dispatcher) | `agent1@soc.lab` | 78 | Creates tickets, initial triage |
| Agent 2 (Responder) | `agent2@soc.lab` | 77 | Deep analysis, forensic notes, auto-resolve/escalate |
| Senior Analyst | `admin@soc.local` | 3 | Human-in-the-loop, escalation owner |

---

## 🛠 Troubleshooting & Critical Fixes

### 1. Zammad API Connectivity
- **Issue**: n8n container could not reach Zammad via `localhost:8080` (separate compose stacks).
- **Solution**: Used the Docker bridge gateway IP: `http://172.19.0.1:8080`.
- **Lesson**: Standardize internal traffic to the host gateway when containers are on separate networks.

### 2. Zammad API Authentication
- **Issue**: Default API tokens were inconsistent or lacked permissions.
- **Verified Token**: `YOUR_ZAMMAD_TOKEN`
- **Fix**: Added Agent 1 and Agent 2 users with full access to SOC L1 (Group 1) and SOC Escalations (Group 2).

### 3. Zammad JSON Schema (Version 7.x)
- **Issue**: Tickets were not being created when wrapped in a `"ticket": { ... }` object.
- **Solution**: Send flat attributes directly in the JSON body.
- **Escalation Logic**: Uses `PUT` to existing tickets. Requires valid IDs: `state_id: 4` (Closed), `state_id: 2` (Open).

### 4. AI Overconfidence (Phase 4)
- **Issue**: Agent 2 was auto-closing administrative anomaly tickets (e.g., unusual sudo usage) with 92% confidence.
- **Solution**: Increased threshold from 80% to **90%** and added a **Conservatism Clause** that forces `inconclusive: true` for any administrative or privilege-related activity.

---

## 🚀 Implementation Phases

### Phase 1: Core Pipeline
- Wazuh → n8n → Zammad basic integration.
- Single API token for all operations.

### Phase 2: Autonomous Logic & CVE Enrichment
- Agent 2 deep threat analysis with CVE correlation.
- Auto-resolve logic (confidence ≥ 80%, not inconclusive).
- `soc_cve_list` custom field in Zammad.

### Phase 3: Per-Agent Identity & Auditability
- Created `agent1@soc.lab` (ID 78) and `agent2@soc.lab` (ID 77) in Zammad.
- Switched from API token auth to **Basic Auth** per agent.
- Full audit trail: CreatedBy = Agent 1, UpdatedBy = Agent 2.
- Group permissions: SOC L1 (full), SOC Escalations (Agent 2 only).

### Phase 4: Conservatism Clause & Threshold Tuning
- Increased auto-resolve threshold from **80% to 90%**.
- Added explicit instructions to the AI to mark administrative anomalies as `inconclusive`.
- Verified with automated test suite.

### Phase 5: Red Team Simulation
- Performed Nmap reconnaissance against vulnerable target (192.168.0.15).
- Executed Hydra brute-force against HTTP (Port 80).
- Confirmed Wazuh detection of scanning activity.
- Validated that Level 5 alerts from the scan were logged in the SIEM.

### Phase 6: Host-Aware Alerting & Auth Failure Elevation
- Updated all ticket titles to include `[WAZUH] [hostname] description`.
- Added host ID (e.g., "ID: 004") to the ticket body for forensic context.
- Authentication failure alerts (Level 5) are now automatically elevated to **Priority 2**.
- Updated Agent 2 AI prompt to perform host-specific risk assessments.

### Phase 7: Final End-to-End Verification & Local Test State
- Temporarily restored active API keys for Groq and Zammad into the local workspace for a final verification (`soc_test_suite.py`, Nmap, Hydra).
- Resynced n8n docker compose volumes to properly reflect local workflow files.
- Verified Docker bridge networking between n8n and Zammad (172.19.0.1:8080).
- Confirmed full pipeline function from raw alerts -> AI Agent 1 Triage -> AI Agent 2 Forensic Assessment.
- Final checkpoint created before concluding testing.

---

## 📍 Navigational Advice
**Where to open Antigravity?**
Open the **root repository folder**: `/home/blueteam/repositories/SOC-Ai-Driven-Automation/`.
This gives full access to `n8n/`, `zammad/`, and `wazuh/` simultaneously.
