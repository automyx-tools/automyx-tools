#!/usr/bin/env bash
set -u

VERSION="0.1.0"
OUTPUT_PATH="./server-health.csv"
S3_URI=""
REMOTE_URI=""
SERVICES=""
PRINT_HEADER=0
STDOUT_ONLY=0

usage() {
  cat <<'USAGE'
AutoMyx Server Health Check

Usage:
  ./server-health-check.sh [options]

Options:
  -o, --output FILE        CSV output file. Default: ./server-health.csv
  --stdout                 Print CSV row to stdout only
  --header                 Print CSV header to stdout and exit
  --services LIST          Comma-separated services to check, e.g. ssh,nginx
  --s3 S3_URI              Upload CSV file to S3, e.g. s3://my-bucket/reports/
  --remote USER@HOST:PATH  Upload CSV file with scp to a central server
  -h, --help               Show this help
  --version                Show version

Examples:
  ./server-health-check.sh
  ./server-health-check.sh --services ssh,nginx --output /var/tmp/server-health.csv
  ./server-health-check.sh --output /var/tmp/server-health.csv --s3 s3://my-bucket/server-health/
  ./server-health-check.sh --output /var/tmp/server-health.csv --remote monitor@10.0.0.10:/data/reports/

Notes:
  - Designed for cron.
  - Writes one CSV row per run.
  - Uploads only when --s3 or --remote is provided.
USAGE
}

need_value() {
  if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
    echo "Missing value for $1" >&2
    usage >&2
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -o|--output)
      need_value "$@"
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --stdout)
      STDOUT_ONLY=1
      shift
      ;;
    --header)
      PRINT_HEADER=1
      shift
      ;;
    --services)
      need_value "$@"
      SERVICES="$2"
      shift 2
      ;;
    --s3)
      need_value "$@"
      S3_URI="$2"
      shift 2
      ;;
    --remote)
      need_value "$@"
      REMOTE_URI="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --version)
      echo "$VERSION"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

csv_escape() {
  value="${1:-}"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  value="${value//\"/\"\"}"
  printf '"%s"' "$value"
}

csv_join() {
  first=1
  for value in "$@"; do
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    csv_escape "$value"
    first=0
  done
  printf '\n'
}

header() {
  csv_join \
    timestamp_utc hostname primary_ip os kernel uptime_seconds cpu_cores \
    load1 load5 load15 mem_total_mb mem_available_mb mem_used_pct \
    swap_total_mb swap_used_pct root_size_gb root_available_gb root_used_pct \
    max_fs_size_gb max_fs_available_gb max_fs_used_pct max_fs_mount \
    max_inode_used_pct max_inode_mount zombie_count running_tasks total_tasks \
    top_cpu_process top_cpu_pct top_mem_process top_mem_pct failed_services \
    watched_services overall_status
}

num_or_zero() {
  value="${1:-0}"
  case "$value" in
    ''|*[!0-9.]*)
      echo 0
      ;;
    *)
      echo "$value"
      ;;
  esac
}

root_df_values() {
  df -Pk "$1" 2>/dev/null |
    awk 'NR == 2 {
      gsub("%","",$5)
      printf "%.2f|%.2f|%s\n", $2/1024/1024, $4/1024/1024, $5
    }'
}

max_df_usage() {
  df -Pk 2>/dev/null |
    awk 'NR > 1 {
      gsub("%","",$5)
      if ($5+0 > max) {
        max=$5+0
        size=$2/1024/1024
        avail=$4/1024/1024
        mount=$6
      }
    } END {
      printf "%.2f|%.2f|%s|%s\n", size, avail, max, mount
    }'
}

max_inode_usage() {
  df -Pi 2>/dev/null | awk 'NR > 1 { gsub("%","",$5); if ($5+0 > max) { max=$5+0; mount=$6 } } END { print max "|" mount }'
}

