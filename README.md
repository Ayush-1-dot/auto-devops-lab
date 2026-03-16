# Auto DevOps Lab

One-click, self-contained DevOps playground: sample Flask app, Nginx, Prometheus and Grafana — runnable locally with Docker Compose or provisioned into a single EC2 sandbox via Terraform.

This repository demonstrates an end-to-end DevOps stack you can use for demos, learning, and experimentation.

---

## 📦 Features

- Flask sample application instrumented for Prometheus
- Nginx reverse proxy
- Prometheus + Grafana observability stack
- Local development via Docker Compose
- Optional Terraform flow that provisions an EC2 sandbox which auto-starts the Compose stack
- Health checks and daily backup rotation configured on the sandbox
- Optional AI assistant (uses OpenAI API) to explain the environment

---

## 🚀 Quick Start (Local)

Prerequisites: Docker & Docker Compose installed.

1. Clone the repository:

```bash
git clone https://github.com/Ayush-1-dot/auto-devops-lab.git
cd auto-devops-lab
```

2. Build and start services locally:

```bash
docker compose up -d --build
```

3. Open the services in your browser:

- App via Nginx: http://localhost
- Flask app (direct): http://localhost:5000
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000

To stop and remove containers:

```bash
docker compose down
```

---

## ☁️ Terraform sandbox (one-click cloud)

The Terraform configuration provisions a single EC2 instance (Ubuntu) and runs a user-data script that installs Docker, clones this repository (if you provide `git_repo`), and attempts to run `docker compose up -d` on boot.

Before running, ensure your AWS credentials are available (environment, AWS CLI configured, or other provider method).

Example workflow (from `terraform/`):

```bash
cd terraform
terraform init
terraform apply -var='git_repo=https://github.com/Ayush-1-dot/auto-devops-lab.git' -var='key_name=my-ec2-key' -auto-approve
```

Important Terraform variables (see `terraform/variables.tf`):

- `aws_region` (default: us-east-1)
- `instance_type` (default: t3.medium)
- `ssh_allow_cidr` (default: 0.0.0.0/0) — change to a restrictive CIDR for security
- `git_repo` — optional repo to clone on the instance (if empty, you must place files on the instance)
- `key_name` — optional existing EC2 key pair name for SSH access
- `enable_ai_assistant` — set to `true` to enable the optional AI helper (requires `openai_api_key`)
- `openai_api_key` — OpenAI API key (avoid committing secrets; consider SSM/Secrets Manager)

Outputs after apply include the sandbox public IP and a set of service URLs (nginx, sample app, grafana, prometheus, jenkins).

Notes about the EC2 user-data behavior:

- Installs Docker and the docker-compose plugin.
- If `git_repo` is provided, it clones the repo to `/home/ubuntu/auto-devops-lab` and runs `docker compose up -d`.
- Adds a simple Python health-check that runs every 5 minutes and logs to `/var/log/auto_devops_health.log`.
- Adds a daily backup script that tars the repo directory to `/var/backups/auto-devops/` and retains 7 days.
- If `enable_ai_assistant=true` and `openai_api_key` is provided, a small script `/usr/local/bin/auto_devops_ai.py` is placed on the instance to call the OpenAI API (the user-data currently writes the key into `/etc/profile.d/` — for production prefer AWS Secrets Manager or SSM Parameter Store with an instance role).

---

## 🔎 Observability and Troubleshooting

- Health-check logs on the EC2 sandbox: `/var/log/auto_devops_health.log`
- Backups: `/var/backups/auto-devops/` (rotated daily, 7-day retention)
- If services do not appear, SSH into the instance and inspect the user-data log: `/var/log/user-data.log` and Docker container logs:

```bash
sudo journalctl -u docker --no-pager
docker ps -a
docker logs <container>
```

If your `docker compose up` did not run automatically, check that `docker compose` is available and run it manually from the repo directory.

---

## 🧩 Project structure

- `sample_app/` — Flask application and Dockerfile
- `nginx/nginx.conf` — Reverse proxy configuration
- `prometheus/` — Prometheus config
- `grafana/` — Grafana provisioning
- `docker-compose.yml` — Local orchestration
- `terraform/` — Terraform configuration for the EC2 sandbox

---

## 🛡 Security notes

- The Terraform config uses a permissive SSH CIDR by default (`0.0.0.0/0`) for demo convenience. Restrict it before using in a public environment.
- Do not store API keys or secrets in plaintext in variables. Prefer secure stores (SSM/Secrets Manager) and instance IAM roles.

---

## 🙌 Contributing

Contributions welcome. Suggested follow-ups:

- Add k3s/minikube provisioning as an alternative to Docker Compose
- Store OpenAI keys securely via SSM and attach an IAM role to the instance
- Add a smoke-test that runs after `terraform apply` to verify endpoints

## AI Assistant

The AI Assistant is an OpenAI-powered chatbot that runs on port `5050`. It provides real-time troubleshooting, log analysis, and environment explanation.

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/ai/explain` | GET, POST | Get an AI explanation of the current environment state |
| `/ai/troubleshoot` | POST | Ask the AI to diagnose and fix an issue |
| `/ai/analyze-logs` | POST | Have the AI analyze container logs for errors |
| `/ai/chat` | POST | General chat with the AI assistant |
| `/ai/status` | GET | Check if the AI is configured and healthy |

### Example Usage

```bash
# Check AI status
curl http://localhost:5050/ai/status

# Get an environment explanation
curl -X POST -H "Content-Type: application/json" \
  -d '{"question": "What services are running?"}' \
  http://localhost:5050/ai/explain

# Troubleshoot an issue
curl -X POST -H "Content-Type: application/json" \
  -d '{"issue": "Grafana dashboard shows no data", "service": "grafana"}' \
  http://localhost:5050/ai/troubleshoot

# Analyze container logs
curl -X POST -H "Content-Type: application/json" \
  -d '{"service": "nginx", "lines": 100}' \
  http://localhost:5050/ai/analyze-logs
```

### Enabling on EC2 Sandbox

When provisioning with Terraform, set `enable_ai = true` and provide `openai_key`. The assistant will auto-start on the instance.

---

## Connect

- 🌐 [LinkedIn (Ayush Agnihotri)](https://www.linkedin.com/in/ayush-agnihotri-206a501b1/)
- 💻 [GitHub Repo: auto-devops-lab](https://github.com/Ayush-1-dot/auto-devops-lab)

## 📋 License

MIT (or specify your preferred license)
