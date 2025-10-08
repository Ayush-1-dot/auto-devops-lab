# Auto DevOps Lab

A complete lab to demonstrate an automated DevOps stack with Flask, Nginx, Prometheus, and Grafana, all managed via Docker Compose.

---

## 📦 Features

- **Flask sample application** with Prometheus metrics exporter
- **Nginx** as reverse proxy for HTTP routing to your app
- **Prometheus** for monitoring Flask service metrics
- **Grafana** for customizable dashboards
- Production-ready example configs for local development

---

## 🚀 Quick Start

### 1. Clone the Repository

git clone https://github.com/Ayush-1-dot/auto-devops-lab.git
cd auto-devops-lab

### 2. Build and Start All Services


### 3. Access Services

- **App via Nginx:** [http://localhost](http://localhost)
- **Flask app (direct):** [http://localhost:5000](http://localhost:5000)
- **Prometheus:** [http://localhost:9090](http://localhost:9090)
- **Grafana:** [http://localhost:3000](http://localhost:3000)

---

## 🗂️ Structure

- `sample_app/` — Flask application and Dockerfile
- `nginx/nginx.conf` — Reverse proxy configuration
- `prometheus/prometheus.yml` — Monitoring config
- `grafana/` — Dashboard provisioning
- `docker-compose.yml` — Orchestration file

---

## 🔎 Observability

- The sample app exposes default and custom metrics through `/metrics` (via Prometheus Flask Exporter).
- Prometheus scrapes the Flask app; Grafana can visualize metrics after you add Prometheus as a Data Source (`http://prometheus:9090`).

---

## 🧹 Tear Down


---

## 🙌 Contributing

Feel free to fork and open pull requests for improvements!

---
## Connect

- 🌐 [LinkedIn (Ayush Agnihotri)](https://www.linkedin.com/in/ayush-agnihotri-206a501b1/)
- 💻 [GitHub Repo: auto-devops-lab](https://github.com/Ayush-1-dot/auto-devops-lab)

## 📋 License

MIT (or specify your preferred license)
