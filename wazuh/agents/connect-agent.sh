#!/bin/bash
# Quick connect script for vulnerable-machine to connect to Wazuh manager
# Run this on the vulnerable-machine

set -e

echo "========================================"
echo "Connecting to Wazuh Manager"
echo "========================================"

# Wazuh Manager IP (update this to your actual manager IP)
# If on Tailscale, use the Tailscale IP of the manager
MANAGER_IP="100.70.191.1"  # Update to your Wazuh manager's IP

echo "Manager IP: $MANAGER_IP"

# Register with manager (if not already done)
echo ""
echo "Attempting agent authentication..."
/var/ossec/bin/agent-auth -m $MANAGER_IP -p 1515 -v

echo ""
echo "Starting Wazuh agent..."
systemctl start wazuh-agent
systemctl enable wazuh-agent

echo ""
echo "Checking status..."
/var/ossec/bin/wazuh-control status

echo ""
echo "To check connection on manager:"
echo "  /var/ossec/bin/manage_agents -l"