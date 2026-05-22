#!/usr/bin/env bash
set -u

VERSION="0.1.0"
TOP_LIMIT=15
TARGET_PATH="/"
OUTPUT_DIR=""

usage() {
  cat <<'USAGE'
AutoMyx Linux Disk Full Triage

Usage:
  sudo ./disk-triage.sh [options]

Options:
  -p, --path PATH      Path or mount point to inspect. Default: /
  -n, --top N          Number of entries to show. Default: 15
  -o, --output DIR     Save report to DIR as disk-report-<timestamp>.txt
  -h, --help           Show this help
  --version            Show version

Examples:
  sudo ./disk-triage.sh
  sudo ./disk-triage.sh --path /var --top 20 --output /tmp

Notes:
  - Read-only evidence collection.
  - Does not delete files, truncate logs, or change mounts.
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
    -p|--path)
      need_value "$@"
      TARGET_PATH="$2"
      shift 2
      ;;
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

if [ "$TOP_LIMIT" -lt 1 ]; then
  echo "--top must be greater than zero" >&2
  exit 1
fi

if [ ! -e "$TARGET_PATH" ]; then
  echo "Path does not exist: $TARGET_PATH" >&2
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

run_if_available() {
  if command -v "$1" >/dev/null 2>&1; then
    "$@"
  else
    echo "Command not available: $1"
  fi
}

header() {
  echo "Time: $(timestamp)"
  echo "Host: $(hostname 2>/dev/null || echo unknown)"
  echo "Kernel: $(uname -srmo 2>/dev/null || echo unknown)"
  echo "Target path: $TARGET_PATH"
}

filesystem_usage() {
  echo "Filesystem capacity:"
  df -hT "$TARGET_PATH" 2>/dev/null || df -hT
  echo
  echo "All mounted filesystems:"
  df -hT 2>/dev/null
}

inode_usage() {
  echo "Inode usage for target:"
  df -ih "$TARGET_PATH" 2>/dev/null || df -ih
  echo
  echo "All inode usage:"
  df -ih 2>/dev/null
}

top_directories() {
  echo "Largest entries directly under $TARGET_PATH:"
  du -xhd1 "$TARGET_PATH" 2>/dev/null | sort -hr | head -n "$TOP_LIMIT" ||
    echo "Unable to read some directories. Try sudo."
}

large_files() {
  echo "Largest files under $TARGET_PATH:"
  find "$TARGET_PATH" -xdev -type f -printf '%s\t%p\n' 2>/dev/null |
    sort -nr |
    head -n "$TOP_LIMIT" |
    awk '{ size=$1; $1=""; printf "%.2f MB\t%s\n", size/1024/1024, $0 }'
}

deleted_open_files() {
  echo "Deleted files still held open by processes:"
  if command -v lsof >/dev/null 2>&1; then
    lsof +L1 2>/dev/null | head -n "$((TOP_LIMIT + 1))"
  else
    echo "lsof not available. Install lsof to detect deleted files still consuming disk."
  fi
}

log_clues() {
  echo "journalctl disk usage:"
  run_if_available journalctl --disk-usage
  echo
  echo "Common large log files:"
  find /var/log -xdev -type f -printf '%s\t%p\n' 2>/dev/null |
    sort -nr |
    head -n "$TOP_LIMIT" |
    awk '{ size=$1; $1=""; printf "%.2f MB\t%s\n", size/1024/1024, $0 }'
}

package_cache_clues() {
  echo "Package cache clues:"
  if [ -d /var/cache/apt ]; then
    du -sh /var/cache/apt 2>/dev/null
  fi
  if [ -d /var/cache/yum ]; then
    du -sh /var/cache/yum 2>/dev/null
  fi
  if [ -d /var/cache/dnf ]; then
    du -sh /var/cache/dnf 2>/dev/null
  fi
}

container_clues() {
  echo "Container storage clues:"
  if command -v docker >/dev/null 2>&1; then
    docker system df 2>/dev/null || echo "docker found but docker system df failed."
  else
    echo "docker command not available."
  fi
  echo
  for dir in /var/lib/docker /var/lib/containerd /var/log/containers /var/log/pods; do
    if [ -d "$dir" ]; then
      du -sh "$dir" 2>/dev/null
    fi
  done
}

recommendations() {
  cat <<'TEXT'
Fast decision guide:
  1. If filesystem Use% is high, inspect the largest directories first.
  2. If inode IUse% is high, search for many small files.
  3. If deleted open files are large, restart the owning service after impact review.
  4. If /var/log is large, inspect log rotation and noisy services.
  5. If container storage is large, inspect images, containers, volumes, and logs.
  6. Capture evidence before deleting or truncating anything.

Useful next commands:
  du -xhd1 /var | sort -hr | head
  find /var -xdev -type f -size +100M -ls
  lsof +L1
  journalctl --disk-usage
  docker system df
TEXT
}

generate_report() {
  section "AutoMyx Linux Disk Full Triage v$VERSION"
  header
  section "Filesystem Usage"
  filesystem_usage
  section "Inode Usage"
  inode_usage
  section "Largest Directories"
  top_directories
  section "Largest Files"
  large_files
  section "Deleted Open Files"
  deleted_open_files
  section "Log Clues"
  log_clues
  section "Package Cache Clues"
  package_cache_clues
  section "Container Storage Clues"
  container_clues
  section "Recommended Next Steps"
  recommendations
}

if [ -n "$OUTPUT_DIR" ]; then
  if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Output directory does not exist: $OUTPUT_DIR" >&2
    exit 1
  fi
  report_file="$OUTPUT_DIR/disk-report-$(date +%Y%m%d-%H%M%S).txt"
  generate_report | tee "$report_file"
  echo
  echo "Saved report: $report_file"
else
  generate_report
fi
