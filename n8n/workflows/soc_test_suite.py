import requests
import json
import time

# Configuration
WEBHOOK_POLLER = "http://localhost:5678/webhook/wazuh-alert"
WEBHOOK_RESPONDER = "http://localhost:5678/webhook/agent2-responder"
ZAMMAD_API = "http://localhost:8080/api/v1/tickets"
ZAMMAD_TOKEN = "YOUR_ZAMMAD_TOKEN"

HEADERS_ZAMMAD = {
    "Authorization": f"Token token={ZAMMAD_TOKEN}",
    "Content-Type": "application/json"
}

def trigger_alert(scenario_data):
    print(f"[*] Triggering alert: {scenario_data['rule']['description']}")
    try:
        resp = requests.post(WEBHOOK_POLLER, json=scenario_data, timeout=10)
        if resp.status_code == 200:
            return resp.json()
    except Exception as e:
        print(f"[!] Error triggering webhook: {e}")
    return None

def trigger_responder(ticket_id, alert_data):
    print(f"[*] Triggering Agent 2 for Ticket ID: {ticket_id}")
    payload = {
        "ticket_id": ticket_id,
        "alertData": {
            "rule_description": alert_data['rule']['description'],
            "severity": alert_data['rule']['level'],
            "hostname": alert_data['agent']['name'],
            "source_ip": alert_data['data']['srcip'],
            "full_log": alert_data['data']['full_log'],
            "priority": 3 if int(alert_data['rule']['level']) >= 12 else 2
        }
    }
    try:
        resp = requests.post(WEBHOOK_RESPONDER, json=payload, timeout=10)
        return resp.json()
    except Exception as e:
        print(f"[!] Responder trigger failed: {e}")
    return None

def check_ticket(ticket_id):
    resp = requests.get(f"{ZAMMAD_API}/{ticket_id}", headers=HEADERS_ZAMMAD)
    return resp.json()

def run_test():
    print("--- SOC PIPELINE TEST SUITE ---")
    
    # SCENARIO 1: Critical Log4j (Auto-Resolve)
    print("\n[Scenario 1] Critical Log4j (Auto-Resolve)")
    alert1 = {
        "timestamp": "2026-04-05T13:00:00Z",
        "rule": {"level": 15, "description": "CVE-2021-44228 Log4j Remote Code Execution", "id": "114422"},
        "agent": {"id": "001", "name": "prod-web-01"},
        "data": {"srcip": "185.156.177.12", "full_log": "DEBUG: jndi:ldap://collaboration-srv.net/a. Log4j detected."}
    }
    t1 = trigger_alert(alert1)
    if t1 and "id" in t1:
        tid = t1["id"]
        print(f"  [+] Ticket {tid} created. Waiting for Agent 2...")
        time.sleep(3)
        trigger_responder(tid, alert1)
        time.sleep(7)
        res = check_ticket(tid)
        status = "PASSED" if res["state_id"] == 4 else "FAILED"
        print(f"  [#] Result: {status} (State: {res['state_id']}, CVEs: {res.get('soc_cve_list')})")
        print(f"  [#] Audit: CreatedBy={res['created_by_id']}, UpdatedBy={res['updated_by_id']}")

    # SCENARIO 2: Suspicious Sudo Usage (Escalation)
    print("\n[Scenario 2] Unusual Sudo Usage (Escalation)")
    alert2 = {
        "timestamp": "2026-04-05T13:05:00Z",
        "rule": {"level": 10, "description": "Successful sudo usage by non-standard user", "id": "111000"},
        "agent": {"id": "044", "name": "jump-box-01"},
        "data": {"srcip": "10.0.5.5", "full_log": "Apr  5 13:05:01 jump-box-01 sudo:  test-user : TTY=pts/0 ; PWD=/home/test-user ; USER=root ; COMMAND=/usr/bin/apt-get update"}
    }
    t2 = trigger_alert(alert2)
    if t2 and "id" in t2:
        tid = t2["id"]
        print(f"  [+] Ticket {tid} created. Waiting for Agent 2...")
        time.sleep(3)
        trigger_responder(tid, alert2)
        time.sleep(7)
        res = check_ticket(tid)
        status = "PASSED" if res["state_id"] == 2 and res["group_id"] == 2 else "FAILED"
        print(f"  [#] Result: {status} (State: {res['state_id']}, Group: {res['group_id']}, Owner: {res['owner_id']})")

    # SCENARIO 3: Authentication Failure (Priority Elevation & Host Tagging)
    print("\n[Scenario 3] SSH Authentication Failure (Host: vulnerable)")
    alert3 = {
        "timestamp": "2026-04-05T13:10:00Z",
        "rule": {"level": 5, "description": "sshd: authentication failure", "id": "5716"},
        "agent": {"id": "004", "name": "vulnerable"},
        "data": {"srcip": "192.168.1.50", "full_log": "Apr  5 13:10:01 vulnerable sshd[1234]: pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=192.168.1.50  user=root"}
    }
    t3 = trigger_alert(alert3)
    if t3 and "id" in t3:
        tid = t3["id"]
        # Expectation: P2 priority despite Level 5, and [vulnerable] in title
        res = check_ticket(tid)
        title_ok = "[vulnerable]" in res["title"]
        priority_ok = res["priority_id"] == 2
        status = "PASSED" if title_ok and priority_ok else "FAILED"
        print(f"  [#] Result: {status} (Title: {res['title']}, Priority: {res['priority_id']})")
        print(f"  [#] Detail: HostID={res.get('article', {}).get('body', '')[0:50]}...") # truncated check for ID 004 in body

if __name__ == "__main__":
    run_test()
