# Video 05: Linux Slow SSH Troubleshooting With AutoMyx

## Title Options

- Linux SSH Slow Or Failing? Troubleshoot It Fast
- Slow SSH Login On Linux? Check These First
- Production SSH Access Issue Troubleshooting

## Thumbnail Text

Slow SSH?
Find The Delay

## Description

In this AutoMyx video, we troubleshoot slow SSH login and SSH access issues using a read-only tool. We inspect ssh service status, sshd config, listening ports, firewall clues, auth logs, DNS, routes, and system resources.

Tool:

```text
https://github.com/automyx-tools/automyx-tools/tree/main/linux/slow-ssh
```

## Chapters

00:00 Intro
00:30 Problem statement
01:00 Run SSH triage
02:00 Check service status
03:00 Check sshd config
04:00 Check ports and firewall
05:00 Auth logs and DNS
06:00 Safe next steps

## Demo Plan

```bash
chmod +x ssh-triage.sh
sudo ./ssh-triage.sh
```

## Pinned Comment

Was your SSH issue caused by DNS, firewall, keys, or server load?
