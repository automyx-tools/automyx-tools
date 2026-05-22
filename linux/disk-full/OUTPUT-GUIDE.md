# Linux Disk Full Output Guide

Use this guide to interpret `disk-triage.sh` output and run equivalent manual commands.

## Quick Read

Start with these questions:

1. Is filesystem `Use%` high?
2. Is inode `IUse%` high?
3. Which top-level directory is growing?
4. Are deleted files still held open?
5. Are logs, package cache, or container storage responsible?

## Filesystem Usage

Manual command:

```bash
df -hT
df -hT /var
```

Warning signs:

- `Use%` above 85 percent: investigate.
- `Use%` above 95 percent: urgent.
- `/`, `/var`, `/tmp`, or application data mounts are full.

## Inode Usage

Manual command:

```bash
df -ih
```

Warning signs:

- `IUse%` is high while disk space looks available.
- Many small files are present, often in cache, sessions, mail, or temp directories.

Follow-up:

```bash
find /var -xdev -type f | awk -F/ '{print "/"$2"/"$3}' | sort | uniq -c | sort -nr | head
```

## Largest Directories

Manual command:

```bash
du -xhd1 /var | sort -hr | head
```

Use `-x` to stay on the same filesystem.

## Largest Files

Manual command:

```bash
find /var -xdev -type f -size +100M -ls
```

Warning signs:

- Huge logs without rotation.
- Large application dumps.
- Unexpected archives or backup files.

## Deleted Open Files

Manual command:

```bash
lsof +L1
```

If a deleted file is still open, disk space is not released until the process closes the file. Restart the owning service only after impact review.

## Log Clues

Manual commands:

```bash
journalctl --disk-usage
du -sh /var/log/*
```

Common causes:

- No log rotation.
- Verbose debug logging.
- Repeating service errors.

## Container Storage

Manual command:

```bash
docker system df
du -sh /var/lib/docker /var/lib/containerd
```

Warning signs:

- Unused images and old containers.
- Large JSON container logs.
- Volumes growing unexpectedly.

## Common Conclusions

- Disk full with large `/var/log`: inspect noisy service and log rotation.
- Disk full with large deleted file: restart owning process after approval.
- Inode full: find directory with many small files.
- Container storage large: inspect Docker images, containers, logs, and volumes.