service_summary() {
  if [ -z "$SERVICES" ]; then
    echo "not_configured"
    return
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    echo "systemctl_not_available"
    return
  fi

  old_ifs="$IFS"
  IFS=','
  summary=""
  for svc in $SERVICES; do
    svc="$(echo "$svc" | awk '{$1=$1; print}')"
    [ -z "$svc" ] && continue
    state="$(systemctl is-active "$svc" 2>/dev/null || true)"
    [ -z "$state" ] && state="unknown"
    if [ -n "$summary" ]; then
      summary="$summary;$svc=$state"
    else
      summary="$svc=$state"
    fi
  done
  IFS="$old_ifs"
  echo "${summary:-not_configured}"
}

overall_status() {
  mem_used="$1"
  root_used="$2"
  max_fs="$3"
  failed="$4"
  watched="$5"

  if [ "$failed" != "none" ] && [ "$failed" != "unknown" ]; then
    echo "WARN"
    return
  fi
  if echo "$watched" | grep -qE '=failed|=inactive|=unknown'; then
    echo "WARN"
    return
  fi
  if awk -v v="$mem_used" 'BEGIN { exit !(v >= 90) }'; then
    echo "WARN"
    return
  fi
  if awk -v v="$root_used" 'BEGIN { exit !(v >= 90) }'; then
    echo "WARN"
    return
  fi
  if awk -v v="$max_fs" 'BEGIN { exit !(v >= 90) }'; then
    echo "WARN"
    return
  fi
  echo "OK"
}

