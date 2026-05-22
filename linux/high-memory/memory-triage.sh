#!/usr/bin/env bash
set -u

VERSION="0.1.0"
TOP_LIMIT=10
OUTPUT_DIR=""

usage() {
  cat <<'USAGE'
AutoMyx Linux High Memory Triage

Usage:
  sudo ./memory-triage.sh [options]

Options:
  -n, --top N          Number of top processes to show. Default: 10
  -o, --output DIR     Save report to DIR as memory-report-<timestamp>.txt
  -h, --help           Show this help
  --version            Show version

Notes:
  - Read-only evidence collection.
  - Does not kill processes, drop caches, or change swap.
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
    -n|--top)
      need_value "$@"
      TOP_LIMIT="$2"
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

case "$TOP_LIMIT" in
  ''|*[!0-9]*)
    echo "Invalid --top value: $TOP_LIMIT" >&2
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

read_file() {
  if [ -r "$1" ]; then
    cat "$1"
  else
    echo "Cannot read $1"
  fi
}

header() {
  echo "Time: $(timestamp)"
  echo "Host: $(hostname 2>/dev/null || echo unknown)"
  echo "Kernel: $(uname -srmo 2>/dev/null || echo unknown)"
}

memory_summary() {
  free -h 2>/dev/null || echo "free command not available."
  echo
  echo "Key /proc/meminfo fields:"
  grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Dirty|Writeback|Slab|SReclaimable|SUnreclaim):' /proc/meminfo 2>/dev/null
}

top_memory_processes() {
  ps -eo pid,ppid,user,stat,pmem,rss,vsz,etime,comm,args --sort=-rss |
    awk -v limit="$TOP_LIMIT" 'NR == 1 || NR <= limit + 1'
}

swap_clues() {
  echo "Swap summary:"
  swapon --show 2>/dev/null || echo "swapon not available or no swap configured."
  echo
  echo "vmstat sample:"
  vmstat 1 3 2>/dev/null || echo "vmstat not available."
}

oom_clues() {
  echo "Recent OOM or memory pressure messages:"
  if command -v dmesg >/dev/null 2>&1; then
    dmesg -T 2>/dev/null |
      grep -Ei 'out of memory|oom|killed process|memory allocation|page allocation|swap' |
      tail -n 40 ||
      echo "No matching dmesg lines found or dmesg is restricted."
  else
    echo "dmesg not available."
  fi
  echo
  if command -v journalctl >/dev/null 2>&1; then
    journalctl -k --since "2 hours ago" --no-pager 2>/dev/null |
      grep -Ei 'out of memory|oom|killed process|memory allocation|page allocation|swap' |
      tail -n 40 ||
      echo "No matching journal lines found."
  fi
}

pressure_clues() {
  if [ -r /proc/pressure/memory ]; then
    read_file /proc/pressure/memory
  else
    echo "Memory pressure stall information is not available."
  fi
}

cgroup_clues() {
  echo "cgroup memory clues:"
  for file in /sys/fs/cgroup/memory.current /sys/fs/cgroup/memory.max /sys/fs/cgroup/memory.events /sys/fs/cgroup/memory.stat; do
    if [ -r "$file" ]; then
      echo
      echo "$file"
      cat "$file" 2>/dev/null | sed -n '1,40p'
    fi
  done
}

slab_clues() {
  echo "Slab memory:"
  grep -E '^(Slab|SReclaimable|SUnreclaim):' /proc/meminfo 2>/dev/null
  echo
  if [ -r /proc/slabinfo ]; then
    echo "Top slab caches by object size estimate:"
    awk 'NR > 2 { printf "%12d %s\n", $3*$4, $1 }' /proc/slabinfo 2>/dev/null |
      sort -nr |
      head -n "$TOP_LIMIT"
  fi
}

recommendations() {
  cat <<'TEXT'
Fast decision guide:
  1. If MemAvailable is low and one process dominates RSS, inspect that process first.
  2. If swap in/out is active, investigate memory pressure and latency.
  3. If OOM messages exist, identify the killed process and timeline.
  4. If cgroup memory events show oom/oom_kill, review container memory limits.
  5. If slab is unusually high, inspect kernel caches and filesystem activity.
  6. Capture evidence before restarting or killing processes.

Useful next commands:
  ps -eo pid,user,pmem,rss,comm,args --sort=-rss | head
  free -h
  vmstat 1
  cat /proc/pressure/memory
  journalctl -k --since "2 hours ago"
TEXT
}

generate_report() {
  section "AutoMyx Linux High Memory Triage v$VERSION"
  header
  section "Memory Summary"
  memory_summary
  section "Top Processes By RSS"
  top_memory_processes
  section "Swap And VM Activity"
  swap_clues
  section "OOM And Kernel Memory Clues"
  oom_clues
  section "Memory Pressure"
  pressure_clues
  section "cgroup Memory Clues"
  cgroup_clues
  section "Slab Memory Clues"
  slab_clues
  section "Recommended Next Steps"
  recommendations
}

if [ -n "$OUTPUT_DIR" ]; then
  if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Output directory does not exist: $OUTPUT_DIR" >&2
    exit 1
  fi
  report_file="$OUTPUT_DIR/memory-report-$(date +%Y%m%d-%H%M%S).txt"
  generate_report | tee "$report_file"
  echo
  echo "Saved report: $report_file"
else
  generate_report
fi
