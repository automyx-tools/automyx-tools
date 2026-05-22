#!/usr/bin/env bash
set -u

VERSION="0.1.0"
LOG_LINES=80
OUTPUT_DIR=""

usage() {
  cat <<'USAGE'
AutoMyx Linux Slow SSH Triage

Usage:
  sudo ./ssh-triage.sh [options]

Options:
  -l, --lines N        Auth log lines to show. Default: 80
  -o, --output DIR     Save report to DIR as ssh-report-<timestamp>.txt
  -h, --help           Show this help
  --version            Show version

Notes:
  - Read-only evidence collection.
  - Does not change sshd_config, firewall, DNS, or service state.
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
}

ssh_service_status() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl status ssh --no-pager -l 2>/dev/null ||
      systemctl status sshd --no-pager -l 2>/dev/null ||
      echo "ssh/sshd service not found through systemctl."
  else
    echo "systemctl not available."
  fi
}

sshd_config_clues() {
  config="/etc/ssh/sshd_config"
  echo "sshd config path: $config"
  if [ -r "$config" ]; then
    grep -Ei '^\s*(Port|ListenAddress|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|UseDNS|GSSAPIAuthentication|MaxStartups|AllowUsers|AllowGroups|DenyUsers|DenyGroups)\b' "$config" 2>/dev/null ||
      echo "No matching active sshd_config settings found."
  else
    echo "Cannot read $config"
  fi
  echo
  echo "sshd effective config, when available:"
  if command -v sshd >/dev/null 2>&1; then
    sshd -T 2>/dev/null |
      grep -Ei '^(port|listenaddress|permitrootlogin|passwordauthentication|pubkeyauthentication|usedns|gssapiauthentication|maxstartups|allowusers|allowgroups|denyusers|denygroups)\b' ||
      echo "Unable to read sshd -T output."
  else
    echo "sshd command not available."
  fi
}

port_clues() {
  echo "Listening SSH sockets:"
  if command -v ss >/dev/null 2>&1; then
    ss -lntup 2>/dev/null | grep -Ei '(:22\s|sshd|ssh)' || echo "No SSH listener found in ss output."
  else
    echo "ss command not available."
  fi
  echo
  echo "Firewall clues:"
  if command -v ufw >/dev/null 2>&1; then
    ufw status verbose 2>/dev/null || true
  fi
  if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --list-all 2>/dev/null || true
  fi
  if command -v iptables >/dev/null 2>&1; then
    iptables -S 2>/dev/null | sed -n '1,80p'
  fi
}

auth_logs() {
  echo "Recent SSH/auth log lines:"
  if command -v journalctl >/dev/null 2>&1; then
    journalctl -u ssh -u sshd -n "$LOG_LINES" --no-pager 2>/dev/null ||
      journalctl -n "$LOG_LINES" --no-pager 2>/dev/null | grep -Ei 'ssh|sshd|authentication|failed|accepted'
  fi
  for file in /var/log/auth.log /var/log/secure; do
    if [ -r "$file" ]; then
      echo
      echo "$file:"
      grep -Ei 'ssh|sshd|failed|accepted|invalid|disconnect|pam' "$file" 2>/dev/null | tail -n "$LOG_LINES"
    fi
  done
}

dns_and_network_clues() {
  echo "Resolver configuration:"
  sed -n '1,80p' /etc/resolv.conf 2>/dev/null || true
  echo
  echo "Name service switch hosts line:"
  grep '^hosts:' /etc/nsswitch.conf 2>/dev/null || true
  echo
  echo "Default routes:"
  ip route 2>/dev/null || route -n 2>/dev/null || true
  echo
  echo "Interface summary:"
  ip -brief addr 2>/dev/null || ip addr 2>/dev/null | sed -n '1,80p'
}

resource_clues() {
  echo "Load and memory:"
  uptime 2>/dev/null || true
  free -h 2>/dev/null || true
  echo
  echo "Disk usage:"
  df -hT / /var /tmp 2>/dev/null || df -hT 2>/dev/null | sed -n '1,20p'
}

recommendations() {
  cat <<'TEXT'
Fast decision guide:
  1. If ssh/sshd is not active, inspect service logs before restarting.
  2. If no listener exists, verify sshd_config Port and ListenAddress.
  3. If login is slow after connection, check DNS, UseDNS, GSSAPI, and PAM delays.
  4. If authentication fails, inspect auth logs and account/key settings.
  5. If server resources are exhausted, fix CPU, memory, or disk first.
  6. For cloud servers, also check security groups, NACLs, and route tables.

Useful next commands:
  systemctl status ssh -l
  journalctl -u ssh --since "30 min ago"
  sshd -T
  ss -lntup | grep ssh
  tail -f /var/log/auth.log
TEXT
}

generate_report() {
  section "AutoMyx Linux Slow SSH Triage v$VERSION"
  header
  section "SSH Service Status"
  ssh_service_status
  section "sshd Configuration Clues"
  sshd_config_clues
  section "Port And Firewall Clues"
  port_clues
  section "Auth Log Clues"
  auth_logs
  section "DNS And Network Clues"
  dns_and_network_clues
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
  report_file="$OUTPUT_DIR/ssh-report-$(date +%Y%m%d-%H%M%S).txt"
  generate_report | tee "$report_file"
  echo
  echo "Saved report: $report_file"
else
  generate_report
fi
