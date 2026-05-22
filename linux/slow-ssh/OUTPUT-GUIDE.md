# Linux Slow SSH Output Guide

Use this guide to interpret `ssh-triage.sh` output and run equivalent manual commands.

## Quick Read

Start with:

1. Is ssh/sshd active?
2. Is the expected port listening?
3. Are auth logs showing failures or delays?
4. Are DNS or GSSAPI settings causing login delay?
5. Are firewall or cloud security rules blocking access?

## SSH Service Status

Manual command:

```bash
systemctl status ssh -l
systemctl status sshd -l
```

Warning signs:

- Service inactive or failed.
- Repeated restart attempts.
- Config or key load errors.

## sshd Configuration

Manual commands:

```bash
grep -Ei 'Port|UseDNS|GSSAPIAuthentication|PasswordAuthentication|PubkeyAuthentication' /etc/ssh/sshd_config
sshd -T
```

Common slow login causes:

- Reverse DNS lookup delay
- GSSAPI delay
- PAM/module delay
- overloaded system

## Port And Firewall

Manual commands:

```bash
ss -lntup | grep ssh
ufw status verbose
iptables -S
```

For cloud servers, also check security groups, NACLs, and route tables.

## Auth Logs

Manual commands:

```bash
journalctl -u ssh --since "30 min ago"
tail -n 100 /var/log/auth.log
tail -n 100 /var/log/secure
```

Common clues:

- Failed password
- Invalid user
- Permission denied
- Authentication refused
- PAM delay

## DNS And Network

Manual commands:

```bash
cat /etc/resolv.conf
grep '^hosts:' /etc/nsswitch.conf
ip route
ip -brief addr
```

## Common Conclusions

- No SSH listener: inspect service and config.
- Auth failure: inspect keys, account, and permissions.
- Login delay: check DNS, GSSAPI, PAM, and system load.
- Connection timeout: check firewall, security groups, routing, and listener.
- Connection refused: service not listening or port mismatch.
