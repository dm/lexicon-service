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

  lexicon_args="$provider --delegated $zone update $zone $type --name $name --content $content"

  if [ -n "$priority" ]; then
    lexicon_args="$lexicon_args --priority $priority"
  fi

  if lexicon $lexicon_args 2>&1; then
    echo "[sync] OK: $type $name"
  else
    echo "[sync] Update failed, trying create..."
    lexicon_args_create="$provider --delegated $zone create $zone $type --name $name --content $content"
    if [ -n "$priority" ]; then
      lexicon_args_create="$lexicon_args_create --priority $priority"
    fi
    if lexicon $lexicon_args_create 2>&1; then
      echo "[sync] Created: $type $name"
    else
      echo "[sync] FAILED: $type $name"
    fi
  fi
done

echo "[sync] Done"
