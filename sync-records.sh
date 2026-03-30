#!/bin/bash
set -euo pipefail

CONFIG="/config/records.json"

if [ ! -f "$CONFIG" ]; then
  echo "[sync] No config found at $CONFIG"
  exit 0
fi

record_count=$(jq length "$CONFIG")
echo "[sync] Processing $record_count records..."

for i in $(seq 0 $((record_count - 1))); do
  record=$(jq -r ".[$i]" "$CONFIG")

  provider=$(echo "$record" | jq -r '.provider')
  zone=$(echo "$record" | jq -r '.zone')
  type=$(echo "$record" | jq -r '.type')
  name=$(echo "$record" | jq -r '.name')
  content=$(echo "$record" | jq -r '.content // empty')
  priority=$(echo "$record" | jq -r '.priority // empty')
  dynamic=$(echo "$record" | jq -r '.dynamic // false')

  if [ "$dynamic" = "true" ] && [ -z "$content" ]; then
    echo "[sync] Skipping dynamic record $type $name (managed by ddns-update)"
    continue
  fi

  echo "[sync] Ensuring $type $name -> $content (zone: $zone, provider: $provider)"

  priority_args=""
  if [ -n "$priority" ]; then
    priority_args="--priority $priority"
  fi

  if lexicon "$provider" update "$zone" "$type" --name "$name" --content "$content" $priority_args > /dev/null 2>&1; then
    echo "[sync] Updated $type $name -> $content"
  elif lexicon "$provider" create "$zone" "$type" --name "$name" --content "$content" $priority_args > /dev/null 2>&1; then
    echo "[sync] Created $type $name -> $content"
  else
    echo "[sync] FAILED $type $name -> $content (zone: $zone, provider: $provider)"
  fi
done

echo "[sync] Done"
