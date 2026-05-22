# Linux Slow SSH Triage

Read-only first-pass troubleshooting tool for slow SSH login, SSH connection failures, authentication delays, listener issues, DNS delays, and firewall clues.

This scenario belongs to the AutoMyx **Linux Troubleshooting** playlist.

## Files

| File | Purpose |
| --- | --- |
| [ssh-triage.sh](ssh-triage.sh) | Read-only Linux SSH triage script |
| [OUTPUT-GUIDE.md](OUTPUT-GUIDE.md) | Explains how to interpret the script output |
| [VIDEO-05-linux-slow-ssh.md](VIDEO-05-linux-slow-ssh.md) | Video title, description, chapters, script, and demo notes |

## Run

```bash
chmod +x ssh-triage.sh
sudo ./ssh-triage.sh
```

Save a report:

```bash
sudo ./ssh-triage.sh --lines 120 --output /tmp
```

## What It Checks

- ssh/sshd service status
- selected sshd configuration and effective settings
- listening SSH sockets
- firewall clues
- auth logs
- resolver and network clues
- basic CPU, memory, and disk resource clues

## Safety

This tool is read-only. It does not change `sshd_config`, firewall rules, DNS, routes, or service state.
