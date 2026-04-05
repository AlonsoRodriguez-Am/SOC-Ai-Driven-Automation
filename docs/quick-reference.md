# Quick Reference Card

## Service URLs

| Service | URL | Purpose |
|---------|-----|---------|
| n8n | http://localhost:5678 | Workflow automation |
| Zammad | http://localhost:8080 | Ticketing system |
| Wazuh Dashboard | https://localhost:443 | SIEM dashboard |
| Wazuh API | https://localhost:55000 | SIEM API |

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| n8n | admin | *(set during install)* |
| Wazuh | admin | *(check credentials.md)* |
| Zammad Agent 1 | agent1@soc.lab | `SOC_Admin_2026!` |
| Zammad Agent 2 | agent2@soc.lab | `SOC_Admin_2026!` |
| Zammad Admin | analyst@soc.local | *(set during install)* |

## Common Commands

### Start/Stop Services
```bash
# Start all services
./scripts/start-services.sh start

# Stop all services
./scripts/start-services.sh stop

# Check status
./scripts/start-services.sh status
```

### Docker Commands
```bash
# View all containers
docker ps -a

# View logs
docker logs -f <container_name>

# Restart a service
docker restart <container_name>

# Access container shell
docker exec -it <container_name> /bin/bash
```

### Service-Specific Commands
```bash
# n8n
docker restart soc-n8n

# Zammad
docker restart soc-zammad-railsserver soc-zammad-websocket

# Wazuh
systemctl restart wazuh-manager
```

## File Locations

| Purpose | Path |
|---------|------|
| Scripts | `SOC-Ai-Driven-Automation/scripts/` |
| Configs | `SOC-Ai-Driven-Automation/*/config/` |
| Workflows | `SOC-Ai-Driven-Automation/n8n/workflows/` |

## Log Files

| Service | Log Location |
|---------|--------------|
| n8n | `docker logs soc-n8n` |
| Zammad Rails | `docker logs soc-zammad-railsserver` |
| Zammad WebSocket | `docker logs soc-zammad-websocket` |
| Wazuh | `/var/ossec/logs/ossec.log` |
| Wazuh Alerts | `/var/ossec/logs/alerts/alerts.json` |
| Alert Forwarder | `/opt/soc-automation/logs/forwarder.log` |

## API Endpoints

### n8n Webhooks
- **Wazuh Alert Poller**: `POST http://localhost:5678/webhook/wazuh-alert`
- **Agent 1 Dispatcher**: `POST http://localhost:5678/webhook/agent1-dispatcher`
- **Agent 2 Responder**: `POST http://localhost:5678/webhook/agent2-responder`

### Zammad API
- Base: `http://localhost:8080/api/v1`
- Tickets: `/tickets.json`
- Articles: `/tickets/{id}/articles.json`

### Wazuh API
- Base: `https://localhost:55000`
- Auth: `/security/user/authenticate`
- Agents: `/agents`
- Active Response: `/active-response`

## Key Ports

| Port | Service |
|------|---------|
| 443 | Wazuh Dashboard |
| 5678 | n8n |
| 8080 | Zammad Nginx |
| 9200 | Elasticsearch |
| 55000 | Wazuh API |

## Version Info

| Component | Version |
|-----------|---------|
| Kali Linux | 2026.1 |
| Docker | Latest |
| n8n | Latest |
| Zammad | 7.0 |
| Wazuh | 4.14.3 |
| PostgreSQL | 15 |
| Elasticsearch | 7.17 |

## Emergency Commands

```bash
# Full restart
./scripts/start-services.sh restart all

# Clean rebuild
docker-compose down -v
docker-compose up -d

# View all logs
docker-compose logs -f

### Verification Tools

| Purpose | Command |
|---------|---------|
| Start SOC Test Suite | `python3 n8n/workflows/soc_test_suite.py` |
| View History Log | `cat n8n/workflows/antigravity_history.md` |
| Force Agent 2 Analysis | `curl -X POST -H "Content-Type: application/json" -d '{"ticket_id": <ID>}' http://localhost:5678/webhook/agent2-responder` |
```