#!/usr/bin/env bash
#
# system_health.sh - append CPU, memory and disk usage to health_log.txt
#
# Usage:  ./system_health.sh
# Env:    LOG_FILE        (default: health_log.txt)
#         DISK_THRESHOLD  (default: 80)

set -euo pipefail

LOG_FILE="${LOG_FILE:-health_log.txt}"
DISK_THRESHOLD="${DISK_THRESHOLD:-80}"

cpu_usage() {
  local -a a b
  local i total_a=0 total_b=0 idle_a=0 idle_b=0 dt di

  read -r -a a < /proc/stat
  sleep 1
  read -r -a b < /proc/stat

  for i in 1 2 3 4 5 6 7 8; do
    total_a=$(( total_a + a[i] ))
    total_b=$(( total_b + b[i] ))
  done
  idle_a=$(( a[4] + a[5] ))
  idle_b=$(( b[4] + b[5] ))

  dt=$(( total_b - total_a ))
  di=$(( idle_b - idle_a ))

  if (( dt > 0 )); then
    awk -v dt="$dt" -v di="$di" 'BEGIN { printf "%.1f", (dt - di) * 100 / dt }'
  else
    printf '0.0'
  fi
}

mem_usage() {
  local total avail
  total=$(awk '/^MemTotal:/     { print $2; exit }' /proc/meminfo)
  avail=$(awk '/^MemAvailable:/ { print $2; exit }' /proc/meminfo)
  awk -v t="$total" -v a="$avail" 'BEGIN { printf "%.1f", (t - a) * 100 / t }'
}

disk_usage() {
  df -P / | awk 'NR == 2 { gsub("%", "", $5); print $5 }'
}

main() {
  local cpu mem disk

  cpu=$(cpu_usage)
  mem=$(mem_usage)
  disk=$(disk_usage)

  printf '[%s] CPU: %s%% | MEM: %s%% | DISK: %s%%\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$cpu" "$mem" "$disk" | tee -a "$LOG_FILE"

  if (( disk > DISK_THRESHOLD )); then
    printf '[WARNING] Disk space high!\n' | tee -a "$LOG_FILE"
  fi
}

main
