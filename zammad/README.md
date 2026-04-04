# Zammad Module

<div align="center">

**Open-Source Ticketing System for SOC Automation**

</div>

## Overview

Zammad provides the Human-in-the-Loop (HITL) interface for the SOC Automation system:
- **Ticket Management** - Create, assign, and track security incidents
- **API Integration** - Full REST API for automated ticket creation
- **Custom Fields** - SOC-specific fields for threat analysis
- **Email Integration** - Send notifications to analysts

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Initial Setup](#initial-setup)
4. [Configuration](#configuration)
5. [API Integration](#api-integration)
6. [Custom Fields](#custom-fields)
7. [Email Configuration](#email-configuration)
8. [Troubleshooting](#troubleshooting)
9. [Backup & Restore](#backup--restore)

---

## Prerequisites

### System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 4 GB | 8 GB |
| CPU | 2 cores | 4 cores |
| Disk | 20 GB | 50 GB |

### Dependencies

- Docker Engine 20.10+
- Docker Compose v2+

### Required Ports

| Port | Service |
|------|---------|
| 8080 | Zammad Nginx (HTTP) |
| 3000 | Rails Server |
| 9200 | Elasticsearch |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 11211 | Memcached |

---

## Installation

### Quick Start (Docker)

1. **Navigate to Zammad module:**
```bash
cd SOC-Ai-Driven-Automation/zammad
```

2. **Create environment file:**
```bash
cat > .env << 'EOF'
COMPOSE_PROJECT_NAME=soc-zammad
VERSION=7.0.0-0058
NGINX_PORT=8080
ZAMMAD_HTTP_TYPE=http
ZAMMAD_FQDN=zammad.local
TZ=America/New_York
POSTGRES_PASS=zammad_secure_pass_2026
EOF
```

3. **Start services:**
```bash
docker-compose up -d
```

4. **Wait for initialization:**
```bash
# This takes 3-5 minutes on first run
docker-compose logs -f zammad-railsserver
# Wait for: "Railsserver Websocket started"
```

5. **Access Zammad:**
- URL: http://localhost:8080
- Admin: admin@zammad.local / *(set below)*

---

## Initial Setup

### First-Time Configuration

1. **Open browser:** http://localhost:8080
2. **Follow setup wizard:**
   - Create admin account
   - Set organization name
   - Configure email (optional now, can do later)

### Create Admin Account

```
Email: admin@zammad.local
Password: SOC_Admin_2026!
Full Name: SOC Administrator
```

### Create SOC Groups

Navigate to: **Settings → Groups → Add Group**

| Group Name | Description |
|------------|-------------|
| SOC-Alerts | New security alerts requiring triage |
| SOC-Triage | Alerts under active analysis |
| SOC-Approved | Approved for automated remediation |
| SOC-FP | Confirmed false positives |

### Create SOC Users

Navigate to: **Settings → Users → Create User**

| User | Email | Role | Group |
|------|-------|------|-------|
| SOC Bot | bot@soc.local | Bot | All SOC groups |
| Analyst | analyst@soc.local | Agent | SOC-Alerts, SOC-Triage |
| Lead | lead@soc.local | Admin | All groups |

---

## Configuration

### Docker Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `COMPOSE_PROJECT_NAME` | Project name | soc-zammad |
| `VERSION` | Zammad version | 7.0.0-0058 |
| `NGINX_PORT` | HTTP port | 8080 |
| `ZAMMAD_HTTP_TYPE` | HTTP/HTTPS | http |
| `TZ` | Timezone | America/New_York |
| `POSTGRES_PASS` | DB password | *(required)* |
| `ELASTICSEARCH_ENABLED` | Enable search | true |

### Full .env Example

```bash
COMPOSE_PROJECT_NAME=soc-zammad
VERSION=7.0.0-0058
NGINX_PORT=8080
NGINX_EXPOSE_PORT=8080
ZAMMAD_HTTP_TYPE=http
ZAMMAD_FQDN=zammad.local
TZ=America/New_York
ELASTICSEARCH_ENABLED=true
ELASTICSEARCH_SCHEMA=http
ELASTICSEARCH_HOST=zammad-elasticsearch
ELASTICSEARCH_PORT=9200
POSTGRES_DB=zammad_production
POSTGRES_USER=zammad
POSTGRES_PASS=zammad_secure_pass_2026
POSTGRES_HOST=zammad-postgresql
POSTGRES_PORT=5432
REDIS_URL=redis://zammad-redis:6379
ELASTICSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
RESTART=always
```

---

## API Integration

### Authentication Methods

#### Method 1: API Token (Recommended)

1. **Create token:**
   - Settings → API → Add Token
   - Name: SOC Automation
   - Permissions: admin (or custom)
   - Copy the generated token

2. **Use in requests:**
```bash
curl -H "Authorization: Token token=YOUR_API_TOKEN" \
  http://localhost:8080/api/v1/tickets.json
```

#### Method 2: Session-Based Auth

```bash
# 1. Get CSRF token
curl -s -c cookies.txt http://localhost:8080/ | grep csrf-token

# 2. Login
curl -s -X POST http://localhost:8080/api/v1/signin \
  -H "Content-Type: application/json" \
  -H "X-CSRF-Token: YOUR_CSRF_TOKEN" \
  -b cookies.txt \
  -d '{"username":"admin@zammad.local","password":"PASS","fingerprint":"soc-bot"}'
```

### Key API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/tickets` | GET | List tickets |
| `/api/v1/tickets` | POST | Create ticket |
| `/api/v1/tickets/{id}` | GET | Get ticket |
| `/api/v1/tickets/{id}` | PUT | Update ticket |
| `/api/v1/tickets/{id}` | DELETE | Delete ticket |
| `/api/v1/tickets/{id}/articles` | GET | Get ticket articles |
| `/api/v1/tickets/{id}/articles` | POST | Add article |
| `/api/v1/users` | GET | List users |
| `/api/v1/groups` | GET | List groups |

### Create Ticket via API

```bash
# Using API token
curl -X POST http://localhost:8080/api/v1/tickets \
  -H "Content-Type: application/json" \
  -H "Authorization: Token token=YOUR_TOKEN" \
  -d '{
    "title": "Security Alert: SSH Brute Force",
    "group": "SOC-Alerts",
    "state": "new",
    "priority": "3",
    "article": {
      "body": "Alert Details:\\n- Rule: SSH Brute Force\\n- Level: 10\\n- Source: 192.168.1.100",
      "type": "note",
      "sender": "System"
    }
  }'
```

### Update Ticket (Add Analysis)

```bash
curl -X PUT http://localhost:8080/api/v1/tickets/123 \
  -H "Content-Type: application/json" \
  -H "Authorization: Token token=YOUR_TOKEN" \
  -d '{
    "group": "SOC-Approved",
    "state": "open",
    "priority": "2",
    "custom_fields": {
      "soc_confidence": 85,
      "soc_action": "approved"
    }
  }'
```

---

## Custom Fields

### Required SOC Fields

Navigate to: **Settings → Object Manager → Ticket → Add Field**

| Field Name | Type | Purpose |
|------------|------|---------|
| `soc_proposal` | Text Area | AI remediation proposal |
| `soc_confidence` | Number (0-100) | AI confidence score |
| `soc_action` | Select | pending/approved/rejected |
| `soc_executed` | Boolean | Remediation completed |
| `soc_mitre_id` | Text | MITRE ATT&CK technique ID |
| `soc_mitre_tactic` | Text | MITRE tactic |

### Import Custom Fields

```bash
# Using API
curl -X POST http://localhost:8080/api/v1/object_manager_attributes \
  -H "Authorization: Token token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "soc_proposal",
    "display": "SOC Remediation Proposal",
    "object": "Ticket",
    "data_type": "textarea",
    "data_option": {
      "type": "text",
      "rows": 5,
      "maxlength": 5000
    },
    "editable": true,
    "active": true,
    "position": 1
  }'
```

---

## Email Configuration

### SMTP Setup

Navigate to: **Settings → Channels → Email → Add Email Channel**

| Setting | Value |
|---------|-------|
| Type | SMTP |
| Host | smtp.gmail.com |
| Port | 587 |
| SSL/TLS | StartTLS |
| User | your-email@gmail.com |
| Password | *(App Password)* |

### Create Email Filters

Navigate to: **Settings → Channels → Email → Filters**

| Filter | Condition | Action |
|--------|-----------|--------|
| Auto-assign SOC | Subject contains "[ALERT]" | Set group: SOC-Alerts |
| Priority High | Subject contains "CRITICAL" | Set priority: 4 |

### Email Notifications

1. **User settings:**
   - Each user configures own notifications
   - Go to User Profile → Notifications

2. **Trigger notifications:**
   - Ticket created
   - Ticket assigned
   - State changed
   - Article added

---

## Troubleshooting

### Common Issues

#### Initialization Takes Too Long

```bash
# Check init container
docker logs soc-zammad-zammad-init-1

# Check database
docker exec soc-zammad-zammad-postgresql-1 pg_isready -U zammad
```

#### Assets Return 404

```bash
# Wait for initialization to complete
docker logs soc-zammad-zammad-railsserver | grep "started"

# Or restart
docker-compose restart zammad-railsserver
```

#### WebSocket Not Connecting

```bash
# Check websocket service
docker logs soc-zammad-zammad-websocket-1

# Verify port
docker port soc-zammad-zammad-websocket-1
```

#### API Returns 401

```bash
# Verify token is valid
curl -H "Authorization: Token token=YOUR_TOKEN" \
  http://localhost:8080/api/v1/users/me
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f zammad-railsserver

# Search logs
docker-compose logs | grep -i error
```

---

## Backup & Restore

### Backup

```bash
# Create backup directory
mkdir -p /opt/backups/zammad
cd /opt/backups/zammad

# Backup PostgreSQL
docker exec soc-zammad-zammad-postgresql-1 pg_dump -U zammad zammad_production > zammad_db_$(date +%Y%m%d).sql

# Backup volumes
docker run --rm -v soc-zammad_postgresql-data:/data -v $(pwd):/backup alpine \
  tar czf postgresql_data_$(date +%Y%m%d).tar.gz /data

docker run --rm -v soc-zammad_elasticsearch-data:/data -v $(pwd):/backup alpine \
  tar czf elasticsearch_data_$(date +%Y%m%d).tar.gz /data
```

### Restore

```bash
# Restore database
docker exec -i soc-zammad-zammad-postgresql-1 psql -U zammad zammad_production < zammad_db_YYYYMMDD.sql
```

---

## Security Hardening

1. **Enable HTTPS** - Use reverse proxy with SSL
2. **Restrict API access** - Use IP allowlisting
3. **Regular backups** - Schedule automated backups
4. **User management** - Regular audit of users
5. **Update regularly** - Keep Zammad updated

---

## Integration with SOC Automation

### Workflow

1. **n8n** receives Wazuh alert
2. **n8n** calls Gemini AI for analysis
3. **n8n** creates Zammad ticket via API
4. **Analyst** reviews and approves/rejects
5. **n8n** executes approved actions

### Example API Call from n8n

```json
{
  "node": "HTTP Request",
  "method": "POST",
  "url": "http://localhost:8080/api/v1/tickets",
  "authentication": "predefinedCredentialType",
  "header": {
    "Authorization": "Token token={{credentials.zammad_api_token}}",
    "Content-Type": "application/json"
  },
  "body": {
    "title": "Alert: {{json.rule.description}}",
    "group": "SOC-Alerts",
    "state": "new",
    "priority": "{{json.rule.level}}"
  }
}
```

---

## Next Steps

1. [Configure API Token](#api-integration)
2. [Set up Custom Fields](#custom-fields)
3. [Configure Email Notifications](#email-configuration)
4. [Integrate with n8n Workflows](../n8n/workflows/README.md)

---

## Additional Resources

- [Zammad Documentation](https://docs.zammad.org/)
- [Zammad API Documentation](https://docs.zammad.org/en/latest/api/index.html)
- [Zammad Community](https://community.zammad.org/)