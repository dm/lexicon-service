#!/bin/bash
set -euo pipefail

DDNS_INTERVAL="${DDNS_INTERVAL:-*/5 * * * *}"

echo "=== lexicon-service starting ==="

if [ ! -f /config/records.json ]; then
  echo "No /config/records.json found, nothing to manage"
else
  echo "Running initial record sync..."
  /usr/local/bin/sync-records.sh

  if jq -e '.[] | select(.dynamic == true)' /config/records.json > /dev/null 2>&1; then
    echo "Dynamic records found, setting up cron: ${DDNS_INTERVAL}"
    echo "${DDNS_INTERVAL} /usr/local/bin/ddns-update.sh >> /proc/1/fd/1 2>&1" > /etc/crontabs/root
    crond -f -l 6 &
    echo "DDNS cron loop started"
  else
    echo "No dynamic records, skipping cron setup"
  fi
fi

echo "=== lexicon-service ready ==="

# Keep container alive
exec tail -f /dev/null
