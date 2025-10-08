#!/bin/bash
#cloud-config
set -eux

GIT_REPO="${git_repo}"
ENABLE_AI=${enable_ai}
OPENAI_KEY="${openai_key}"

exec > /var/log/user-data.log 2>&1

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git python3 python3-venv

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker ubuntu || true

# Install docker-compose plugin
apt-get install -y docker-compose-plugin

# Clone repository (if not provided, assume code baked in AMI)
if [ -n "$GIT_REPO" ]; then
  su - ubuntu -c "git clone --depth 1 $GIT_REPO /home/ubuntu/auto-devops-lab || (cd /home/ubuntu/auto-devops-lab && git pull)"
  TARGET_DIR="/home/ubuntu/auto-devops-lab"
else
  TARGET_DIR="/root/auto-devops-lab"
  mkdir -p "$TARGET_DIR"
  echo "No git repo provided; please place project files under $TARGET_DIR" > /root/auto-devops-note.txt
fi

# Start docker-compose stack if present
if [ -f "$TARGET_DIR/docker-compose.yml" ]; then
  su - ubuntu -c "cd $TARGET_DIR && docker compose up -d --remove-orphans"
fi

# Create a simple health-check script
cat > /usr/local/bin/auto_devops_health.py << 'PY'
#!/usr/bin/env python3
import requests
services = {
    'nginx': 'http://127.0.0.1/',
    'sample_app': 'http://127.0.0.1:5000/',
    'grafana': 'http://127.0.0.1:3000/',
    'prometheus': 'http://127.0.0.1:9090/',
    'jenkins': 'http://127.0.0.1:8080/'
}
out = []
for name, url in services.items():
    try:
        r = requests.get(url, timeout=3)
        out.append(f"{name}: {r.status_code}")
    except Exception as e:
        out.append(f"{name}: ERROR - {e}")
print('\n'.join(out))
PY
chmod +x /usr/local/bin/auto_devops_health.py

# Cron job to run health check every 5 minutes and save to file
cat > /etc/cron.d/auto_devops_health <<'CRON'
*/5 * * * * root /usr/bin/python3 /usr/local/bin/auto_devops_health.py >> /var/log/auto_devops_health.log 2>&1
CRON
chmod 644 /etc/cron.d/auto_devops_health

# Simple backup: archive docker-compose and configs daily
cat > /usr/local/bin/auto_devops_backup.sh << 'BK'
#!/bin/bash
BACKUP_DIR=/var/backups/auto-devops
mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_DIR/auto-devops-$(date +%F).tgz" -C "${TARGET_DIR}" . || true
find "$BACKUP_DIR" -type f -mtime +7 -delete
BK
chmod +x /usr/local/bin/auto_devops_backup.sh

cat > /etc/cron.d/auto_devops_backup <<'CRON2'
0 3 * * * root /usr/local/bin/auto_devops_backup.sh
CRON2
chmod 644 /etc/cron.d/auto_devops_backup

# Install python deps for optional AI assistant and health-checker
python3 -m venv /opt/auto-devops-venv
source /opt/auto-devops-venv/bin/activate
pip install --upgrade pip requests

if [ "$ENABLE_AI" = "true" ] && [ -n "$OPENAI_KEY" ]; then
  pip install openai
  cat > /usr/local/bin/auto_devops_ai.py <<'AI'
#!/usr/bin/env python3
import os
import openai
openai.api_key = os.getenv('OPENAI_API_KEY')
def explain():
    prompt = "Explain the Auto DevOps Lab sandbox resources in plain English."
    resp = openai.ChatCompletion.create(model='gpt-4o-mini', messages=[{'role':'user','content':prompt}], max_tokens=300)
    print(resp['choices'][0]['message']['content'])

if __name__ == '__main__':
    explain()
AI
  chmod +x /usr/local/bin/auto_devops_ai.py
  # store key in env for that script
  echo "OPENAI_API_KEY=${OPENAI_KEY}" > /etc/profile.d/auto_devops_ai.sh
  chmod 600 /etc/profile.d/auto_devops_ai.sh
fi

deactivate || true

echo "User-data done" >> /var/log/user-data.log