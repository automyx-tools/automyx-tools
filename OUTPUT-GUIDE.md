# AutoMyx High CPU Report Output Guide

This guide explains how to interpret the output from `highcpu-triage.sh` and how to collect the same evidence manually with Linux commands.

The example below is based on Ubuntu 24.04 running on an AWS EC2 instance:

- Kernel: `Linux 6.17.0-1013-aws`
- CPU cores: `2`
- 1-minute load average: `0.09`
- CPU idle: `99.67%`
- Top application process: `uvicorn`
- cgroup throttling: `0`

This sample does not show an active high CPU incident. It is a healthy baseline report.

## Quick Interpretation

The fastest first read is:

1. Compare `1-minute load average` with `CPU cores online`.
2. Check `%idle`, `%iowait`, `%steal`, and `%soft` in the CPU snapshot.
3. Look at the top process and thread tables.
4. Check `/proc/pressure` for CPU, I/O, or memory waiting.
5. Check cgroup throttling if the workload runs in a container or has CPU limits.

For the Ubuntu 24.04 sample:

- `1-minute load average: 0.09` on `2` CPU cores means the server is not CPU saturated.
- `%idle: 99.67` means the CPU is mostly free.
- `uvicorn` used only `0.33%` in the sampled `pidstat` output.
- `nr_throttled 0` and `throttled_usec 0` mean the root cgroup was not CPU-throttled.
- CPU pressure `avg10=0.00` means tasks were not recently waiting for CPU.

## Section: Header And Host Summary

Example:

```text
CPU cores online: 2
1-minute load average: 0.09
Runnable/total tasks: 1
Initial signal: load is not above CPU core count.
```

How to read it:

- `CPU cores online` is the number of logical CPUs available.
- `1-minute load average` is the recent system load.
- A simple first check is: if load is higher than CPU count, investigate CPU pressure.
- `Runnable/total tasks` shows how many tasks are runnable compared with total tasks.

Healthy signs:

- Load average is below CPU core count.
- Runnable tasks are low.

Warning signs:

- Load average is consistently higher than CPU core count.
- Runnable tasks stay high for several samples.

Manual commands:

```bash
hostname
uname -srmo
nproc
uptime
cat /proc/loadavg
```

## Section: Top Processes By CPU

Example from the sample:

```text
PID  USER    %CPU  %MEM  COMMAND
535  root     1.4   4.5  snapd
527  root     1.2   2.4  amazon-ssm-agent
508  ubuntu   0.8   5.1  uvicorn
```

How to read it:

- `%CPU` shows recent CPU usage per process.
- `%MEM` helps identify whether the same process is also memory-heavy.
- `COMMAND` and full command line identify the service or application.

Healthy signs:

- No single process is consuming a large share of CPU.
- System processes use small amounts of CPU.

Warning signs:

- One process stays near or above `80-100%` on a single-core workload.
- On multi-core systems, one process may exceed `100%` if it uses multiple threads.
- Unknown or unexpected processes appear at the top.

Manual commands:

```bash
ps -eo pid,ppid,user,stat,ni,pri,pcpu,pmem,etime,comm,args --sort=-pcpu | head
top
htop
```

Next commands for a suspicious process:

```bash
ps -fp <PID>
ls -l /proc/<PID>/exe
cat /proc/<PID>/cmdline | tr '\0' ' '
journalctl _PID=<PID> --since "30 min ago"
```

## Section: Top Threads By CPU

Example:

```text
PID  TID  USER    %CPU  COMMAND
508  508  ubuntu   0.8  uvicorn
```

How to read it:

- `PID` is the process ID.
- `TID` is the thread ID.
- A hot thread can reveal the exact worker inside a multi-threaded process.

Healthy signs:

- No thread is consistently hot.

Warning signs:

- One thread stays high while the parent process looks normal.
- Java, database, web server, or Python worker threads dominate CPU.

Manual commands:

```bash
ps -eLo pid,tid,ppid,user,stat,pcpu,pmem,comm --sort=-pcpu | head
top -H -p <PID>
pidstat -u -t -p <PID> 1
```

For Java thread dumps, convert the decimal TID to hex:

```bash
printf '%x\n' <TID>
jstack <PID> | grep -i <hex_tid>
```

## Section: CPU Per-Core Snapshot

Example from the sample:

```text
%usr  %sys  %iowait  %soft  %steal  %idle
0.00  0.00     0.00   0.00    0.33  99.67
```

