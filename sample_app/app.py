from flask import Flask, request, jsonify
import os
import subprocess
import json
import requests
from datetime import datetime
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)
metrics = PrometheusMetrics(app)

# AI Configuration
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY', '')
OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')

@app.route('/')
def home():
    return 'Hello, World! The sample app is working.'

@app.route('/ai/status', methods=['GET'])
def ai_status():
    """Check if AI assistant is configured."""
    return jsonify({
        'ai_enabled': bool(OPENAI_API_KEY),
        'model': OPENAI_MODEL if OPENAI_API_KEY else 'not configured',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/ai/explain', methods=['GET', 'POST'])
def explain():
    """Explain the current environment state using AI."""
    if not OPENAI_API_KEY:
        return jsonify({'response': 'AI is not configured. Set OPENAI_API_KEY environment variable.'}), 400
    sys_info = {}
    try:
        sys_info['uptime'] = subprocess.check_output(['uptime', '-p'], text=True).strip()
    except Exception:
        sys_info['uptime'] = 'N/A'
    try:
        sys_info['disk'] = subprocess.check_output(['df', '-h', '/'], text=True).strip()
    except Exception:
        sys_info['disk'] = 'N/A'
    try:
        sys_info['docker_ps'] = subprocess.check_output(['docker', 'ps', '--format', '{{.Names}}: {{.Status}}'], text=True).strip()
    except Exception:
        sys_info['docker_ps'] = 'N/A'
    context = f"""You are an AI assistant for the Auto DevOps Lab. Current state:
Uptime: {sys_info['uptime']}
Disk: {sys_info['disk']}
Containers: {sys_info['docker_ps']}"""
    user_question = ''
    if request.method == 'POST':
        data = request.get_json() or {}
        user_question = data.get('question', '')
    headers = {'Authorization': f'Bearer {OPENAI_API_KEY}', 'Content-Type': 'application/json'}
    data = {'model': OPENAI_MODEL, 'messages': [
        {'role': 'system', 'content': context},
        {'role': 'user', 'content': f"Explain the current state. {user_question}".strip()}
    ], 'max_tokens': 1500}
    try:
        resp = requests.post('https://api.openai.com/v1/chat/completions', headers=headers, json=data, timeout=60)
        resp.raise_for_status()
        return jsonify({'response': resp.json()['choices'][0]['message']['content']})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/ai/chat', methods=['POST'])
def chat():
    """Chat with AI assistant."""
    if not OPENAI_API_KEY:
        return jsonify({'response': 'AI is not configured. Set OPENAI_API_KEY.'}), 400
    data = request.get_json() or {}
    message = data.get('message', '')
    if not message:
        return jsonify({'error': 'Please provide a message'}), 400
    headers = {'Authorization': f'Bearer {OPENAI_API_KEY}', 'Content-Type': 'application/json'}
    payload = {'model': OPENAI_MODEL, 'messages': [
        {'role': 'system', 'content': 'You are a helpful DevOps assistant for Auto DevOps Lab. Be concise.'},
        {'role': 'user', 'content': message}
    ], 'max_tokens': 1500}
    try:
        resp = requests.post('https://api.openai.com/v1/chat/completions', headers=headers, json=payload, timeout=60)
        resp.raise_for_status()
        return jsonify({'response': resp.json()['choices'][0]['message']['content']})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
