# Server Health Check Output Guide

`server-health-check.sh` writes CSV output with one row per run.

## Example

```csv
timestamp_utc,hostname,primary_ip,os,kernel,uptime_seconds,cpu_cores,load1,load5,load15,mem_total_mb,mem_available_mb,mem_used_pct,swap_total_mb,swap_used_pct,root_size_gb,root_available_gb,root_used_pct,max_fs_size_gb,max_fs_available_gb,max_fs_used_pct,max_fs_mount,max_inode_used_pct,max_inode_mount,zombie_count,running_tasks,total_tasks,top_cpu_process,top_cpu_pct,top_mem_process,top_mem_pct,failed_services,watched_services,overall_status
```

## Important Columns

| Column | Meaning |
| --- | --- |
| `timestamp_utc` | UTC time when the check ran |
| `hostname` | Server or VM hostname |
| `primary_ip` | First IP returned by `hostname -I` |
| `load1`, `load5`, `load15` | Load averages |
| `mem_available_mb` | Available memory in MB |
| `mem_used_pct` | Estimated memory used percentage |
| `swap_used_pct` | Swap usage percentage |
| `root_size_gb` | Total size of `/` filesystem in GB |
| `root_available_gb` | Available space on `/` filesystem in GB |
| `root_used_pct` | `/` filesystem usage |
| `max_fs_size_gb` | Total size of the most-used filesystem in GB |
| `max_fs_available_gb` | Available space on the most-used filesystem in GB |
| `max_fs_used_pct` | Highest filesystem usage on the server |
| `max_fs_mount` | Mount point with highest filesystem usage |
| `max_inode_used_pct` | Highest inode usage |
| `zombie_count` | Number of zombie processes |
| `top_cpu_process` | Process name with highest CPU at sample time |
| `top_mem_process` | Process name with highest memory at sample time |
| `failed_services` | Failed systemd services, or `none` |
| `watched_services` | Optional service states from `--services` |
| `overall_status` | `OK` or `WARN` |

## Interpreting Status

`overall_status=WARN` when:

- Failed systemd services exist
- A watched service is failed, inactive, or unknown
- Memory used percentage is 90 or higher
- Root filesystem usage is 90 or higher
- Any filesystem usage is 90 or higher

## Manual Commands

Equivalent Linux commands:

```bash
hostname
hostname -I
cat /etc/os-release
uname -srmo
cat /proc/loadavg
free -h
df -hT
df -BG /
df -Pk /
df -ih
ps -eo stat
ps -eo comm,pcpu --sort=-pcpu | head
ps -eo comm,pmem --sort=-pmem | head
systemctl --failed
systemctl is-active ssh
```

## S3 Collection Pattern

Simple approach:

```bash
./server-health-check.sh --output /var/tmp/server-health.csv --s3 s3://my-bucket/server-health/
```

For many servers, use a hostname folder:

```bash
./server-health-check.sh --output /var/tmp/server-health.csv --s3 s3://my-bucket/server-health/$(hostname)/
```

## Central Server Pattern

```bash
./server-health-check.sh --output /var/tmp/server-health.csv --remote monitor@10.0.0.10:/data/reports/
```

Use SSH keys for non-interactive cron uploads.
