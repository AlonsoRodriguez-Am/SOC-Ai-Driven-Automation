# Google Antigravity IDE - Project Setup Guide

This guide covers installing, configuring, and using Google Antigravity IDE for managing the SOC Automation project.

## Installation

### Prerequisites
- Ubuntu/Debian Linux (or Kali Linux)
- Root/sudo access
- Internet connection

### Install Steps

```bash
# 1. Create keyring directory
sudo mkdir -p /etc/apt/keyrings

# 2. Add signing key
curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
  sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg

# 3. Add repository
echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
  sudo tee /etc/apt/sources.list.d/antigravity.list

# 4. Install
sudo apt update
sudo apt install antigravity
```

### Verify Installation
```bash
antigravity --version
```

---

## Opening the Project

### Method 1: Command Line
```bash
# Open current directory
antigravity .

# Open specific project folder
antigravity /home/blueteam/repositories/SOC-Ai-Driven-Automation/
```

### Method 2: Using Desktop

1. Launch Antigravity from applications menu
2. File → Open Folder
3. Navigate to `/home/blueteam/repositories/SOC-Ai-Driven-Automation/`

---

## Project Structure

```
/home/blueteam/repositories/SOC-Ai-Driven-Automation/
├── n8n/
│   ├── workflows/
│   │   ├── wazuh-alert-poller.json
│   │   ├── agent1-dispatcher.json
│   │   └── agent2-responder.json
│   ├── docker-compose.yml
│   ├── MANAGEMENT.md       # n8n management guide
│   ├── README.md
│   └── troubleshooting.md
└── (other project folders...)
```

---

## Managing Workflow Changes

### Workflow Files Location
```
/home/blueteam/repositories/SOC-Ai-Driven-Automation/n8n/workflows/
```

### Opening for Editing
```bash
antigravity /home/blueteam/repositories/SOC-Ai-Driven-Automation/n8n/workflows/
```

### Important JSON Rules

When editing workflow JSON files in Antigravity:

1. **Always include HTTP method** for HTTP Request nodes:
   ```json
   {
     "parameters": {
       "method": "POST",
       "url": "https://api.example.com/endpoint",
       ...
     }
   }
   ```

2. **Validate JSON syntax** before saving - use `Ctrl+Shift+P` → "Validate JSON"

3. **Keep API keys secure** - don't commit keys to public repos

---

## Docker Integration

### Managing n8n from Antigravity Terminal

Open integrated terminal in Antigravity (`Ctrl+``) and run:

```bash
# Navigate to n8n folder
cd /home/blueteam/repositories/SOC-Ai-Driven-Automation/n8n/

# Stop n8n
docker-compose down

# Start n8n
docker-compose up -d

# View logs
docker logs soc-n8n -f
```

### Common Docker Commands

```bash
# Check container status
docker ps | grep soc-n8n

# Restart n8n
docker restart soc-n8n

# View container logs
docker logs soc-n8n --tail 100
```

---

## Testing Workflows

### Test Flow

1. **Start n8n** (if not running):
   ```bash
   cd /home/blueteam/repositories/SOC-Ai-Driven-Automation/n8n/
   docker-compose up -d
   ```

2. **Re-import workflow** in n8n UI:
   - Open http://localhost:5678
   - Delete old workflow
   - Import updated JSON
   - Activate

3. **Test via curl**:
   ```bash
   curl -X POST http://localhost:5678/webhook/wazuh-alert \
     -H "Content-Type: application/json" \
     -d '{"rule":{"level":7,"id":"100","description":"Test"},"agent":{"name":"test"},"data":{"srcip":"1.1.1.1"}}'
   ```

4. **Check results**:
   - n8n UI: Check execution history
   - Terminal: `docker logs soc-n8n --tail 30`
   - Zammad: Check for new ticket at http://localhost:8080

### Debugging Tips

- **Open n8n logs** in terminal panel while testing
- **Use webhook-test URL** for single test: `http://localhost:5678/webhook-test/wazuh-alert`
- **Check execution data** in SQLite:
  ```bash
  sqlite3 /opt/soc-automation/n8n/data/database.sqlite \
    "SELECT id, status FROM execution_entity ORDER BY id DESC LIMIT 3;"
  ```

---

## Project Workflow with Antigravity

### Step-by-Step Process

1. **Open Project**
   ```bash
   antigravity /home/blueteam/repositories/SOC-Ai-Driven-Automation/
   ```

2. **Navigate to n8n workflows**
   - Use sidebar to browse to `n8n/workflows/`

3. **Edit JSON file**
   - Click on workflow file
   - Make changes with proper JSON syntax
   - **Remember**: Add `method: "POST"` to HTTP Request nodes

4. **Save and close** - `Ctrl+S`, then close tab

5. **Test the workflow**:
   ```bash
   # In integrated terminal
   cd /home/blueteam/repositories/SOC-Ai-Driven-Automation/n8n/
   docker-compose restart soc-n8n
   
   # Test webhook
   curl -X POST http://localhost:5678/webhook/wazuh-alert \
     -H "Content-Type: application/json" \
     -d '{"rule":{"level":7,"id":"100","description":"Test"},"agent":{"name":"test"},"data":{"srcip":"1.1.1.1"}}'
   ```

6. **Verify**:
   - Check n8n execution history
   - Verify Zammad ticket created

7. **Commit changes** (if using git):
   ```bash
   cd /home/blueteam/repositories/SOC-Ai-Driven-Automation/
   git add n8n/workflows/
   git commit -m "Updated workflow changes"
   ```

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+S` | Save file |
| `Ctrl+Shift+P` | Command Palette |
| `Ctrl+`` | Open terminal |
| `Ctrl+B` | Toggle sidebar |
| `Ctrl+P` | Quick file open |
| `F5` | Start debugging |
| `Ctrl+Shift+F` | Find in files |

---

## Troubleshooting Antigravity

### "Failed to load libgtk"

Install missing dependencies:
```bash
sudo apt install libgtk-3-0 libgbm1 libasound2
```

### "Cannot open display"

Ensure X11 forwarding or use:
```bash
antigravity --no-sandbox
```

### Slowness or Freezing

- Reduce opened file tabs
- Disable extensions temporarily
- Increase RAM allocation

---

## Configuration Files

### n8n Environment

The n8n container uses these environment variables (defined in docker-compose.yml):
- `N8N_BASIC_AUTH_ACTIVE=true`
- `N8N_BASIC_AUTH_USER=admin@soc.local`
- `N8N_BASIC_AUTH_PASSWORD=SOC_Automation_2026!`
- `N8N_HOST=0.0.0.0`
- `N8N_PORT=5678`

### Access n8n UI
- URL: http://localhost:5678
- Username: admin@soc.local
- Password: SOC_Automation_2026!

---

## Best Practices

1. **Always validate JSON** before importing to n8n
2. **Test changes incrementally** - one change at a time
3. **Keep terminal visible** - watch logs while testing
4. **Use version control** - commit workflow changes regularly
5. **Document modifications** - update MANAGEMENT.md for significant changes
6. **Stop containers before major edits** - prevents locked database issues

---

## Useful Links

- [n8n Documentation](https://docs.n8n.io/)
- [Groq API Docs](https://console.groq.com/docs)
- [Zammad API Docs](https://user-docs.zammad.org/en/latest/api/index.html)
- [Google Antigravity](https://antigravity.google/)

---

*Last updated: 2026-04-05*