How to read it:

- `%usr`: application/user-space CPU.
- `%sys`: kernel CPU.
- `%iowait`: CPU waiting on disk or storage I/O.
- `%soft`: software interrupt CPU, often network-related.
- `%steal`: CPU time taken by the hypervisor on a VM.
- `%idle`: unused CPU.

Healthy signs:

- High `%idle`.
- Low `%iowait`, `%soft`, and `%steal`.

Warning signs:

- Low `%idle` with high `%usr`: application is CPU-bound.
- Low `%idle` with high `%sys`: kernel/system overhead.
- High `%iowait`: storage issue or blocked I/O.
- High `%steal`: noisy neighbor or undersized cloud instance.
- High `%soft`: possible network packet or driver pressure.

Manual commands:

```bash
mpstat -P ALL 3 1
sar -u 1 5
vmstat 1 5
```

Install on Ubuntu 24.04:

```bash
sudo apt-get update
sudo apt-get install -y sysstat
```

## Section: Sampled Process CPU Snapshot

Example:

```text
UID   TGID  TID  %usr  %system  %wait  %CPU  Command
1000   508   -   0.33     0.00   0.00  0.33  uvicorn
```

How to read it:

- `TGID` is the process ID.
- `TID` is the thread ID. A dash means the whole process row.
- `%usr` is user-space CPU.
- `%system` is kernel-space CPU.
- `%wait` means task wait time.
- `%CPU` is total CPU for that sample interval.

Healthy signs:

- Only small CPU consumers appear.
- The troubleshooting command itself may appear briefly, such as `pidstat`.

Warning signs:

- A process remains high across repeated samples.
- `%wait` is high, which can point to scheduling delay or resource contention.

Manual commands:

```bash
pidstat -u -t -r 3 1
pidstat -u -t -p <PID> 1
pidstat -r -p <PID> 1
```

## Section: CPU, I/O, And Memory Pressure

Example:

```text
CPU pressure:
some avg10=0.00 avg60=1.23 avg300=1.20 total=5359506
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
```

How to read it:

- `some` means at least one task was delayed.
- `full` means all non-idle tasks were delayed at the same time.
- `avg10`, `avg60`, and `avg300` show recent pressure over 10, 60, and 300 seconds.

Healthy signs:

- `avg10=0.00` during the issue window.
- `full` remains `0.00`.

Warning signs:

- CPU `some avg10` rises during a high CPU incident.
- I/O `some` or `full` rises while CPU looks idle.
- Memory pressure rises together with swapping or OOM logs.

Manual commands:

```bash
cat /proc/pressure/cpu
cat /proc/pressure/io
cat /proc/pressure/memory
watch -n 1 'cat /proc/pressure/cpu /proc/pressure/io /proc/pressure/memory'
```

## Section: Run Queue, Context Switches, And Kernel Clues

Example:

```text
r  b  swpd  free  si  so  in  cs  us  sy  id  wa  st
0  0     0     ... 0   0   86  84  0   0 100   0   0
```

How to read `vmstat`:

- `r`: runnable tasks waiting for CPU.
- `b`: blocked tasks, commonly waiting for I/O.
- `si` and `so`: swap in/out.
- `in`: interrupts per second.
- `cs`: context switches per second.
- `us`, `sy`, `id`, `wa`, `st`: user, system, idle, I/O wait, steal CPU.

Healthy signs:

- `r` is below or near CPU count.
- `b` is low.
- `id` is high.
- `wa` and `st` are low.

Warning signs:

- `r` is consistently higher than CPU count.
- `b` is high with high `wa`.
- `st` is high on a VM.
- Kernel messages show `soft lockup`, `hung task`, `RCU stall`, `OOM`, or throttling.

Manual commands:

```bash
vmstat 1 5
dmesg -T | grep -Ei 'cpu|soft lockup|hard lockup|thrott|oom|stall|hung|rcu' | tail -n 30
journalctl -k --since "30 min ago"
```

## Section: Interrupt Clues

Example from AWS:

```text
25: 4342 0 PCI-MSIX ... nvme0q1
28: 0 1203 PCI-MSIX ... ens5-Tx-Rx-0
```

How to read it:

- `nvme` entries relate to disk/storage.
- `ens5` or `ena` entries relate to AWS network interfaces.
- High interrupt movement over time can indicate disk, network, or driver pressure.

Healthy signs:

- Interrupts are spread normally and not growing rapidly during idle periods.

