# Video 01: Linux Server High CPU Troubleshooting With AutoMyx

## Title Options

- Linux Server High CPU? Find the Root Cause Fast
- Real-Time Linux High CPU Troubleshooting Using One Script
- Production Linux High CPU: Practical Root Cause Analysis

## Thumbnail Text

Linux High CPU?
Find Root Cause Fast

## Description

In this first AutoMyx video, we troubleshoot a Linux server high CPU issue using a simple read-only shell tool. We check load average, top processes, hot threads, CPU pressure, interrupts, cgroups, and service clues, then build a clear next-action plan.

Website: https://www.automyx.tech

Commands used:

```bash
chmod +x highcpu-triage.sh
sudo ./highcpu-triage.sh
sudo ./highcpu-triage.sh --top 15 --sample 5 --output /tmp
```

Output interpretation guide:

```text
See OUTPUT-GUIDE.md in this project for section-by-section interpretation and manual Linux commands.
```

## Tags

linux troubleshooting, high cpu linux, linux performance, production issue, devops, sre, system administration, root cause analysis, automation, automyx

## Chapters

00:00 Intro
00:25 Problem statement
00:55 What the tool checks
01:30 Run the high CPU triage script
02:20 Read load average and CPU cores
03:10 Find top CPU processes
04:00 Find hot threads
04:50 Check I/O wait, steal time, and pressure
05:40 Container and cgroup throttling clues
06:25 Recommended next actions
07:10 Wrap-up

## Recording Script

Hi everyone, welcome to AutoMyx. This channel is about real IT problems and practical fixes.

Today we are starting with a very common production issue: a Linux server is showing high CPU, the application is slow, and we need to find the root cause quickly.

Instead of guessing, I'll use a small read-only shell tool called `highcpu-triage.sh`. It does not restart anything, kill anything, or change server settings. It only collects evidence.

First, I'll make the script executable:

```bash
chmod +x highcpu-triage.sh
```

Now I'll run it with sudo:

```bash
sudo ./highcpu-triage.sh
```

The first section shows the host, kernel, CPU core count, load average, and runnable tasks. A quick rule is this: if the one-minute load average is higher than the number of CPU cores, the server may be under CPU pressure.

Next, we check the top processes by CPU. If one process is clearly using most of the CPU, that process becomes our first investigation target. We should check its logs, recent deployments, traffic changes, and workload.

Then we check top threads. This is important for Java, Python, database, and web server issues because sometimes one thread is hot inside a larger process.

If `mpstat` and `pidstat` are available from the `sysstat` package, the report becomes better. `mpstat` helps us see per-core CPU usage, I/O wait, and steal time. `pidstat` helps us sample process and thread CPU instead of trusting only a single instant from `ps`.

After that, the tool checks pressure stall information. If CPU pressure is high, tasks are waiting for CPU time. If I/O pressure is high, the problem may look like CPU but actually come from disk or storage wait.

For container workloads, the cgroup section is useful. If CPU throttling is high, the application may be hitting its CPU limit even when the host looks healthy.

At the end, the tool prints next commands. For example:

```bash
top -H -p <PID>
pidstat -u -t -p <PID> 1
journalctl -u <service> --since "30 min ago"
```

The important point is to capture evidence before taking action. In production, restarting a service may hide the root cause. Evidence first, action second.

That's it for this video. In the next videos, we'll take real examples and automate more Linux, AWS, Azure, Terraform, and monitoring troubleshooting.

This is AutoMyx: real IT problems, real fixes.

For this Ubuntu 24.04 sample, the server is healthy from a CPU perspective: 2 CPU cores, 0.09 load average, and 99.67 percent CPU idle. If users are still reporting slowness, capture the report again during the incident window and check application logs, database latency, network, or storage.

## Demo Plan

1. Open terminal on a Linux VM.
2. Show `uptime` and `nproc`.
3. Run `sudo ./highcpu-triage.sh`.
4. Explain the top three report sections.
5. Optional: create CPU load in another terminal for a visible demo:

```bash
yes > /dev/null &
```

6. Re-run the tool and show the `yes` process.
7. Clean up the demo process:

```bash
pkill yes
```

## Pinned Comment

Thanks for watching the first AutoMyx video. The tool is read-only and designed for first-pass Linux high CPU triage. What production issue should I automate next: memory, disk full, slow SSH, or Kubernetes pod crash?
