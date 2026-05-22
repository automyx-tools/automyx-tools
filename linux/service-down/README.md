# Linux Service Down Triage

Read-only first-pass troubleshooting tool for systemd services that are down, failed, restarting, or not listening on the expected port.

This scenario belongs to the AutoMyx **Linux Troubleshooting** playlist.

## Files

| File | Purpose |
| --- | --- |
| [service-triage.sh](service-triage.sh) | Read-only Linux service triage script |
| [OUTPUT-GUIDE.md](OUTPUT-GUIDE.md) | Explains how to interpret the script output |
| [VIDEO-04-linux-service-down.md](VIDEO-04-linux-service-down.md) | Video title, description, chapters, script, and demo notes |

## Run

```bash
chmod +x service-triage.sh
sudo ./service-triage.sh --service nginx
```

Save a report:

```bash
sudo ./service-triage.sh --service nginx --lines 120 --output /tmp
```

## What It Checks

- systemd service status
- service properties such as state, result, exit code, restart count, and MainPID
- recent journal logs
- listening ports
- unit file and drop-in paths
- basic CPU, memory, and disk resource clues

## Safety

This tool is read-only. It does not start, stop, restart, enable, disable, or reload services.
