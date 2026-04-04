#!/usr/bin/env python3
"""
Wazuh Alert Forwarder for SOC Automation

This script reads Wazuh alerts and forwards them to n8n for processing.
It tracks the last processed position to avoid duplicates.

Author: SOC Automation Team
Version: 1.0.0
"""

import json
import os
import sys
import time
import logging
from datetime import datetime
from pathlib import Path
import requests

# Configuration
N8N_WEBHOOK_URL = os.environ.get('N8N_WEBHOOK_URL', 'http://localhost:5678/webhook/wazuh-alert')
WAZUH_ALERTS_FILE = os.environ.get('WAZUH_ALERTS_FILE', '/var/ossec/logs/alerts/alerts.json')
STATE_FILE = os.environ.get('STATE_FILE', '/opt/soc-automation/logs/last_processed_pos')
LOG_FILE = os.environ.get('LOG_FILE', '/opt/soc-automation/logs/forwarder.log')
MIN_ALERT_LEVEL = int(os.environ.get('MIN_ALERT_LEVEL', '5'))
HTTP_TIMEOUT = int(os.environ.get('HTTP_TIMEOUT', '30'))

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def get_last_position():
    """Read the last processed position from state file."""
    try:
        if os.path.exists(STATE_FILE):
            with open(STATE_FILE, 'r') as f:
                return int(f.read().strip())
    except Exception as e:
        logger.warning(f"Could not read state file: {e}")
    return 0


def save_last_position(position):
    """Save the last processed position to state file."""
    try:
        os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
        with open(STATE_FILE, 'w') as f:
            f.write(str(position))
    except Exception as e:
        logger.error(f"Could not save state file: {e}")


def read_alerts_file():
    """Read and parse the Wazuh alerts JSON file."""
    try:
        if not os.path.exists(WAZUH_ALERTS_FILE):
            logger.warning(f"Alerts file not found: {WAZUH_ALERTS_FILE}")
            return []

        with open(WAZUH_ALERTS_FILE, 'r') as f:
            content = f.read().strip()
            if not content:
                return []

            alerts = []
            for line in content.split('\n'):
                if line.strip():
                    try:
                        alerts.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
            return alerts

    except Exception as e:
        logger.error(f"Error reading alerts file: {e}")
        return []


def send_to_n8n(alert):
    """Send alert to n8n webhook."""
    try:
        response = requests.post(
            N8N_WEBHOOK_URL,
            json=alert,
            timeout=HTTP_TIMEOUT,
            headers={'Content-Type': 'application/json'}
        )

        if response.status_code in [200, 201, 202]:
            logger.info(f"Successfully sent alert to n8n: {alert.get('rule', {}).get('description', 'Unknown')}")
            return True
        else:
            logger.error(f"Failed to send alert to n8n. Status: {response.status_code}, Response: {response.text}")
            return False

    except requests.exceptions.Timeout:
        logger.error(f"Timeout sending alert to n8n (timeout: {HTTP_TIMEOUT}s)")
        return False
    except requests.exceptions.RequestException as e:
        logger.error(f"Error sending alert to n8n: {e}")
        return False


def should_forward(alert):
    """Determine if an alert should be forwarded based on level."""
    try:
        level = alert.get('rule', {}).get('level', 0)
        return level >= MIN_ALERT_LEVEL
    except Exception:
        return False


def forward_alerts():
    """Main function to forward new alerts to n8n."""
    logger.info("Starting alert forwarder...")

    last_position = get_last_position()
    logger.info(f"Last processed position: {last_position}")

    alerts = read_alerts_file()

    if not alerts:
        logger.info("No alerts found in alerts.json")
        return

    total_alerts = len(alerts)
    logger.info(f"Found {total_alerts} alerts in file")

    if last_position >= total_alerts:
        logger.info("No new alerts to process")
        return

    new_alerts = alerts[last_position:]
    logger.info(f"Processing {len(new_alerts)} new alerts")

    successful = 0
    failed = 0

    for i, alert in enumerate(new_alerts):
        if should_forward(alert):
            logger.info(f"Forwarding alert {i + 1}/{len(new_alerts)} (level: {alert.get('rule', {}).get('level', 0)})")

            if send_to_n8n(alert):
                successful += 1
            else:
                failed += 1
                logger.warning(f"Failed to forward alert, continuing...")
        else:
            logger.debug(f"Skipping alert below threshold (level: {alert.get('rule', {}).get('level', 0)})")

        # Update position after each alert to avoid losing progress
        current_position = last_position + i + 1
        save_last_position(current_position)

        # Small delay to avoid overwhelming n8n
        time.sleep(0.1)

    logger.info(f"Forwarder complete. Successful: {successful}, Failed: {failed}, Skipped: {len(new_alerts) - successful - failed}")


if __name__ == '__main__':
    try:
        forward_alerts()
    except Exception as e:
        logger.error(f"Unexpected error in forwarder: {e}")
        sys.exit(1)