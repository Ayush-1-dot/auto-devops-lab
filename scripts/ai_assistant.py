from flask import Flask, request, jsonify
import os
import subprocess
import json
import requests
from datetime import datetime

OPENAI_API_KEY = os.getenv('OPENAI_API_KEY', '')
OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')

app = Flask(__name__)


def get_system_info():
    info = {}
    try:
        info['uptime'] = subprocess.check_output(
            ['uptime', '-p'], text=True).strip()
    except Exception:
        info['uptime'] = 'N/A'
    try:
        info['disk'] = subprocess.check_output(
            ['df', '-h', '/'], text=True).strip()
    except Exception:
        info['disk'] = 'N/A'
    try:
        info['memory'] = subprocess.check_output(
            ['free', '-h'], text=True).strip()
    except Exception:
        info['memory'] = 'N/A'
    try:
        info['docker_ps'] = subprocess.check_output(
            ['docker', 'ps', '--format', '{{.Names}}: {{.Status}}'],
            text=True).strip()
    except Exception:
        info['docker_ps'] = 'N/A'
    try:
        info['docker_images'] = subprocess.check_output(
            ['docker', 'images', '--format', '{{.Repository}}:{{.Tag}}'],
            text=True).strip()
    except Exception:
        info['docker_images'] = 'N/A'
    try:
        info['load'] = subprocess.check_output(
            ['cat', '/proc/loadavg'], text=True).strip()
    except Exception:
        info['load'] = 'N/A'
    return info


def check_service_health(service_name):
    service_urls = {
        'sample_app': 'http://localhost:5000',
        'nginx': 'http://localhost:80',
        'prometheus': 'http://localhost:9090',
        'grafana': 'http://localhost:3000',
    }
    url = service_urls.get(service_name, service_urls.get('sample_app'))
    try:
        resp = requests.get(url, timeout=5)
        status = 'healthy' if resp.status_code == 200 else 'degraded'
        return {'status': status, 'code': resp.status_code}
    except Exception as e:
        return {'status': 'unhealthy', 'error': str(e)}


def get_recent_logs(service_name, lines=50):
    try:
        logs = subprocess.check_output(
            ['docker', 'logs', '--tail', str(lines), service_name],
            text=True, stderr=subprocess.STDOUT)
        return logs[-4000:]
    except Exception as e:
        return f'Could not fetch logs: {e}'


def get_health_check_logs():
    log_file = '/var/log/auto_devops_health.log'
    if os.path.exists(log_file):
        try:
            with open(log_file, 'r') as f:
                return f.read()[-4000:]
        except Exception:
            pass
    return 'No health check log file found.'


def get_backup_status():
    backup_dir = '/var/backups/auto-devops'
    if os.path.exists(backup_dir):
        try:
            files = os.listdir(backup_dir)
            return {'exists': True, 'files': files, 'count': len(files)}
        except Exception as e:
            return {'exists': True, 'error': str(e)}
    return {'exists': False}


def call_openai(messages):
    if not OPENAI_API_KEY:
        return 'AI is not configured. Set OPENAI_API_KEY environment variable.'
    headers = {
        'Authorization': f'Bearer {OPENAI_API_KEY}',
        'Content-Type': 'application/json'
    }
    data = {
        'model': OPENAI_MODEL,
        'messages': messages,
        'max_tokens': 1500,
        'temperature': 0.3
    }
    try:
        url = 'https://api.openai.com/v1/chat/completions'
        resp = requests.post(url, headers=headers, json=data, timeout=60)
        resp.raise_for_status()
        return resp.json()['choices'][0]['message']['content']
    except requests.exceptions.HTTPError as e:
        return f'OpenAI API error: {e.response.status_code}'
    except Exception as e:
        return f'Error calling AI: {str(e)}'


def build_system_context():
    sys_info = get_system_info()
    health = {}
    services = ['sample_app', 'nginx', 'prometheus', 'grafana']
    for svc in services:
        health[svc] = check_service_health(svc)
    context_lines = [
        'You are an AI assistant for the Auto DevOps Lab.',
        'Current environment state:',
        '',
        f"Uptime: {sys_info['uptime']}",
        f"Load Average: {sys_info['load']}",
        f"Disk: {sys_info['disk']}",
        f"Memory: {sys_info['memory']}",
        '',
        'DOCKER CONTAINERS:',
        sys_info['docker_ps'],
        '',
        'DOCKER IMAGES:',
        sys_info['docker_images'],
        '',
        'SERVICE HEALTH:',
        json.dumps(health, indent=2),
        '',
        'HEALTH CHECK LOG:',
        get_health_check_logs(),
        '',
        'BACKUPS:',
        json.dumps(get_backup_status(), indent=2),
        '',
        'Respond in plain English, be concise but thorough.',
        'Suggest actionable next steps.'
    ]
    return '\n'.join(context_lines)


@app.route('/ai/explain', methods=['GET', 'POST'])
def explain():
    context = build_system_context()
    user_question = ''
    if request.method == 'POST':
        data = request.get_json() or {}
        user_question = data.get('question', '')
    prompt = 'Explain the current state of this Auto DevOps Lab '
    prompt += 'environment. ' + user_question
    messages = [
        {'role': 'system', 'content': context},
        {'role': 'user', 'content': prompt.strip()}
    ]
    response = call_openai(messages)
    return jsonify({'response': response, 'context': 'system_state'})


@app.route('/ai/troubleshoot', methods=['POST'])
def troubleshoot():
    data = request.get_json() or {}
    issue = data.get('issue', '')
    service = data.get('service', '')
    if not issue:
        return jsonify({'error': 'Please provide an issue description'}), 400
    context = build_system_context()
    logs = get_recent_logs(service) if service else ''
    prompt = context + '\n\nRecent logs: ' + logs[:2000]
    prompt += '\n\nYou are a DevOps troubleshooting expert. '
    prompt += 'Analyze the issue and provide a diagnosis and fix.'
    messages = [
        {'role': 'system', 'content': prompt},
        {'role': 'user', 'content': f"Issue: {issue}"}
    ]
    response = call_openai(messages)
    return jsonify({'response': response, 'context': 'troubleshooting'})


@app.route('/ai/analyze-logs', methods=['POST'])
def analyze_logs():
    data = request.get_json() or {}
    service = data.get('service', 'sample_app')
    lines = data.get('lines', 100)
    logs = get_recent_logs(service, lines)
    context = build_system_context()
    prompt = context + '\n\nYou are a log analysis expert. '
    prompt += 'Find errors, warnings, and anomalies in the following '
    prompt += 'logs and explain what they mean.'
    messages = [
        {'role': 'system', 'content': prompt},
        {'role': 'user', 'content': f"Logs from '{service}':\n{logs}"}
    ]
    response = call_openai(messages)
    return jsonify({'response': response, 'service': service, 'lines': lines})


@app.route('/ai/status', methods=['GET'])
def ai_status():
    return jsonify({
        'ai_enabled': bool(OPENAI_API_KEY),
        'model': OPENAI_MODEL if OPENAI_API_KEY else 'not configured',
        'timestamp': datetime.utcnow().isoformat(),
        'system': get_system_info()
    })


@app.route('/ai/chat', methods=['POST'])
def chat():
    data = request.get_json() or {}
    message = data.get('message', '')
    if not message:
        return jsonify({'error': 'Please provide a message'}), 400
    context = build_system_context()
    messages = [
        {'role': 'system', 'content': context},
        {'role': 'user', 'content': message}
    ]
    response = call_openai(messages)
    return jsonify({'response': response})


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5050, debug=False)
