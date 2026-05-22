# Video 02: Linux Disk Full Troubleshooting With AutoMyx

## Title Options

- Linux Disk Full? Find What Is Using Space Fast
- Production Linux Disk Full Troubleshooting
- Linux Disk Full, Inode Full, Or Deleted Files? Start Here

## Thumbnail Text

Linux Disk Full?
Find It Fast

## Description

In this AutoMyx video, we troubleshoot a Linux disk full issue using a read-only shell tool. We check filesystem usage, inode usage, largest directories, largest files, deleted open files, logs, package cache, and container storage clues.

Tool:

```text
https://github.com/automyx-tools/automyx-tools/tree/main/linux/disk-full
```

## Chapters

00:00 Intro
00:30 Problem statement
01:00 Run disk triage
02:00 Check filesystem usage
03:00 Check inode usage
04:00 Find large directories and files
05:00 Deleted open files
06:00 Logs and container storage
07:00 Safe next steps

## Demo Plan

```bash
chmod +x disk-triage.sh
sudo ./disk-triage.sh --path /var
```

## Pinned Comment

What should AutoMyx automate next: memory pressure, service restart loops, slow SSH, or cloud networking?
