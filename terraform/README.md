Terraform usage for Auto DevOps Lab

This folder contains a small Terraform configuration that provisions a single EC2 instance (Ubuntu) which will attempt to run the repository's `docker-compose.yml` on boot.

Prerequisites
- AWS credentials configured (environment variables, shared config, or AWS CLI)
- An existing EC2 key pair in the selected region if you want SSH access

Quick example

```bash
cd terraform
terraform init
terraform apply -var='git_repo=https://github.com/Ayush-1-dot/auto-devops-lab.git' -var='key_name=my-ec2-key' -auto-approve
```

Main variables (see `variables.tf` for defaults)
- `aws_region` — AWS region to create resources in (default: us-east-1)
- `instance_type` — EC2 instance type (default: t3.medium)
- `ssh_allow_cidr` — CIDR allowed for SSH (change from default 0.0.0.0/0 for security)
- `git_repo` — optional: repo to clone onto the instance at boot
- `key_name` — optional EC2 key pair name for SSH access
- `enable_ai_assistant` — optional boolean to enable the OpenAI assistant (default: false)
- `openai_api_key` — optional OpenAI API key (avoid committing this; use secure storage in production)

Outputs
- `sandbox_public_ip` — public IP of the provisioned instance
- `urls` — quick service URLs (nginx, sample_app, grafana, prometheus, jenkins)

Notes
- The user-data performs network installs and runs `docker compose` on boot. Check `/var/log/user-data.log` and `/var/log/auto_devops_health.log` on the instance for debugging.
- Consider using AWS SSM Parameter Store or Secrets Manager for storing sensitive API keys and attach an instance profile with least privilege.
