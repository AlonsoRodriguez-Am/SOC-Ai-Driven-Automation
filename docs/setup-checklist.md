# SOC Automation Setup Checklist

## Prerequisites

### System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 16 GB | 32 GB |
| Disk | 100 GB | 200 GB |
| CPU | 4 cores | 8 cores |
| OS | Ubuntu 20.04+ / Kali Linux | Kali Linux 2026.1 |

### Software Dependencies

- [x] Docker Engine 20.10+
- [x] Docker Compose v2+
- [x] Python 3.x
- [ ] Git

### Required Ports

| Port | Service | Status |
|------|---------|--------|
| 443 | Wazuh Dashboard | Available |
| 5678 | n8n | Available |
| 8080 | Zammad | Available |
| 55000 | Wazuh API | Available |

---

## Phase 1: Repository Setup

### Task 1.1: Clone Repository

```bash
# Clone the repository
git clone https://github.com/AlonsoRodriguez-Am/SOC-Ai-Driven-Automation.git
cd SOC-Ai-Driven-Automation

# Verify structure
ls -la
```

### Task 1.2: Create Directory Structure

```bash
# Create required directories
mkdir -p wazuh/data/{indexer,master,worker,etc,certs}
mkdir -p wazuh/logs
mkdir -p n8n/data
mkdir -p scripts/backups
```

---

## Phase 2: Wazuh Installation

### Task 2.1: Deploy Wazuh Stack

```bash
# Navigate to Wazuh module
cd wazuh

# Start Wazuh containers
docker-compose up -d

# Verify services
docker ps | grep wazuh
```

### Task 2.2: Verify Wazuh Access

| Check | Command | Expected |
|-------|---------|----------|
| Dashboard | Open https://localhost:443 | Login page |
| API | `curl -k https://localhost:55000` | JSON response |
| Agent Communication | Check port 1514 | Listening |

### Task 2.3: Configure Wazuh API

```bash
# Get API token
TOKEN=$(curl -s -k -X POST "https://localhost:55000/security/user/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"YOUR_PASSWORD"}' \
  | jq -r '.token')

# Test API
curl -k -H "Authorization: Bearer $TOKEN" https://localhost:55000/agents
```

### Task 2.4: Add Custom Rules (Optional)

Create `/var/ossec/etc/rules/local_rules.xml`:

```xml
<group name="soc,custom">
  <rule id="100001" level="10">
    <if_sid>5716</if_sid>
    <match>authentication failure</match>
    <frequency>5</frequency>
    <time_frame>10m</time_frame>
    <description>Possible SSH brute force attack</description>
    <mitre>
      <id>T1110</id>
    </mitre>
  </rule>
</group>
```

### Task 2.5: Configure Alert Forwarder

```bash
# Edit the forwarder script
nano scripts/wazuh-alert-forwarder.py

# Set the webhook URL (n8n will be configured later)
N8N_WEBHOOK_URL='http://localhost:5678/webhook/wazuh-alert'

# Make executable
chmod +x scripts/wazuh-alert-forwarder.py
```

---

## Phase 3: Zammad Installation

### Task 3.1: Deploy Zammad Stack

```bash
# Navigate to Zammad module
cd zammad

# Create environment file
cat > .env << 'EOF'
COMPOSE_PROJECT_NAME=soc-zammad
VERSION=7.0.0-0058
NGINX_PORT=8080
ZAMMAD_HTTP_TYPE=http
ZAMMAD_FQDN=zammad.local
TZ=America/New_York
POSTGRES_PASS=zammad_secure_pass_2026
EOF

# Start services
docker-compose up -d

# Wait for initialization (3-5 minutes)
docker-compose logs -f zammad-railsserver
```

### Task 3.2: Verify Zammad Access

| Check | URL | Expected |
|-------|-----|----------|
| Web UI | http://localhost:8080 | Setup wizard or login |
| API | `curl http://localhost:8080/api/v1/tickets` | JSON response |

### Task 3.3: Initial Zammad Setup

1. **Open browser:** http://localhost:8080
2. **Follow setup wizard:**
   - Create admin account
   - Set organization name
   - Skip email (configure later)

### Task 3.4: Create Admin Account

| Field | Value |
|-------|-------|
| Email | `admin@zammad.local` |
| Password | `SOC_Admin_2026!` |
| Full Name | SOC Administrator |

### Task 3.5: Create SOC Groups

Navigate to: **Settings → Groups → Add Group**

| Group Name | Description |
|------------|-------------|
| SOC-Alerts | New security alerts requiring triage |
| SOC-Triage | Alerts under active analysis |
| SOC-Approved | Approved for automated remediation |
| SOC-FP | Confirmed false positives |

### Task 3.6: Create Agent Users

Navigate to: **Settings → Users → Create User**

| User | Email | Password | Role |
|------|-------|----------|------|
| Agent 1 | `agent1@soc.lab` | `SOC_Admin_2026!` | Agent |
| Agent 2 | `agent2@soc.lab` | `SOC_Admin_2026!` | Agent |

### Task 3.7: Create API Token

1. Go to **Settings → API → Add Token**
2. Name: `SOC Automation`
3. Permissions: `admin`
4. Copy the generated token

### Task 3.8: Configure Custom Fields

Navigate to: **Settings → Object Manager → Ticket → Add Field**