row() {
  timestamp_utc="$(date -u "+%Y-%m-%dT%H:%M:%SZ")"
  hostname_value="$(hostname 2>/dev/null || echo unknown)"
  primary_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [ -z "$primary_ip" ] && primary_ip="unknown"
  os_value="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
  kernel_value="$(uname -srmo 2>/dev/null || echo unknown)"
  uptime_seconds="$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)"
  cpu_cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 0)"
  load_values="$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null || echo "0 0 0")"
  load1="$(echo "$load_values" | awk '{print $1}')"
  load5="$(echo "$load_values" | awk '{print $2}')"
  load15="$(echo "$load_values" | awk '{print $3}')"

  mem_total_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  mem_available_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  mem_total_mb=$((mem_total_kb / 1024))
  mem_available_mb=$((mem_available_kb / 1024))
  mem_used_pct="$(awk -v total="$mem_total_kb" -v avail="$mem_available_kb" 'BEGIN { if (total > 0) printf "%.2f", ((total-avail)/total)*100; else print "0.00" }')"

  swap_total_kb="$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  swap_free_kb="$(awk '/^SwapFree:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  swap_total_mb=$((swap_total_kb / 1024))
  swap_used_pct="$(awk -v total="$swap_total_kb" -v free="$swap_free_kb" 'BEGIN { if (total > 0) printf "%.2f", ((total-free)/total)*100; else print "0.00" }')"

  root_df_pair="$(root_df_values /)"
  root_size_gb="$(echo "$root_df_pair" | awk -F'|' '{print $1}')"
  root_available_gb="$(echo "$root_df_pair" | awk -F'|' '{print $2}')"
  root_used_pct="$(echo "$root_df_pair" | awk -F'|' '{print $3}')"
  root_size_gb="$(num_or_zero "$root_size_gb")"
  root_available_gb="$(num_or_zero "$root_available_gb")"
  root_used_pct="$(num_or_zero "$root_used_pct")"
  max_fs_pair="$(max_df_usage)"
  max_fs_size_gb="$(echo "$max_fs_pair" | awk -F'|' '{print $1}')"
  max_fs_available_gb="$(echo "$max_fs_pair" | awk -F'|' '{print $2}')"
  max_fs_used_pct="$(echo "$max_fs_pair" | awk -F'|' '{print $3}')"
  max_fs_mount="$(echo "$max_fs_pair" | awk -F'|' '{print $4}')"
  max_fs_size_gb="$(num_or_zero "$max_fs_size_gb")"
  max_fs_available_gb="$(num_or_zero "$max_fs_available_gb")"
  max_fs_used_pct="$(num_or_zero "$max_fs_used_pct")"
  [ -z "$max_fs_mount" ] && max_fs_mount="unknown"

  max_inode_pair="$(max_inode_usage)"
  max_inode_used_pct="$(echo "$max_inode_pair" | awk -F'|' '{print $1}')"
  max_inode_mount="$(echo "$max_inode_pair" | awk -F'|' '{print $2}')"
  max_inode_used_pct="$(num_or_zero "$max_inode_used_pct")"
  [ -z "$max_inode_mount" ] && max_inode_mount="unknown"

  zombie_count="$(ps -eo stat 2>/dev/null | awk '$1 ~ /^Z/ {count++} END {print count+0}')"
  running_tasks="$(awk '{print $4}' /proc/loadavg 2>/dev/null | awk -F/ '{print $1}' || echo 0)"
  total_tasks="$(awk '{print $4}' /proc/loadavg 2>/dev/null | awk -F/ '{print $2}' || echo 0)"
  top_cpu_line="$(ps -eo comm,pcpu --sort=-pcpu 2>/dev/null | awk 'NR == 2 {print $1 "|" $2}')"
  top_cpu_process="$(echo "$top_cpu_line" | awk -F'|' '{print $1}')"
  top_cpu_pct="$(echo "$top_cpu_line" | awk -F'|' '{print $2}')"
  [ -z "$top_cpu_process" ] && top_cpu_process="unknown"
  top_cpu_pct="$(num_or_zero "$top_cpu_pct")"
  top_mem_line="$(ps -eo comm,pmem --sort=-pmem 2>/dev/null | awk 'NR == 2 {print $1 "|" $2}')"
  top_mem_process="$(echo "$top_mem_line" | awk -F'|' '{print $1}')"
  top_mem_pct="$(echo "$top_mem_line" | awk -F'|' '{print $2}')"
  [ -z "$top_mem_process" ] && top_mem_process="unknown"
  top_mem_pct="$(num_or_zero "$top_mem_pct")"

  if command -v systemctl >/dev/null 2>&1; then
    failed_services="$(systemctl --failed --no-legend --no-pager 2>/dev/null | awk '{print $1}' | paste -sd ';' -)"
    [ -z "$failed_services" ] && failed_services="none"
  else
    failed_services="unknown"
  fi
  watched_services="$(service_summary)"
  status="$(overall_status "$mem_used_pct" "$root_used_pct" "$max_fs_used_pct" "$failed_services" "$watched_services")"

  csv_join \
    "$timestamp_utc" "$hostname_value" "$primary_ip" "$os_value" "$kernel_value" "$uptime_seconds" "$cpu_cores" \
    "$load1" "$load5" "$load15" "$mem_total_mb" "$mem_available_mb" "$mem_used_pct" \
    "$swap_total_mb" "$swap_used_pct" "$root_size_gb" "$root_available_gb" "$root_used_pct" \
    "$max_fs_size_gb" "$max_fs_available_gb" "$max_fs_used_pct" "$max_fs_mount" \
    "$max_inode_used_pct" "$max_inode_mount" "$zombie_count" "$running_tasks" "$total_tasks" \
    "$top_cpu_process" "$top_cpu_pct" "$top_mem_process" "$top_mem_pct" "$failed_services" \
    "$watched_services" "$status"
}

if [ "$PRINT_HEADER" -eq 1 ]; then
  header
  exit 0
fi

csv_row="$(row)"

if [ "$STDOUT_ONLY" -eq 1 ]; then
  header
  printf "%s\n" "$csv_row"
  exit 0
fi

output_dir="$(dirname "$OUTPUT_PATH")"
if [ ! -d "$output_dir" ]; then
  echo "Output directory does not exist: $output_dir" >&2
  exit 1
fi

if [ ! -s "$OUTPUT_PATH" ]; then
  header > "$OUTPUT_PATH"
fi
printf "%s\n" "$csv_row" >> "$OUTPUT_PATH"
echo "Wrote CSV row: $OUTPUT_PATH"

if [ -n "$S3_URI" ]; then
  if command -v aws >/dev/null 2>&1; then
    aws s3 cp "$OUTPUT_PATH" "$S3_URI"
  else
    echo "aws CLI not available. Skipping S3 upload." >&2
  fi
fi

if [ -n "$REMOTE_URI" ]; then
  if command -v scp >/dev/null 2>&1; then
    scp "$OUTPUT_PATH" "$REMOTE_URI"
  else
    echo "scp not available. Skipping remote upload." >&2
  fi
fi
