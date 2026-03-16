#!/bin/bash
#cloud-config
set -eux

GIT_REPO="${git_repo}"
ENABLE_AI="${enable_ai}"
OPENAI_KEY="${openai_key}"

exec > /var/log/user-data.log 2>&1

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git python3 python3-pip python3-venv

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
systemctl start docker

# Clone repo if provided
if [ -n "$GIT_REPO" ]; then
  cd /home/ubuntu
  git clone "$GIT_REPO" auto-devops-lab || true
  cd auto-devops-lab
fi

# Start Docker Compose services
if [ -f "docker-compose.yml" ]; then
  docker compose up -d --build
fi

# Health check script
cat > /usr/local/bin/auto_devops_health.sh <<'HEALTH'
#!/bin/bash
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
check_url() {
  curl -sf --connect-timeout 5 "$1" > /dev/null && echo "OK" || echo "FAILED"
}
APP_STATUS=$(check_url http://localhost:5000)
NGINX_STATUS=$(check_url http://localhost:80)
PROM_STATUS=$(check_url http://localhost:9090)
GRAFANA_STATUS=$(check_url http://localhost:3000)
echo "[$TIMESTAMP] sample_app: $APP_STATUS | nginx: $NGINX_STATUS | prometheus: $PROM_STATUS | grafana: $GRAFANA_STATUS"
HEALTH
chmod +x /usr/local/bin/auto_devops_health.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/auto_devops_health.sh >> /var/log/auto_devops_health.log 2>&1") | crontab -

# Daily backup script
mkdir -p /var/backups/auto-devops
cat > /usr/local/bin/auto_devops_backup.sh <<'BACKUP'
#!/bin/bash
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_DIR="/var/backups/auto-devops"
SOURCE_DIR="/home/ubuntu/auto-devops-lab"
if [ -d "$SOURCE_DIR" ]; then
  tar -czf "$BACKUP_DIR/auto-devops-$TIMESTAMP.tar.gz" -C "$SOURCE_DIR" .
  find "$BACKUP_DIR" -name 'auto-devops-*.tar.gz' -mtime +7 -delete
fi
BACKUP
chmod +x /usr/local/bin/auto_devops_backup.sh
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/auto_devops_backup.sh") | crontab -

# Enhanced AI Assistant
if [ "$ENABLE_AI" = "true" ] && [ -n "$OPENAI_KEY" ]; then
  pip install --break-system-packages flask requests openai || pip install flask requests openai
  cat > /usr/local/bin/auto_devops_ai.py <<'AI'
from flask import Flask, request, jsonify
import os, subprocess, json, requests
from datetime import datetime

app = Flask(__name__)
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY', '')
OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')

def get_system_info():
    info = {}
    try: info['uptime'] = subprocess.check_output(['uptime', '-p'], text=True).strip()
    except: info['uptime'] = 'N/A'
    try: info['disk'] = subprocess.check_output(['df', '-h', '/'], text=True).strip()
    except: info['disk'] = 'N/A'
    try: info['memory'] = subprocess.check_output(['free', '-h'], text=True).strip()
    except: info['memory'] = 'N/A'
    try: info['docker_ps'] = subprocess.check_output(['docker', 'ps', '--format', '{{.Names}}: {{.Status}}'], text=True).strip()
    except: info['docker_ps'] = 'N/A'
    try: info['load'] = subprocess.check_output(['cat', '/proc/loadavg'], text=True).strip()
    except: info['load'] = 'N/A'
    return info

def check_health(svc):
    urls = {'sample_app': 'http://localhost:5000', 'nginx': 'http://localhost:80', 'prometheus': 'http://localhost:9090', 'grafana': 'http://localhost:3000'}
    try: r = requests.get(urls.get(svc, 'http://localhost:80'), timeout=5); return {'status': 'healthy' if r.status_code==200 else 'degraded', 'code': r.status_code}
    except Exception as e: return {'status': 'unhealthy', 'error': str(e)}

def get_logs(svc, lines=50):
    try: return subprocess.check_output(['docker', 'logs', '--tail', str(lines), svc], text=True, stderr=subprocess.STDOUT)[-4000:]
    except: return 'N/A'

def get_health_logs():
    try:
        with open('/var/log/auto_devops_health.log') as f: return f.read()[-4000:]
    except: return 'N/A'

def build_context():
    s = get_system_info(); h = {k: check_health(k) for k in ['sample_app','nginx','prometheus','grafana']}
    return f"""You are an AI assistant for the Auto DevOps Lab. Current state:
Uptime: {s['uptime']} | Load: {s['load']}
Disk: {s['disk']}
Memory: {s['memory']}
Containers: {s['docker_ps']}
Health: {json.dumps(h, indent=2)}
Health logs: {get_health_logs()}
"""

@app.route('/ai/explain', methods=['GET','POST'])
def explain():
    if not OPENAI_API_KEY: return jsonify({'response': 'AI not configured.'}), 400
    q = request.get_json().get('question', '') if request.method=='POST' else ''
    msgs = [{'role':'system','content':build_context()},{'role':'user','content':f"Explain the environment. {q}"}]
    resp = requests.post('https://api.openai.com/v1/chat/completions', headers={'Authorization':f'Bearer {OPENAI_API_KEY}','Content-Type':'application/json'}, json={'model':OPENAI_MODEL,'messages':msgs,'max_tokens':1500}, timeout=60)
    return jsonify({'response': resp.json()['choices'][0]['message']['content']})

@app.route('/ai/troubleshoot', methods=['POST'])
def troubleshoot():
    if not OPENAI_API_KEY: return jsonify({'response': 'AI not configured.'}), 400
    data = request.get_json() or {}
    issue, svc = data.get('issue',''), data.get('service','')
    if not issue: return jsonify({'error': 'Provide an issue.'}), 400
    logs = get_logs(svc) if svc else ''
    msgs = [{'role':'system','content':f"{build_context()}\nLogs: {logs[:2000]}\nYou are a DevOps expert. Diagnose and fix."},{'role':'user','content':f"Issue: {issue}"}]
    resp = requests.post('https://api.openai.com/v1/chat/completions', headers={'Authorization':f'Bearer {OPENAI_API_KEY}','Content-Type':'application/json'}, json={'model':OPENAI_MODEL,'messages':msgs,'max_tokens':1500}, timeout=60)
    return jsonify({'response': resp.json()['choices'][0]['message']['content']})

@app.route('/ai/analyze-logs', methods=['POST'])
def analyze_logs():
    if not OPENAI_API_KEY: return jsonify({'response': 'AI not configured.'}), 400
    data = request.get_json() or {}
    svc, lines = data.get('service','sample_app'), data.get('lines',100)
    logs = get_logs(svc, lines)
    msgs = [{'role':'system','content':f"{build_context()}\nYou are a log analysis expert."},{'role':'user','content':f"Logs from '{svc}':\n{logs}"}]
    resp = requests.post('https://api.openai.com/v1/chat/completions', headers={'Authorization':f'Bearer {OPENAI_API_KEY}','Content-Type':'application/json'}, json={'model':OPENAI_MODEL,'messages':msgs,'max_tokens':1500}, timeout=60)
    return jsonify({'response': resp.json()['choices'][0]['message']['content']})

@app.route('/ai/chat', methods=['POST'])
def chat():
    if not OPENAI_API_KEY: return jsonify({'response': 'AI not configured.'}), 400
    data = request.get_json() or {}
    if not data.get('message'): return jsonify({'error': 'Provide a message.'}), 400
    msgs = [{'role':'system','content':build_context()+'You are a helpful DevOps assistant.'},{'role':'user','content':data['message']}]
    resp = requests.post('https://api.openai.com/v1/chat/completions', headers={'Authorization':f'Bearer {OPENAI_API_KEY}','Content-Type':'application/json'}, json={'model':OPENAI_MODEL,'messages':msgs,'max_tokens':1500}, timeout=60)
    return jsonify({'response': resp.json()['choices'][0]['message']['content']})

@app.route('/ai/status', methods=['GET'])
def ai_status():
    return jsonify({'ai_enabled': bool(OPENAI_API_KEY), 'model': OPENAI_MODEL, 'system': get_system_info()})

@app.route('/health', methods=['GET'])
def health(): return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5050, debug=False)
AI
  chmod +x /usr/local/bin/auto_devops_ai.py
  echo "OPENAI_API_KEY=$OPENAI_KEY" > /etc/profile.d/auto_devops_ai.sh
  echo "OPENAI_MODEL=gpt-4o-mini" >> /etc/profile.d/auto_devops_ai.sh
  chmod 600 /etc/profile.d/auto_devops_ai.sh
  # Run AI assistant as a service
  python3 /usr/local/bin/auto_devops_ai.py &
fi
