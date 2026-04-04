#!/bin/bash
# Wazuh Agent Installation Script for vulnerable-machine
# Tailscale IP: 100.70.191.1

set -e

# Configuration
MANAGER_IP="100.70.191.1"  # This should be the Wazuh manager's IP accessible from the agent
# Or use hostname if on same network
MANAGER_HOST="kali-Sec"  # Update this to your actual manager hostname/IP

echo "========================================"
echo "Wazuh Agent Installation for vulnerable-machine"
echo "========================================"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo "Cannot detect OS"
    exit 1
fi

echo "Detected: $OS $VER"

# Install based on OS
case "$OS" in
    ubuntu|debian)
        echo "Installing for Debian/Ubuntu..."
        
        # Add Wazuh repository
        apt-get update
        apt-get install -y curl wget
        
        # Add repository key
        curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg 2>/dev/null || true
        echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
        
        apt-get update
        apt-get install -y wazuh-agent
        
        ;;
    centos|rhel|rocky|alma)
        echo "Installing for RHEL/CentOS..."
        cat > /etc/yum.repos.d/wazuh.repo << 'EOF'
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
priority=1
EOF
        yum install -y wazuh-agent
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

echo ""
echo "========================================"
echo "Configuring Wazuh Agent"
echo "========================================"

# Configure agent to connect to manager
# Using the IP that can reach the Wazuh manager (Tailscale or LAN)
# Update this to the actual Wazuh manager IP
MANAGER_ADDRESS="100.70.191.1"  # Change if manager has different IP

cat > /var/ossec/etc/ossec.conf << EOF
<ossec_config>
  <client>
    <server>
      <address>${MANAGER_ADDRESS}</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
  </client>

  <syscheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>
    <scan_on_start>yes</scan_on_start>
    <directories>/etc,/usr/bin,/usr/sbin</directories>
    <directories>/bin,/sbin</directories>
  </syscheck>

  <rootcheck>
    <disabled>no</disabled>
    <check_files>yes</check_files>
    <check_trojans>yes</check_trojans>
    <frequency>43200</frequency>
  </rootcheck>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/messages</location>
  </localfile>

  <buffer>
    <disabled>no</disabled>
    <queue_size>131072</queue_size>
  </buffer>
</ossec_config>
EOF

echo "Configuration written to /var/ossec/etc/ossec.conf"

# Get agent key from manager
# You need to run this ON THE MANAGER first:
# /var/ossec/bin/manage_agents -l  (to see agent ID)
# /var/ossec/bin/manage_agents -e 004  (to get the key for agent 004)

echo ""
echo "========================================"
echo "IMPORTANT: Register with Wazuh Manager"
echo "========================================"
echo "Run this on the Wazuh Manager server first:"
echo ""
echo "  /var/ossec/bin/manage_agents -l"
echo "  # Verify agent 004 is registered"
echo ""
echo "Then on THIS machine, run:"
echo ""
echo "  /var/ossec/bin/agent-auth -m <MANAGER_IP> -p 1515"
echo ""
echo "Where <MANAGER_IP> is the IP of your Wazuh manager"
echo ""

# If you already have the key, you can import it:
# /var/ossec/bin/manage_agents -i <KEY>

echo "To start the agent:"
echo "  systemctl start wazuh-agent"
echo "  systemctl enable wazuh-agent"
echo ""
echo "To check status:"
echo "  /var/ossec/bin/wazuh-control status"
echo ""