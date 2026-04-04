# n8n Troubleshooting Guide

## Overview

This guide covers common issues and solutions for n8n in the SOC Automation system.

---

## Table of Contents

1. [Service Issues](#service-issues)
2. [Workflow Issues](#workflow-issues)
3. [Webhook Issues](#webhook-issues)
4. [Credential Issues](#credential-issues)
5. [API Integration Issues](#api-integration-issues)
6. [Performance Issues](#performance-issues)
7. [Docker Issues](#docker-issues)

---

## Service Issues

### n8n Not Starting

**Symptoms:** Container fails to start or exits immediately

**Diagnosis:**
```bash
# Check container status
docker ps -a | grep n8n

# Check logs
docker logs soc-n8n

# Check volume permissions
ls -la ./data
```

**Solutions:**

1. **Fix volume permissions:**
```bash
chmod -R 777 ./data
chown -R 1000:1000 ./data
```

2. **Check port availability:**
```bash
ss -tlnp | grep 5678
# Kill process if needed
```

3. **Check Docker resources:**
```bash
docker system df
```

4. **Restart n8n:**
```bash
docker restart soc-n8n
```

### Cannot Access n8n UI

**Symptoms:** Cannot reach http://localhost:5678

**Solutions:**

1. **Check container is running:**
```bash
docker ps | grep soc-n8n
```

2. **Check port mapping:**
```bash
docker port soc-n8n
```

3. **Check logs for errors:**
```bash
docker logs soc-n8n | tail -50
```

4. **Test locally in container:**
```bash
docker exec soc-n8n curl -s localhost:5678
```

---

## Workflow Issues

### Workflow Not Activating

**Symptoms:** Toggle switch won't stay on

**Solutions:**

1. **Check for errors:**
- Look for red nodes
- Check execution history

2. **Check trigger node:**
- Ensure trigger is valid
- Test trigger manually

3. **Check credentials:**
- Verify all credentials exist
- Test credentials

### Execution Failed

**Symptoms:** Workflow execution shows red status

**Diagnosis:**
```bash
# In n8n UI:
# 1. Click on execution
# 2. Check error message
# 3. Check node that failed
```

**Solutions:**

1. **Check error message:**
- Read the error details
- Note the failing node

2. **Common causes:**
- Invalid credentials
- API endpoint changed
- Network timeout
- Invalid JSON

3. **Fix specific node:**
- Click on failing node
- Check parameters
- Test API call manually

### Workflow Not Triggering

**Symptoms:** Schedule trigger doesn't fire

**Solutions:**

1. **Verify schedule:**
```json
{
  "rule": {
    "interval": [{"field": "minutes"}]
  }
}
```

2. **Check timezone:**
- Ensure GENERIC_TIMEZONE is correct

3. **Check is active:**
- Toggle must be ON

---

## Webhook Issues

### Webhook Not Found

**Symptoms:** "Webhook not found" error

**Solutions:**

1. **Make sure workflow is ACTIVE:**
- Click the toggle in top-right
- Toggle must be green/ON

2. **Check webhook path:**
- URL must match exactly
- Case-sensitive

3. **Restart n8n:**
```bash
docker restart soc-n8n
```

4. **Check n8n version:**
- In v2.x, webhooks may need recreation

### Webhook Returns 404

**Diagnosis:**
```bash
# Test webhook URL
curl -X POST http://localhost:5678/webhook/wazuh-alert
```

**Solutions:**

1. **Verify workflow is active:**
- n8n UI → Workflow → Active (must be ON)

2. **Check webhook node:**
- Webhook path: `wazuh-alert`
- HTTP Method: POST
- Response Mode: onReceived

3. **Recreate webhook:**
- Deactivate workflow
- Delete webhook node
- Add new webhook node
- Activate workflow

### Webhook Timeout

**Solutions:**

1. **Increase timeout:**
```yaml
environment:
  - EXECUTIONS_TIMEOUT=600
```

2. **Add continueOnFail:**
- Set on problematic nodes
- Allows workflow to continue

3. **Split workflow:**
- Split long-running tasks
- Use separate workflows

---

## Credential Issues

### Credentials Not Working

**Symptoms:** API calls fail with 401/403

**Solutions:**

1. **Verify credentials exist:**
- Settings → Credentials

2. **Test API manually:**
```bash
# Wazuh
TOKEN=$(curl -s -k -X POST "https://localhost:55000/security/user/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"PASS"}' | jq -r '.token')

# Zammad
curl -H "Authorization: Token token=YOUR_TOKEN" \
  http://localhost:8080/api/v1/users/me
```

3. **Regenerate tokens:**
- Wazuh: Dashboard → API → Generate token
- Zammad: Settings → API → Add Token
- Gemini: Google AI Studio → Create API Key

### Cannot Save Credentials

**Solutions:**

1. **Check credential type:**
- Use correct authentication type

2. **Check required fields:**
- All fields must be filled

3. **Check credential name:**
- Must be unique

---

## API Integration Issues

### Wazuh API Errors

**Solutions:**

1. **Check token:**
```bash
curl -k -H "Authorization: Bearer TOKEN" \
  https://localhost:55000/
```

2. **Check certificate:**
- Use `-k` flag for self-signed cert

3. **Check permissions:**
- Token needs appropriate access

### Zammad API Errors

**Solutions:**

1. **Verify API token:**
```bash
curl -H "Authorization: Token token=TOKEN" \
  http://localhost:8080/api/v1/users/me
```

2. **Check token permissions:**
- Admin permission needed for full access

3. **Verify group exists:**
```bash
curl -H "Authorization: Token token=TOKEN" \
  http://localhost:8080/api/v1/groups
```

### Gemini API Errors

**Solutions:**

1. **Verify API key:**
- Check in Google AI Studio
- Ensure billing is enabled

2. **Check quota:**
```bash
# API returns quota errors
```

3. **Verify endpoint:**
- Use correct endpoint URL
- Check for typos

4. **Check model:**
- gemini-1.5-pro is current model

---

## Performance Issues

### Slow Execution

**Solutions:**

1. **Check execution time:**
- In n8n UI → Executions

2. **Optimize nodes:**
- Remove unnecessary nodes
- Reduce API calls
- Use batching

3. **Add caching:**
- Cache frequently accessed data

4. **Increase timeout:**
```yaml
environment:
  - EXECUTIONS_TIMEOUT=600
  - EXECUTIONS_TIMEOUT_MAX=3600
```

### High Memory Usage

**Solutions:**

1. **Check memory:**
```bash
docker stats soc-n8n
```

2. **Reduce execution data:**
```yaml
environment:
  - EXECUTIONS_DATA_PRUNE=true
  - EXECUTIONS_DATA_MAX_AGE=24
```

3. **Increase memory:**
```yaml
environment:
  - NODE_OPTIONS=--max-old-space-size=2048
```

---

## Docker Issues

### Container in Restart Loop

**Diagnosis:**
```bash
# Check restart count
docker ps -a | grep soc-n8n

# Check logs
docker-compose logs n8n
```

**Solutions:**

1. **Check volume:**
```bash
ls -la ./data
chmod -R 777 ./data
```

2. **Check port:**
```bash
ss -tlnp | grep 5678
```

3. **Recreate container:**
```bash
docker-compose down
docker-compose up -d
```

### Volume Permissions

**Solutions:**

1. **Fix ownership:**
```bash
chown -R 1000:1000 ./data
```

2. **Fix permissions:**
```bash
chmod -R 755 ./data
chmod -R 777 ./data/n8n-files
```

---

## Log Reference

### View n8n Logs

```bash
# Docker logs
docker logs soc-n8n

# Follow logs
docker logs -f soc-n8n

# Last 100 lines
docker logs --tail=100 soc-n8n

# Docker compose logs
docker-compose logs -f n8n
```

### View Execution Logs

In n8n UI:
1. Go to **Executions**
2. Click on execution
3. View each node's input/output

---

## Emergency Recovery

### Reset n8n

```bash
# WARNING: Deletes all workflows and credentials
docker-compose down
rm -rf ./data/*
docker-compose up -d
```

### Restore from Backup

```bash
# Restore data directory
docker-compose down
rm -rf ./data
tar -xzvf n8n-backup-YYYYMMDD.tar.gz -C ./
docker-compose up -d
```

---

## Get Help

1. Check [n8n Documentation](https://docs.n8n.io/)
2. Search [n8n Community](https://community.n8n.io/)
3. Check [n8n GitHub](https://github.com/n8n-io/n8n)