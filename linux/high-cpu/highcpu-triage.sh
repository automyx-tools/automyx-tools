#!/usr/bin/env bash
set -u

VERSION="0.1.0"
TOP_LIMIT=10
SAMPLE_SECONDS=3
OUTPUT_DIR=""

need_value() {
  if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
    echo "Missing value for $1" >&2
    usage >&2
    exit 1
  fi
}

usage() {
  cat <<'USAGE'
AutoMyx Linux High CPU Triage

Usage:
  sudo ./highcpu-triage.sh [options]

Options:
  -n, --top N          Number of top processes to show. Default: 10
  -s, --sample SEC    mpstat/pidstat sample duration. Default: 3
  -o, --output DIR    Save report to DIR as highcpu-report-<timestamp>.txt
  -h, --help          Show this help
  --version           Show version

Examples:
  sudo ./highcpu-triage.sh
  sudo ./highcpu-triage.sh --top 15 --sample 5 --output /tmp

Notes:
  - Works without extra packages, but sysstat adds better mpstat/pidstat data.
  - Designed for first-pass production triage, not destructive remediation.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|--top)
      need_value "$@"
      TOP_LIMIT="${2:-}"
      shift 2
      ;;
    -s|--sample)
      need_value "$@"
      SAMPLE_SECONDS="${2:-}"
      shift 2
      ;;
    -o|--output)
      need_value "$@"
      OUTPUT_DIR="${2:-}"
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

case "$TOP_LIMIT" in
  ''|*[!0-9]*)
    echo "Invalid --top value: $TOP_LIMIT" >&2
    exit 1
    ;;
esac

case "$SAMPLE_SECONDS" in
  ''|*[!0-9]*)
    echo "Invalid --sample value: $SAMPLE_SECONDS" >&2
    exit 1
    ;;
esac

if [ "$TOP_LIMIT" -lt 1 ] || [ "$SAMPLE_SECONDS" -lt 1 ]; then
  echo "--top and --sample must be greater than zero" >&2
  exit 1
fi

timestamp() {
  date "+%Y-%m-%d %H:%M:%S %Z"
}

section() {
  printf "\n================================================================================\n"
  printf "%s\n" "$1"
  printf "================================================================================\n"
}

run() {
  if command -v "$1" >/dev/null 2>&1; then
    "$@"
  else
    echo "Command not available: $1"
  fi
}

read_file() {
  if [ -r "$1" ]; then
    cat "$1"
  else
    echo "Cannot read $1"
  fi
}

human_status() {
  load_1="$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo unknown)"
  cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
  runnable="$(awk '{print $4}' /proc/loadavg 2>/dev/null | awk -F/ '{print $1}' || echo unknown)"

  echo "Time: $(timestamp)"
  echo "Host: $(hostname 2>/dev/null || echo unknown)"
  echo "Kernel: $(uname -srmo 2>/dev/null || echo unknown)"
  echo "CPU cores online: $cpu_count"
  echo "1-minute load average: $load_1"
  echo "Runnable/total tasks: $runnable"

  if awk -v load_avg="$load_1" -v cores="$cpu_count" 'BEGIN { exit !(load_avg > cores) }'; then
    echo "Initial signal: load is higher than CPU core count. CPU pressure is likely."
  else
    echo "Initial signal: load is not above CPU core count. Check I/O wait, short spikes, or per-process hotspots."
  fi
}

top_processes() {
  ps -eo pid,ppid,user,stat,ni,pri,pcpu,pmem,etime,comm,args --sort=-pcpu |
    awk -v limit="$TOP_LIMIT" 'NR == 1 || NR <= limit + 1'
}

top_threads() {
  ps -eLo pid,tid,ppid,user,stat,pcpu,pmem,comm --sort=-pcpu |
    awk -v limit="$TOP_LIMIT" 'NR == 1 || NR <= limit + 1'
}

cpu_snapshot() {
  if command -v mpstat >/dev/null 2>&1; then
    mpstat -P ALL "$SAMPLE_SECONDS" 1
  else
    echo "mpstat not found. Install sysstat for per-core CPU usage."
    echo
    echo "Fallback /proc/stat snapshot:"
    read_file /proc/stat | sed -n '1,9p'
  fi
}

pid_snapshot() {
  if command -v pidstat >/dev/null 2>&1; then
    pidstat -u -t -r "$SAMPLE_SECONDS" 1 | sed -n '1,80p'
  else
    echo "pidstat not found. Install sysstat for sampled process and thread CPU usage."
  fi
}

