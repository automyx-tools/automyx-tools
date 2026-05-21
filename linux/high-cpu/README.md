# Linux High CPU Triage

First-pass troubleshooting tool for Linux servers with high CPU or high load.

This scenario belongs to the AutoMyx **Linux Troubleshooting** playlist.

## Files

| File | Purpose |
| --- | --- |
| [highcpu-triage.sh](highcpu-triage.sh) | Read-only Linux high CPU triage script |
| [OUTPUT-GUIDE.md](OUTPUT-GUIDE.md) | Explains how to interpret the script output |
| [VIDEO-01-linux-high-cpu.md](VIDEO-01-linux-high-cpu.md) | Video title, description, chapters, script, and demo notes |

## Run

```bash
chmod +x highcpu-triage.sh
sudo ./highcpu-triage.sh
```

Save a report:

```bash
sudo ./highcpu-triage.sh --top 15 --sample 5 --output /tmp
```

## What It Checks

- Host, kernel, CPU core count, load average, and runnable tasks
- Top CPU processes
- Top CPU threads
- Per-core CPU usage when `mpstat` is installed
- Sampled process/thread CPU when `pidstat` is installed
- CPU, I/O, and memory pressure from `/proc/pressure`
- Run queue and context switches from `vmstat`
- Kernel messages related to CPU stalls, throttling, OOM, and lockups
- Interrupt clues
- cgroup/container CPU clues
- Running service clues when systemd is available

## Recommended Dependency

The script works with standard Linux tools, but `sysstat` improves the report.

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y sysstat
```

RHEL/CentOS/Amazon Linux:

```bash
sudo yum install -y sysstat
```

## Safety

This tool is read-only. It does not restart services, kill processes, change kernel settings, or edit configuration files.
