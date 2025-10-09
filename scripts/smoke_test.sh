#!/usr/bin/env bash
# Simple smoke test for Auto DevOps Lab
set -euo pipefail

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: $0 [remote_host]"
  echo "If remote_host is provided, the script will check the remote endpoints (nginx, sample app, grafana, prometheus)."
  exit 0
fi

REMOTE_HOST=${1:-}

echo "Running local docker-compose config check..."
docker compose -f docker-compose.yml config >/dev/null
echo "docker-compose file OK"

if [ -n "$REMOTE_HOST" ]; then
  echo "Checking remote endpoints on $REMOTE_HOST"
  for url in "http://$REMOTE_HOST/" "http://$REMOTE_HOST:5000/" "http://$REMOTE_HOST:3000/" "http://$REMOTE_HOST:9090/"; do
    echo -n "GET $url -> "
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" || echo "000")
    echo "$status"
  done
else
  echo "No remote host provided; local endpoints should be available at localhost when containers are running."
fi

echo "Smoke test completed"
