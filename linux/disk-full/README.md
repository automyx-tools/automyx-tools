# Linux Disk Full Triage

Read-only first-pass troubleshooting tool for Linux disk full, inode full, log growth, package cache, container storage, and deleted-open-file issues.

This scenario belongs to the AutoMyx **Linux Troubleshooting** playlist.

## Files

| File | Purpose |
| --- | --- |
| [disk-triage.sh](disk-triage.sh) | Read-only Linux disk triage script |
| [OUTPUT-GUIDE.md](OUTPUT-GUIDE.md) | Explains how to interpret the script output |
| [VIDEO-02-linux-disk-full.md](VIDEO-02-linux-disk-full.md) | Video title, description, chapters, script, and demo notes |

## Run

```bash
chmod +x disk-triage.sh
sudo ./disk-triage.sh
```

Inspect a specific path:

```bash
sudo ./disk-triage.sh --path /var --top 20 --output /tmp
```

## What It Checks

- Filesystem capacity
- Inode usage
- Largest directories on one filesystem
- Largest files
- Deleted files still held open by processes
- journalctl disk usage
- Large log files
- Package cache size
- Docker/container storage clues

## Safety

This tool is read-only. It does not delete files, truncate logs, clean package cache, prune containers, or change mounts.
