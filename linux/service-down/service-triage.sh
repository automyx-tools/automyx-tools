#!/usr/bin/env bash
set -u

VERSION="0.1.0"
SERVICE_NAME=""
LOG_LINES=80
OUTPUT_DIR=""

usage() {
  cat <<'USAGE'
AutoMyx Linux Service Down Triage

Usage:
  sudo ./service-triage.sh --service SERVICE [options]
  sudo ./service-triage.sh [options]

Options:
  -s, --service NAME   systemd service name to inspect
  -l, --lines N        Journal lines to show. Default: 80
  -o, --output DIR     Save report to DIR as service-report-<timestamp>.txt
  -h, --help           Show this help
  --version            Show version

Examples:
  sudo ./service-triage.sh --service nginx
  sudo ./service-triage.sh --service ssh --lines 120 --output /tmp

Notes:
  - Read-only evidence collection.
  - Does not start, stop, restart, enable, or disable services.
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
    -s|--service)
      need_value "$@"
      SERVICE_NAME="$2"
      shift 2
      ;;
    -l|--lines)
      need_value "$@"
      LOG_LINES="$2"
      shift 2
      ;;
    -o|--output)
      need_value "$@"
      OUTPUT_DIR="$2"
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

case "$LOG_LINES" in
  ''|*[!0-9]*)
    echo "Invalid --lines value: $LOG_LINES" >&2
    exit 1
    ;;
esac

timestamp() {
  date "+%Y-%m-%d %H:%M:%S %Z"
}

section() {
  printf "\n================================================================================\n"
  printf "%s\n" "$1"
  printf "================================================================================\n"
}

header() {
  echo "Time: $(timestamp)"
  echo "Host: $(hostname 2>/dev/null || echo unknown)"
  echo "Kernel: $(uname -srmo 2>/dev/null || echo unknown)"
  if [ -n "$SERVICE_NAME" ]; then
    echo "Target service: $SERVICE_NAME"
  else
    echo "Target service: not specified"
  fi
}

service_overview() {
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "systemctl not available."
    return
  fi

  if [ -n "$SERVICE_NAME" ]; then
    systemctl status "$SERVICE_NAME" --no-pager -l 2>&1 || true
    echo
    echo "Service properties:"
    systemctl show "$SERVICE_NAME" --no-pager \
      -p Id -p LoadState -p ActiveState -p SubState -p Result -p ExecMainStatus \
      -p ExecMainCode -p Restart -p NRestarts -p MainPID -p FragmentPath \
      -p UnitFileState -p ActiveEnterTimestamp -p InactiveEnterTimestamp 2>&1 || true
  else
    echo "Failed services:"
    systemctl --failed --no-pager 2>&1 || true
    echo
    echo "Running services:"
    systemctl --type=service --state=running --no-pager 2>/dev/null | sed -n '1,40p'
  fi
}

service_logs() {
  if ! command -v journalctl >/dev/null 2>&1; then
    echo "journalctl not available."
    return
  fi

  if [ -n "$SERVICE_NAME" ]; then
    journalctl -u "$SERVICE_NAME" -n "$LOG_LINES" --no-pager 2>&1 || true
  else
    journalctl -p warning -n "$LOG_LINES" --no-pager 2>&1 || true
  fi
}

process_and_port_clues() {
  if [ -n "$SERVICE_NAME" ] && command -v systemctl >/dev/null 2>&1; then
    main_pid="$(systemctl show "$SERVICE_NAME" -p MainPID --value 2>/dev/null || echo 0)"
    echo "MainPID: $main_pid"
    if [ "$main_pid" != "0" ] && [ -n "$main_pid" ]; then
      ps -fp "$main_pid" 2>/dev/null || true
      echo
      echo "Open files/listening sockets for MainPID:"
      if command -v ss >/dev/null 2>&1; then
        ss -lntup 2>/dev/null | grep -F "pid=$main_pid," || echo "No listening sockets found for MainPID."
      fi
    fi
  fi

  echo
  echo "Listening TCP/UDP sockets:"
  if command -v ss >/dev/null 2>&1; then
    ss -lntup 2>/dev/null | sed -n '1,80p'
  else
    echo "ss not available."
  fi
}

config_clues() {
  if [ -z "$SERVICE_NAME" ] || ! command -v systemctl >/dev/null 2>&1; then
    echo "Specify --service to inspect unit file paths."
    return
  fi

  fragment="$(systemctl show "$SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)"
  dropins="$(systemctl show "$SERVICE_NAME" -p DropInPaths --value 2>/dev/null || true)"
  echo "Unit file: ${fragment:-unknown}"
  echo "Drop-ins: ${dropins:-none}"
  if [ -n "$fragment" ] && [ -r "$fragment" ]; then
    echo
    echo "Unit file preview:"
    sed -n '1,120p' "$fragment"
  fi
}

resource_clues() {
  echo "System load and memory:"
  uptime 2>/dev/null || true
  free -h 2>/dev/null || true
  echo
  echo "Disk usage:"
  df -hT 2>/dev/null | sed -n '1,20p'
}

recommendations() {
  cat <<'TEXT'
Fast decision guide:
  1. If LoadState is not loaded, check unit file path and package installation.
  2. If ActiveState is failed, read Result, ExecMainStatus, and journal errors.
  3. If restart count is increasing, inspect recent logs and dependencies.
  4. If port is already in use, identify the process holding it.
  5. If disk or memory is exhausted, fix the resource issue before restarting.
  6. Capture evidence before restarting the service.

Useful next commands:
  systemctl status <service> -l
  journalctl -u <service> --since "30 min ago"
  systemctl cat <service>
  ss -lntup
  systemctl reset-failed <service>
TEXT
}

generate_report() {
  section "AutoMyx Linux Service Down Triage v$VERSION"
  header
  section "Service Overview"
  service_overview
  section "Service Logs"
  service_logs
  section "Process And Port Clues"
  process_and_port_clues
  section "Service Configuration Clues"
  config_clues
  section "Resource Clues"
  resource_clues
  section "Recommended Next Steps"
  recommendations
}

if [ -n "$OUTPUT_DIR" ]; then
  if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Output directory does not exist: $OUTPUT_DIR" >&2
    exit 1
  fi
  report_file="$OUTPUT_DIR/service-report-$(date +%Y%m%d-%H%M%S).txt"
  generate_report | tee "$report_file"
  echo
  echo "Saved report: $report_file"
else
  generate_report
fi
