# Linux High Memory Output Guide

Use this guide to interpret `memory-triage.sh` output and run equivalent manual commands.

## Quick Read

Start with:

1. Is `MemAvailable` low?
2. Is swap active?
3. Which process has the highest RSS?
4. Are there OOM kill messages?
5. Is cgroup memory limiting the workload?

## Memory Summary

Manual commands:

```bash
free -h
grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree' /proc/meminfo
```

Warning signs:

- `MemAvailable` is very low.
- Swap is being used heavily.
- Dirty/writeback memory remains high.

## Top Processes By RSS

Manual command:

```bash
ps -eo pid,ppid,user,stat,pmem,rss,vsz,etime,comm,args --sort=-rss | head
```

RSS is resident memory currently held in RAM.

## Swap And VM Activity

Manual command:

```bash
vmstat 1 5
swapon --show
```

Warning signs:

- `si` and `so` are non-zero repeatedly.
- System feels slow while swap activity is high.

## OOM Clues

Manual commands:

```bash
dmesg -T | grep -Ei 'oom|out of memory|killed process'
journalctl -k --since "2 hours ago"
```

If OOM happened, identify:

- Killed process
- Time of event
- Memory limit involved
- Whether it was host OOM or cgroup OOM

## cgroup Memory

Manual commands:

```bash
cat /sys/fs/cgroup/memory.current
cat /sys/fs/cgroup/memory.max
cat /sys/fs/cgroup/memory.events
```

Warning signs:

- `oom` or `oom_kill` counters increase.
- `memory.current` approaches `memory.max`.

## Common Conclusions

- One process dominates RSS: inspect that service and workload.
- OOM kill found: investigate memory growth before restarting.
- Swap active: memory pressure may be affecting latency.
- cgroup OOM: container memory limit may be too low.
- Slab high: inspect kernel/filesystem cache behavior.
