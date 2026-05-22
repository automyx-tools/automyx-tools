# Linux High Memory Triage

Read-only first-pass troubleshooting tool for Linux high memory, swap pressure, OOM, cgroup memory limits, and top RSS process issues.

This scenario belongs to the AutoMyx **Linux Troubleshooting** playlist.

## Files

| File | Purpose |
| --- | --- |
| [memory-triage.sh](memory-triage.sh) | Read-only Linux memory triage script |
| [OUTPUT-GUIDE.md](OUTPUT-GUIDE.md) | Explains how to interpret the script output |

## Run

```bash
chmod +x memory-triage.sh
sudo ./memory-triage.sh
```

Save a report:

```bash
sudo ./memory-triage.sh --top 15 --output /tmp
```

## What It Checks

- `free -h` memory summary
- Key `/proc/meminfo` fields
- Top processes by RSS
- Swap and `vmstat`
- OOM and kernel memory logs
- Memory pressure stall information
- cgroup memory clues
- Slab memory clues

## Safety

This tool is read-only. It does not kill processes, drop caches, change swap, or modify cgroup limits.
