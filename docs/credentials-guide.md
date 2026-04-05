# Credentials Guide

## Overview

This guide documents the credentials required for the SOC Automation system and how to manage them securely.

---

## Service Credentials

### Wazuh

| Credential | Default Value | Where to Find |
|------------|---------------|----------------|
| Dashboard User | `admin` | Set during installation |
| Dashboard Password | `rCH9ff?ATZN3iq7hrldFar9SCmAR03j*` | Check installation output |
| API Token | *(generated)* | Dashboard → API → Generate Token |

**Get API Token:**
```bash
TOKEN=$(curl -s -k -X POST "https://localhost:55000/security/user/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"user":"admin","password":"YOUR_PASSWORD"}' | jq -r '.token')
echo $TOKEN
```

### Zammad

| Credential | Default Value | Where to Find |
|------------|---------------|----------------|
| Admin Email | `admin@zammad.local` | Set during installation |
| Admin Password | `SOC_Admin_2026!` | Set during installation |
| API Token | *(generated)* | Settings → API → Add Token |

**Get API Token:**
1. Login to Zammad as admin
2. Go to **Settings → API**
3. Click **Add Token**
4. Copy the generated token

### n8n

| Credential | Default Value | Where to Find |
|------------|---------------|----------------|
| Admin User | `admin` | Set via environment variable |
| Admin Password | `SOC_Automation_2026!` | Set via environment variable |

### Groq AI

| Credential | Where to Find |
|------------|---------------|
| API Key | [Groq Cloud Console](https://console.groq.com/keys) |

**Get API Key:**
1. Go to Groq Cloud Console
2. Click **API Keys**
3. Create new API key
4. Copy the key

---

## Agent Identities (Zammad)

The system uses specific identities for auditing. These users must be created in Zammad with the following details:

| Identity | Email | Password | Role |
|----------|-------|----------|------|
| **Agent 1** | `agent1@soc.lab` | `SOC_Admin_2026!` | Agent |
| **Agent 2** | `agent2@soc.lab` | `SOC_Admin_2026!` | Agent |

### Basic Auth Encoding

For n8n HTTP Request nodes using Basic Auth, encode the credentials as `base64(email:password)`:

- **Agent 1**: `YWdlbnQxQHNvYy5sYWI6U09DX0FkbWluXzIwMjYh`
- **Agent 2**: `YWdlbnQyQHNvYy5sYWI6U09DX0FkbWluXzIwMjYh`

### Gmail (for notifications)

| Credential | Where to Find |
|------------|---------------|
| App Password | [Google Account Security](https://myaccount.google.com/security) |

**Get App Password:**
1. Go to Google Account → Security
2. Enable 2-Step Verification
3. Go to App Passwords
4. Create new app password for "Mail"
5. Copy the 16-character password

---

## Credential Storage

### In n8n

Store credentials in **Settings → Credentials**:

1. **wazuh-api**
   - Type: HTTP Request
   - Auth: Header
   - Header Name: `Authorization`
   - Header Value: `Bearer {{TOKEN}}`

2. **zammad-api**
   - Type: HTTP Request
   - Auth: Header
   - Header Name: `Authorization`
   - Header Value: `Token token={{TOKEN}}`

3. **groq-api**
   - Type: HTTP Request
   - Auth: Header
   - Header Name: `Authorization`
   - Header Value: `Bearer {{API_KEY}}`

4. **gmail-smtp**
   - Type: Email (SMTP)
   - Host: `smtp.gmail.com`
   - Port: `587`
   - User: `your-email@gmail.com`
   - Password: `{{APP_PASSWORD}}`

---

## Security Best Practices

### Do NOT

- ❌ Commit credentials to version control
- ❌ Share credentials via chat/email
- ❌ Use default passwords in production
- ❌ Store credentials in plain text files

### DO

- ✅ Use environment variables
- ✅ Store in secure credential manager
- ✅ Rotate passwords regularly
- ✅ Use unique passwords for each service

---

## Environment Variables (.env.example)

Create a `.env` file for Docker Compose based on this template:

```bash
# Wazuh
WAZUH_API_USER=admin
WAZUH_API_PASSWORD=your_secure_password

# Zammad
ZAMMAD_API_TOKEN=your_zammad_token
AGENT1_EMAIL=agent1@soc.lab
AGENT1_PASS=SOC_Admin_2026!
AGENT2_EMAIL=agent2@soc.lab
AGENT2_PASS=SOC_Admin_2026!

# Groq AI
GROQ_API_KEY=your_groq_key

# Email
GMAIL_USER=your-email@gmail.com
GMAIL_APP_PASSWORD=your_app_password
```

---

## Rotating Credentials

### Wazuh

1. Login to Dashboard
2. Go to **Settings → API**
3. Generate new token
4. Update n8n credential

### Zammad

1. Login to Zammad
2. Go to **Settings → API**
3. Revoke old token
4. Create new token
5. Update n8n credential

### n8n

1. Access n8n UI
2. Go to **Settings → Credentials**
3. Update password

---

## Backup Credentials

Before system rebuild, export credentials:

```bash
# Export n8n credentials (manual via UI)
# Settings → Credentials → Export
```

---

## Emergency Recovery

If you lose credentials:

1. **Wazuh:** Reset admin password via `/var/ossec/bin/manage_agents -P`

2. **Zammad:** Reset via Rails console:
   ```bash
   docker exec -it soc-zammad-railsserver rails c
   user = User.find_by(email: 'admin@zammad.local')
   user.password = 'NewPassword123!'
   user.save!
   ```

3. **n8n:** Recreate via environment variables

---

## Next Steps

After configuring credentials:

1. [Configure n8n Credentials](../n8n/README.md#credentials)
2. [Set up Wazuh API Integration](../wazuh/integration/README.md)
3. [Configure Zammad API Access](../zammad/api/README.md)