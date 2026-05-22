# Video 03: Linux High Memory Troubleshooting With AutoMyx

## Title Options

- Linux High Memory? Find The Process And OOM Clues
- Production Linux Memory Troubleshooting
- Linux OOM, Swap, And Memory Pressure Explained

## Thumbnail Text

Linux High Memory?
Find Root Cause

## Description

In this AutoMyx video, we troubleshoot Linux high memory using a read-only triage tool. We inspect memory summary, top RSS processes, swap, OOM logs, cgroup memory limits, pressure stall information, and slab memory.

Tool:

```text
https://github.com/automyx-tools/automyx-tools/tree/main/linux/high-memory
```

## Chapters

00:00 Intro
00:30 Problem statement
01:00 Run memory triage
02:00 Read free and meminfo
03:00 Find top RSS processes
04:00 Check swap and vmstat
05:00 OOM and cgroup clues
06:00 Safe next steps

## Demo Plan

```bash
chmod +x memory-triage.sh
sudo ./memory-triage.sh
```

## Pinned Comment

Have you seen more memory issues from applications, containers, or kernel cache?
