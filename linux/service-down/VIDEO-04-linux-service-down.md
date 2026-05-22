# Video 04: Linux Service Down Or Restarting With AutoMyx

## Title Options

- Linux Service Down? Troubleshoot systemd The Right Way
- systemd Service Failed Or Restarting? Find The Cause
- Production Linux Service Down Troubleshooting

## Thumbnail Text

Service Down?
Find Why

## Description

In this AutoMyx video, we troubleshoot a Linux systemd service that is down, failed, or restarting. We inspect service status, exit code, journal logs, ports, unit files, and resource clues using a read-only tool.

Tool:

```text
https://github.com/automyx-tools/automyx-tools/tree/main/linux/service-down
```

## Chapters

00:00 Intro
00:30 Problem statement
01:00 Run service triage
02:00 Read systemctl status
03:00 Check exit code and restart count
04:00 Read service logs
05:00 Check listening ports
06:00 Safe next steps

## Demo Plan

```bash
chmod +x service-triage.sh
sudo ./service-triage.sh --service nginx
```

## Pinned Comment

What service failure should AutoMyx demo next: nginx, ssh, docker, cron, or a custom app?