pressure_snapshot() {
  if [ -d /proc/pressure ]; then
    echo "CPU pressure:"
    read_file /proc/pressure/cpu
    echo
    echo "I/O pressure:"
    read_file /proc/pressure/io
    echo
    echo "Memory pressure:"
    read_file /proc/pressure/memory
  else
    echo "Pressure stall information is not available on this kernel."
  fi
}

interrupts_snapshot() {
  echo "Top interrupt counters:"
  awk 'NR == 1 || NR > 1 {print}' /proc/interrupts 2>/dev/null |
    sed -n '1,25p' ||
    echo "Cannot read /proc/interrupts"
}

kernel_hotspots() {
  echo "Run queue and context switch indicators:"
  vmstat 1 3 2>/dev/null || echo "vmstat not available"
  echo
  echo "Recent kernel messages that may relate to CPU, throttling, or stalls:"
  if command -v dmesg >/dev/null 2>&1; then
    dmesg -T 2>/dev/null |
      grep -Ei 'cpu|soft lockup|hard lockup|thrott|oom|stall|hung|rcu' |
      tail -n 30 ||
      echo "No matching dmesg lines found or dmesg is restricted."
  else
    echo "dmesg not available"
  fi
}

container_clues() {
  echo "cgroup CPU clues:"
  if [ -r /sys/fs/cgroup/cpu.stat ]; then
    read_file /sys/fs/cgroup/cpu.stat
  elif [ -r /sys/fs/cgroup/cpu/cpu.stat ]; then
    read_file /sys/fs/cgroup/cpu/cpu.stat
  else
    echo "No readable cgroup CPU stat file found."
  fi

  echo
  echo "Container markers:"
  if grep -qaE '(docker|kubepods|containerd|libpod)' /proc/1/cgroup 2>/dev/null; then
    cat /proc/1/cgroup
  else
    echo "No common container marker found in /proc/1/cgroup."
  fi
}

service_clues() {
  echo "Top systemd control groups by CPU, when available:"
  if command -v systemd-cgtop >/dev/null 2>&1; then
    systemd-cgtop --raw --batch -n 1 2>/dev/null | sed -n '1,25p' ||
      echo "systemd-cgtop failed or systemd cgroup data is restricted."
  else
    echo "systemd-cgtop not available."
  fi

  echo
  echo "Running systemd services:"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --no-pager --type=service --state=running 2>/dev/null | sed -n '1,30p' ||
      echo "systemctl failed or systemd is not available."
  else
    echo "systemctl not available."
  fi
}

recommendations() {
  cat <<'TEXT'
Fast decision guide:
  1. If one process dominates CPU, inspect its logs and workload first.
  2. If one PID has one hot TID, convert TID to hex and capture a thread dump when supported.
  3. If load is high but CPU idle is also high, investigate I/O wait or blocked tasks.
  4. If softirq/interrupts are high, check network, disk, and driver activity.
  5. If cgroup throttling is high, review container CPU limits and application concurrency.
  6. Capture before/after evidence before restarting services in production.

Useful next commands:
  top -H -p <PID>
  perf top -p <PID>
  strace -p <PID> -f -tt -T
  journalctl -u <service> --since "30 min ago"
  pidstat -u -t -p <PID> 1
TEXT
}

generate_report() {
  section "AutoMyx Linux High CPU Triage v$VERSION"
  human_status

  section "Top Processes By CPU"
  top_processes

  section "Top Threads By CPU"
  top_threads

  section "CPU Per-Core Snapshot"
  cpu_snapshot

  section "Sampled Process CPU Snapshot"
  pid_snapshot

  section "CPU, I/O, And Memory Pressure"
  pressure_snapshot

  section "Run Queue, Context Switches, And Kernel Clues"
  kernel_hotspots

  section "Interrupt Clues"
  interrupts_snapshot

  section "Container And Cgroup Clues"
  container_clues

  section "Service Clues"
  service_clues

  section "Recommended Next Steps"
  recommendations
}

if [ -n "$OUTPUT_DIR" ]; then
  if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Output directory does not exist: $OUTPUT_DIR" >&2
    exit 1
  fi

  report_file="$OUTPUT_DIR/highcpu-report-$(date +%Y%m%d-%H%M%S).txt"
  generate_report | tee "$report_file"
  echo
  echo "Saved report: $report_file"
else
  generate_report
fi