Warning signs:

- One IRQ line grows very fast.
- High `%soft` in `mpstat` appears with high network IRQ activity.
- High disk IRQ activity appears with high `%iowait`.

Manual commands:

```bash
cat /proc/interrupts
watch -n 1 cat /proc/interrupts
mpstat -P ALL 1
sar -n DEV 1 5
iostat -xz 1 5
```

## Section: Container And Cgroup Clues

Example:

```text
nr_periods 0
nr_throttled 0
throttled_usec 0
No common container marker found in /proc/1/cgroup.
```

How to read it:

- `nr_throttled` counts how often the cgroup was CPU-throttled.
- `throttled_usec` is total throttled time.
- Container markers show whether PID 1 appears to be running inside Docker, Kubernetes, containerd, or similar.

Healthy signs:

- `nr_throttled` and `throttled_usec` are `0` or not increasing.

Warning signs:

- `nr_throttled` increases while the app is slow.
- Host CPU looks idle but the container is throttled.
- Kubernetes pod has low CPU limits for the workload.

Manual commands:

```bash
cat /sys/fs/cgroup/cpu.stat
cat /proc/1/cgroup
systemd-cgls
systemd-cgtop
```

Kubernetes follow-up:

```bash
kubectl top pod -A
kubectl describe pod <pod_name> -n <namespace>
kubectl get pod <pod_name> -n <namespace> -o yaml
```

## Section: Service Clues

Example:

```text
system.slice/ai-sysadmin-mentor.service
nginx.service loaded active running
ssh.service loaded active running
```

How to read it:

- `systemd-cgtop` shows systemd control groups, task counts, memory, and CPU when available.
- `systemctl` shows running services that may own the suspicious process.

Healthy signs:

- Expected services are running.
- No service control group shows unexpected CPU usage.

Warning signs:

- A service related to the top process is using high CPU.
- A recently deployed service appears at the top.
- A service is repeatedly restarting.

Manual commands:

```bash
systemd-cgtop --raw --batch -n 1
systemctl --no-pager --type=service --state=running
systemctl status <service>
journalctl -u <service> --since "30 min ago"
```

## Manual High CPU Checklist

Use this when you do not have the script.

```bash
date
hostname
uname -srmo
nproc
uptime
cat /proc/loadavg
ps -eo pid,ppid,user,stat,ni,pri,pcpu,pmem,etime,comm,args --sort=-pcpu | head -20
ps -eLo pid,tid,ppid,user,stat,pcpu,pmem,comm --sort=-pcpu | head -20
mpstat -P ALL 3 1
pidstat -u -t -r 3 1
vmstat 1 5
cat /proc/pressure/cpu
cat /proc/pressure/io
cat /proc/pressure/memory
cat /sys/fs/cgroup/cpu.stat
cat /proc/interrupts
dmesg -T | grep -Ei 'cpu|soft lockup|hard lockup|thrott|oom|stall|hung|rcu' | tail -n 30
systemd-cgtop --raw --batch -n 1
systemctl --no-pager --type=service --state=running
```

## What To Say For This Ubuntu 24.04 Sample

Use this explanation in the video:

```text
This report is from an Ubuntu 24.04 server on AWS. The server has 2 CPU cores, and the 1-minute load average is only 0.09. The CPU snapshot shows 99.67 percent idle, so this is not an active high CPU incident.

The top process list shows normal background services like snapd, amazon-ssm-agent, systemd, and a uvicorn application, but none of them are consuming meaningful CPU. pidstat confirms uvicorn used only 0.33 percent during the sample.

The pressure section also supports this: CPU avg10 is 0.00, so tasks are not currently waiting for CPU. cgroup throttling is zero, which means this server is not being limited by cgroup CPU quotas.

So the conclusion is: at this exact time, the server is healthy from a CPU perspective. If users still report slowness, the next check should be application logs, network, database, storage latency, or capturing the report again during the actual incident window.
```

## Common Conclusions

Use these quick patterns:

- High load, low idle, high `%usr`: application CPU bottleneck.
- High load, low idle, high `%sys`: kernel/system overhead.
- High load, high `%iowait`: storage or blocked I/O issue.
- High load, high `%steal`: VM host contention or cloud instance pressure.
- Low host CPU, high cgroup throttling: container CPU limit issue.
- High `%soft` plus network IRQ growth: network packet processing issue.
- No high CPU in the report: capture again during the incident window.
