# Linux Service Down Output Guide

Use this guide to interpret `service-triage.sh` output and run equivalent manual commands.

## Quick Read

Start with:

1. Is the service loaded?
2. Is `ActiveState` failed, inactive, activating, or running?
3. What are `Result` and `ExecMainStatus`?
4. Are logs showing config, permission, port, dependency, or resource errors?
5. Is the expected port listening?

## Service Overview

Manual commands:

```bash
systemctl status <service> -l
systemctl show <service> -p ActiveState -p SubState -p Result -p ExecMainStatus -p NRestarts -p MainPID
```

Warning signs:

- `LoadState=not-found`
- `ActiveState=failed`
- `Result=exit-code`
- `NRestarts` increasing

## Service Logs

Manual command:

```bash
journalctl -u <service> --since "30 min ago"
```

Common clues:

- Config syntax error
- Permission denied
- Address already in use
- Missing file/path
- Dependency unavailable

## Port Clues

Manual command:

```bash
ss -lntup
```

If the expected port is missing, the service may not have started correctly. If another process owns the port, inspect that process.

## Configuration Clues

Manual commands:

```bash
systemctl cat <service>
systemctl show <service> -p FragmentPath -p DropInPaths
```

Use this to find the actual unit file and overrides.

## Resource Clues

Manual commands:

```bash
uptime
free -h
df -hT
```

Services may fail if disk is full, memory is exhausted, or the system is overloaded.

## Common Conclusions

- Service failed with config error: validate config before restart.
- Port already in use: identify conflicting process.
- Restart loop: inspect logs and recent changes.
- Unit not found: package or unit file missing.
- Resource issue: fix disk/memory/CPU pressure first.