| Field Name | Type | Key |
|------------|------|-----|
| soc_cve_list | Text | `soc_cve_list` |
| soc_proposal | Text Area | `soc_proposal` |
| soc_confidence | Text | `soc_confidence` |
| soc_mitre_id | Text | `soc_mitre_id` |
| soc_mitre_tactic | Text | `soc_mitre_tactic` |

See [docs/custom-fields.md](./custom-fields.md) for detailed setup.

---

## Phase 4: n8n Installation

### Task 4.1: Deploy n8n Stack

```bash
# Navigate to n8n module
cd n8n

# Create directories
mkdir -p ./data

# Start n8n
docker-compose up -d

# Verify
docker ps | grep soc-n8n
```

### Task 4.2: Access n8n

| Item | Value |
|------|-------|
| URL | http://localhost:5678 |
| User | `admin` |
| Password | `SOC_Automation_2026!` |

### Task 4.3: Change Default Password

1. Login to n8n
2. Go to **Settings → User**
3. Change password immediately

### Task 4.4: Create n8n Credentials

Navigate to: **Settings → Credentials → Add Credential**

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

#### 3. Groq API

| Field | Value |
|-------|-------|
| Name | `groq-api` |
| Type | HTTP Request |
| Auth | Header |
| Header Name | `Authorization` |
| Header Value | `Bearer YOUR_GROQ_API_KEY` |
| URL | `https://api.groq.com/openai/v1/chat/completions` |

### Task 4.5: Import Workflows

1. Open n8n UI
2. Go to **Workflows → Import from File**
3. Import each workflow:
   - `n8n/workflows/wazuh-alert-poller.json`
   - `n8n/workflows/agent1-dispatcher.json`
   - `n8n/workflows/agent2-responder.json`
4. Activate each workflow

### Task 4.6: Update API Keys in Workflows

For each workflow, update placeholder credentials:

| Placeholder | Replace With |
|-------------|--------------|
| `INSERT_YOUR_GROQ_API_KEY` | Your Groq API key |
| `INSERT_YOUR_ZAMMAD_API_TOKEN` | Your Zammad API token |

---

## Phase 5: Email Configuration (Optional)

### Task 5.1: Configure Gmail SMTP

Navigate to: **Settings → Channels → Email → Add Email Channel**

| Setting | Value |
|---------|-------|
| Type | SMTP |
| Host | smtp.gmail.com |
| Port | 587 |
| SSL/TLS | StartTLS |
| User | your-email@gmail.com |
| Password | App Password (not regular password) |

### Task 5.2: Create App Password

1. Go to Google Account → Security
2. Enable 2-Step Verification
3. Go to App Passwords
4. Create new app password for "Mail"
5. Copy the 16-character password

---

## Phase 6: Service Startup

### Task 6.1: Start All Services

```bash
# From project root
cd SOC-Ai-Driven-Automation
./scripts/start-services.sh start
```

### Task 6.2: Verify Service Status

```bash
./scripts/start-services.sh status
```

Expected output:
```
Docker Containers:
soc-n8n: Up
soc-zammad-*: Up
wazuh-*: Up

Service URLs:
  n8n:        http://localhost:5678
  Zammad:     http://localhost:8080
  Wazuh:      https://localhost:443
```

### Task 6.3: Configure Alert Forwarder Cron

```bash
# Add to crontab (runs every minute)
(crontab -l 2>/dev/null; echo "* * * * * /usr/bin/python3 $(pwd)/scripts/wazuh-alert-forwarder.py >> $(pwd)/logs/forwarder.log 2>&1") | crontab -
```

---

## Phase 7: Integration Testing

### Task 7.1: Test Webhook

```bash
curl -X POST http://localhost:5678/webhook/wazuh-alert \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2026-04-05T00:00:00-0500",
    "rule": {
      "level": 7,
      "description": "Test Alert",
      "id": "100",
      "groups": ["test"],
      "mitre": {"id": ["T1110"], "tactic": ["Brute Force"]}
    },
    "agent": {"id": "001", "name": "test-host"},
    "full_log": "Test alert for webhook verification"
  }'
```

### Task 7.2: Run Test Suite

```bash
python3 n8n/workflows/soc_test_suite.py
```

### Task 7.3: Verify Zammad Ticket

1. Open http://localhost:8080
2. Check for new ticket in SOC-Alerts group
3. Verify ticket has host tag in title

---

## Phase 8: Security Hardening

- [ ] Change all default passwords
- [ ] Enable 2FA on all services
- [ ] Configure firewall rules
- [ ] Enable SSL/TLS for production
- [ ] Review API permissions
- [ ] Set up backup procedures
- [ ] Document credentials securely

---

## Final Verification Checklist

### Service Status

```bash
# All containers running
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "soc-|wazuh"
```

### Access Verification

- [ ] n8n: http://localhost:5678
- [ ] Zammad: http://localhost:8080
- [ ] Wazuh: https://localhost:443

### Workflow Verification

- [ ] wazuh-alert-poller workflow ACTIVE
- [ ] agent1-dispatcher workflow ACTIVE
- [ ] agent2-responder workflow ACTIVE

### Alert Flow Verification

```bash
# Generate test alert
curl -X POST http://localhost:5678/webhook/wazuh-alert \
  -H "Content-Type: application/json" \
  -d '{"rule":{"level":10,"id":"999","description":"Test"},"agent":{"name":"test"}}'

# Check for ticket in Zammad
# Should appear within 30 seconds
```

---

## Sign-off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Technical Lead | | | |
| Security Analyst | | | |
| System Admin | | | |

## Notes

_Add implementation notes, issues encountered, and solutions found._
