#!/bin/bash
set -euo pipefail

CONFIG="/config/records.json"
LAST_IP_FILE="/data/last_ip"
IP_PROVIDERS="${IP_PROVIDERS:-https://checkip.amazonaws.com,https://ifconfig.me,https://icanhazip.com}"

resolve_public_ip() {
  IFS=',' read -ra providers <<< "$IP_PROVIDERS"
  local ips=()

  for provider in "${providers[@]}"; do
    ip=$(curl -s --max-time 5 "$provider" | tr -d '[:space:]')
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      ips+=("$ip")
    fi
  done

  if [ ${#ips[@]} -lt 2 ]; then
    echo "[ddns] ERROR: Could not get IP from at least 2 providers" >&2
    return 1
  fi

  consensus=$(printf '%s\n' "${ips[@]}" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
  count=$(printf '%s\n' "${ips[@]}" | grep -c "^${consensus}$")

  if [ "$count" -lt 2 ]; then
    echo "[ddns] ERROR: No consensus among providers: ${ips[*]}" >&2
    return 1
  fi

  echo "$consensus"
}

resolve_dns_source() {
  local hostname="$1"
  ip=$(dig +short A "$hostname" | head -1 | tr -d '[:space:]')
  if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$ip"
  else
    echo "[ddns] ERROR: Could not resolve $hostname" >&2
    return 1
  fi
}

if [ ! -f "$CONFIG" ]; then
  echo "[ddns] No config found"
  exit 0
fi

declare -A source_ips

for i in $(seq 0 $(($(jq length "$CONFIG") - 1))); do
  record=$(jq -r ".[$i]" "$CONFIG")
  dynamic=$(echo "$record" | jq -r '.dynamic // false')

  if [ "$dynamic" != "true" ]; then
    continue
  fi

  provider=$(echo "$record" | jq -r '.provider')
  source=$(echo "$record" | jq -r '.source // "public"')

  if [ -z "${source_ips[$source]+x}" ]; then
    if [ "$source" = "public" ]; then
      ip=$(resolve_public_ip) || exit 1
    elif [[ "$source" == dns:* ]]; then
      hostname="${source#dns:}"
      ip=$(resolve_dns_source "$hostname") || exit 1
    else
      echo "[ddns] ERROR: Unknown source type: $source"
      exit 1
    fi
    source_ips[$source]="$ip"
  fi

  current_ip="${source_ips[$source]}"
  zone=$(echo "$record" | jq -r '.zone')
  type=$(echo "$record" | jq -r '.type')
  name=$(echo "$record" | jq -r '.name')

  last_ip_key=$(echo "${name}_${source}" | tr '.:' '_')
  last_ip_file="${LAST_IP_FILE}_${last_ip_key}"

  last_ip=""
  if [ -f "$last_ip_file" ]; then
    last_ip=$(cat "$last_ip_file")
  fi

  if [ "$current_ip" = "$last_ip" ]; then
    continue
  fi

  echo "[ddns] IP changed for $name ($source): ${last_ip:-none} -> $current_ip"
  echo "[ddns] Updating $type $name -> $current_ip (zone: $zone, provider: $provider)"

  if lexicon "$provider" --delegated "$zone" update "$zone" "$type" --name "$name" --content "$current_ip" 2>&1; then
    echo "[ddns] Updated: $type $name -> $current_ip"
    echo "$current_ip" > "$last_ip_file"
  else
    echo "[ddns] Update failed, trying create..."
    if lexicon "$provider" --delegated "$zone" create "$zone" "$type" --name "$name" --content "$current_ip" 2>&1; then
      echo "[ddns] Created: $type $name -> $current_ip"
      echo "$current_ip" > "$last_ip_file"
    else
      echo "[ddns] FAILED: $type $name"
    fi
  fi
done
