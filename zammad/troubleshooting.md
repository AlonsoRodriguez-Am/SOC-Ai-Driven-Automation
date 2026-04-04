# Zammad Troubleshooting Guide

## Overview

This guide covers common issues and solutions for Zammad deployment in the SOC Automation system.

---

## Table of Contents

1. [Service Issues](#service-issues)
2. [Initialization Issues](#initialization-issues)
3. [API Issues](#api-issues)
4. [Login Issues](#login-issues)
5. [Email Issues](#email-issues)
6. [Performance Issues](#performance-issues)
7. [Database Issues](#database-issues)
8. [Log Reference](#log-reference)

---

## Service Issues

### Container Not Starting

**Symptoms:** Container exits immediately after start

**Diagnosis:**
```bash
# Check all containers
docker-compose ps

# Check specific container logs
docker-compose logs zammad-railsserver
```

**Solutions:**

1. **Check dependencies:**
```bash
# Ensure PostgreSQL is healthy
docker-compose ps | grep postgresql

# Ensure Elasticsearch is healthy  
docker-compose ps | grep elasticsearch
```

2. **Check port conflicts:**
```bash
ss -tlnp | grep -E '8080|3000|9200|5432'
```

3. **Recreate volumes:**
```bash
docker-compose down -v
docker-compose up -d
```

4. **Check resources:**
```bash
docker system df
```

### Service Keeps Restarting

**Symptoms:** Container in restart loop

**Diagnosis:**
```bash
# Check restart count
docker ps -a | grep zammad

# View recent logs
docker-compose logs --tail=100 zammad-railsserver
```

**Solutions:**

1. **Check database connection:**
```bash
docker exec soc-zammad-postgresql-1 pg_isready -U zammad
```

2. **Check Elasticsearch:**
```bash
docker exec soc-zammad-elasticsearch-1 curl -s localhost:9200
```

3. **Increase timeout:**
```bash
# Edit docker-compose.yml and add to railsserver:
environment:
  - ZAMMAD_INIT_TIMEOUT=600
```

---

## Initialization Issues

### First Start Takes Very Long

**Symptoms:** Railsserver doesn't become ready after 5+ minutes

**Diagnosis:**
```bash
# Watch initialization logs
docker-compose logs -f zammad-railsserver
```

**Solutions:**

1. **Wait for PostgreSQL:**
```bash
# Check if DB is ready
docker exec soc-zammad-postgresql-1 pg_isready -U zammad

# Check DB size
docker exec soc-zammad-postgresql-1 psql -U zammad -d zammad_production -c "SELECT pg_size_pretty(pg_database_size('zammad_production'));"
```

2. **Wait for Elasticsearch:**
```bash
# Check ES health
docker exec soc-zammad-elasticsearch-1 curl -s localhost:9200/_cluster/health
```

3. **Check init container:**
```bash
# First run includes schema setup
docker logs soc-zammad-zammad-init-1 2>&1 | tail -50
```

### Assets Return 404

**Symptoms:** CSS/JS files not loading, blank page

**Diagnosis:**
```bash
# Check if assets are compiled
docker exec soc-zammad-railsserver ls -la /opt/zammad/public/assets/
```

**Solutions:**

1. **Wait for initialization to complete:**
```bash
# Initialization takes 3-5 minutes
docker-compose logs | grep -i "Asset precompilation"
```

2. **Force asset compile:**
```bash
docker exec soc-zammad-railsserver rails assets:precompile
```

3. **Restart railsserver:**
```bash
docker-compose restart zammad-railsserver
```

### Database Schema Not Created

**Symptoms:** Tables don't exist, errors about missing columns

**Diagnosis:**
```bash
# Check tables
docker exec soc-zammad-postgresql-1 psql -U zammad -d zammad_production -c "\dt"
```

**Solutions:**

1. **Run migrations:**
```bash
docker exec soc-zammad-railsserver rails db:migrate
```

2. **Reset database:**
```bash
# WARNING: This deletes all data
docker-compose down -v
docker-compose up -d
```

---

## API Issues

### API Returns 401 Unauthorized

**Symptoms:** All API requests return 401

**Diagnosis:**
```bash
# Test token
curl -H "Authorization: Token token=YOUR_TOKEN" \
  http://localhost:8080/api/v1/users/me
```

**Solutions:**

1. **Verify token exists:**
```bash
# In Zammad UI: Settings → API → Check tokens
```

2. **Check token format:**
```bash
# Must be "Token token=YOUR_TOKEN" not just "YOUR_TOKEN"
curl -H "Authorization: Token token=abc123..." http://localhost:8080/api/v1/users/me
```

3. **Create new token:**
```bash
# In Zammad UI:
# Settings → API → Add Token
```

### API Returns 422 Validation Error

**Symptoms:** Cannot create/update tickets

**Diagnosis:**
```bash
# Check response details
curl -X POST ... | jq
```

**Solutions:**

1. **Check required fields:**
```json
{
  "error": "Unable to create ticket",
  "details": {
    "title": ["is required"]
  }
}
```

2. **Check field types:**
```bash
# Priority must be string like "2" not number 2
curl -X POST ... -d '{"priority": "2"}'
```

3. **Check group exists:**
```bash
# List groups first
curl -H "Authorization: Token token=..." http://localhost:8080/api/v1/groups
```

### API Slow Response

**Symptoms:** API requests take 5+ seconds

**Solutions:**

1. **Add pagination:**
```bash
# Limit results
curl "?limit=50"
```

2. **Use filters:**
```bash
# Only get needed data
curl "?state=new&group=SOC-Alerts"
```

3. **Check Elasticsearch:**
```bash
docker exec soc-zammad-elasticsearch-1 curl -s localhost:9200/_cluster/health
```

---

## Login Issues

### Cannot Login to Web Interface

**Symptoms:** Login page shows but credentials don't work

**Solutions:**

1. **Reset password via console:**
```bash
docker exec -it soc-zammad-railsserver rails c
User.find_by(email: 'admin@zammad.local')
user = User.find_by(email: 'admin@zammad.local')
user.password = 'NewPassword123!'
user.save!
exit
```

2. **Check authentication backend:**
```bash
# In Settings → Authentication → System
```

3. **Check session settings:**
```bash
# Settings → Sessions → Increase timeout
```

### Forgot Admin Password

**Solution:**

```bash
# Access Rails console
docker exec -it soc-zammad-railsserver rails c

# Find admin and reset
user = User.find_by(email: 'admin@zammad.local')
user.password = 'SOC_Admin_2026!'
user.save!
puts "Password reset successful"
exit
```

### Session Expires Immediately

**Symptoms:** Login works but immediately logged out

**Solutions:**

1. **Check cookie settings:**
```bash
# In Settings → Sessions
# Set cookie domain to localhost
```

2. **Check Redis:**
```bash
docker exec soc-zammad-redis-1 redis-cli ping
```

---

## Email Issues

### SMTP Not Sending Emails

**Symptoms:** Email notifications not delivered

**Diagnosis:**
```bash
# Check channel status
# Settings → Channels → Email → Check status
```

**Solutions:**

1. **Verify SMTP settings:**
```bash
# Settings → Channels → Email → Edit
# Ensure correct: host, port, user, password
```

2. **Test SMTP connection:**
```bash
# In Zammad: Settings → Channels → Email → "Check MX"
```

3. **Check App Password (Gmail):**
```bash
# If using Gmail, ensure App Password not regular password
# Go to myaccount.google.com → Security → App Passwords
```

4. **Check email log:**
```bash
# In Zammad: Admin → Logs → Email
```

### Email Filter Not Working

**Symptoms:** Incoming emails not creating tickets

**Solutions:**

1. **Enable channel:**
```bash
# Settings → Channels → Email → Add → Inbound
```

2. **Configure filter:**
```bash
# Settings → Channels → Email → Filters
# Ensure conditions match incoming emails
```

3. **Check IMAP settings:**
```bash
# If using IMAP, verify:
# - Host, port, user, password
# - SSL/TLS enabled
```

---

## Performance Issues

### Slow Page Load

**Symptoms:** Dashboard takes 10+ seconds to load

**Solutions:**

1. **Check Elasticsearch:**
```bash
docker exec soc-zammad-elasticsearch-1 curl -s localhost:9200/_cluster/health
```

2. **Clear cache:**
```bash
docker exec soc-zammad-railsserver rails cache:clear
```

3. **Restart services:**
```bash
docker-compose restart
```

### High Memory Usage

**Symptoms:** Container using excessive RAM

**Solutions:**

1. **Check current usage:**
```bash
docker stats
```

2. **Reduce workers:**
```bash
# In docker-compose.yml:
environment:
  - WEB_CONCURRENCY=2
  - MAX_THREADS=5
```

3. **Add swap:**
```bash
# On host
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
```

### Elasticsearch Full

**Symptoms:** Search not working, errors about ES

**Solutions:**

1. **Check disk space:**
```bash
docker exec soc-zammad-elasticsearch-1 df -h
```

2. **Clear old indices:**
```bash
docker exec soc-zammad-elasticsearch-1 \
  curl -X DELETE "localhost:9200/_all"
```

3. **Reindex:**
```bash
docker exec soc-zammad-railsserver rails searchindex:rebuild
```

---

## Database Issues

### PostgreSQL Connection Failed

**Symptoms:** Railsserver can't connect to database

**Diagnosis:**
```bash
docker exec soc-zammad-postgresql-1 pg_isready -U zammad
```

**Solutions:**

1. **Check credentials:**
```bash
# Verify POSTGRES_USER and POSTGRES_PASSWORD in .env
docker-compose config | grep -A5 POSTGRES
```

2. **Check database exists:**
```bash
docker exec soc-zammad-postgresql-1 psql -U postgres -l | grep zammad
```

3. **Restart PostgreSQL:**
```bash
docker-compose restart zammad-postgresql
```

### Database Corruption

**Symptoms:** Random errors, missing data

**Solutions:**

1. **Check for corruption:**
```bash
docker exec soc-zammad-postgresql-1 psql -U zammad -d zammad_production -c "SELECT version();"
```

2. **Repair if possible:**
```bash
# Not always possible, may need restore
docker exec soc-zammad-postgresql-1 psql -U zammad -d zammad_production -c "VACUUM FULL;"
```

3. **Restore from backup:**
```bash
docker exec -i soc-zammad-postgresql-1 psql -U zammad zammad_production < backup.sql
```

---

## Log Reference

### Docker Compose Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f zammad-railsserver
docker-compose logs -f zammad-websocket

# Search for errors
docker-compose logs | grep -i error
```

### Application Logs

```bash
# Inside container
docker exec soc-zammad-railsserver tail -f /opt/zammad/log/production.log

# Nginx logs
docker exec soc-zammad-nginx tail -f /var/log/zammad/nginx.access.log
```

### PostgreSQL Logs

```bash
docker logs soc-zammad-postgresql 2>&1 | tail -50
```

---

## Emergency Recovery

### Complete Reset

```bash
# WARNING: Deletes all data
docker-compose down
docker volume rm soc-zammad_postgresql-data
docker volume rm soc-zammad_elasticsearch-data
docker-compose up -d
```

### Restore from Backup

```bash
# Restore database
docker exec -i soc-zammad-postgresql-1 psql -U zammad zammad_production < backup.sql

# Reindex search
docker exec soc-zammad-railsserver rails searchindex:rebuild
```

---

## Get Help

1. Check [Zammad Documentation](https://docs.zammad.org/)
2. Search [Zammad Community](https://community.zammad.org/)
3. Check [GitHub Issues](https://github.com/zammad/zammad/issues)