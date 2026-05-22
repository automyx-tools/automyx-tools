# AutoMyx Tools

Practical troubleshooting and automation tools from AutoMyx for Linux, cloud, monitoring, root cause analysis, and production operations.

AutoMyx focuses on real IT problems, practical fixes, and clear evidence-based troubleshooting. The goal is to help engineers collect useful evidence quickly, understand what the output means, and decide the next safe action.

## About

This repository contains tools used in AutoMyx videos and technical runbooks.

Most tools here follow the same pattern:

1. Collect read-only system evidence.
2. Show the most likely investigation paths.
3. Provide manual commands for users who want to verify each step.
4. Avoid risky automatic changes unless clearly documented.

## Tools

| Area | Tool | Status | Description |
| --- | --- | --- | --- |
| Linux Troubleshooting | [Linux High CPU](linux/high-cpu/) | Available | First-pass Linux high CPU and high load triage |
| Linux Troubleshooting | [Linux Disk Full](linux/disk-full/) | Available | Disk full, inode, large files, deleted open files, and log growth triage |
| Linux Troubleshooting | [Linux High Memory](linux/high-memory/) | Available | Memory pressure, swap, OOM, RSS, and cgroup memory triage |
| Linux Troubleshooting | [Linux Service Down](linux/service-down/) | Available | systemd service down, failed, or restarting triage |
| Linux Troubleshooting | [Linux Slow SSH](linux/slow-ssh/) | Available | Slow SSH or server access issue triage |

## Repository Structure

```text
automyx-tools/
  README.md
  LICENSE
  linux/
    high-cpu/
      README.md
      highcpu-triage.sh
      OUTPUT-GUIDE.md
      VIDEO-01-linux-high-cpu.md
    disk-full/
      README.md
      disk-triage.sh
      OUTPUT-GUIDE.md
      VIDEO-02-linux-disk-full.md
    high-memory/
      README.md
      memory-triage.sh
      OUTPUT-GUIDE.md
      VIDEO-03-linux-high-memory.md
    service-down/
      README.md
      service-triage.sh
      OUTPUT-GUIDE.md
      VIDEO-04-linux-service-down.md
    slow-ssh/
      README.md
      ssh-triage.sh
      OUTPUT-GUIDE.md
      VIDEO-05-linux-slow-ssh.md
```

Each real-time scenario has its own folder. For example, the first Linux troubleshooting scenario is:

```text
linux/high-cpu/
```

## Quick Start

Clone the repository:

```bash
git clone https://github.com/automyx-tools/automyx-tools.git
cd automyx-tools
```

Run a tool:

```bash
cd linux/high-cpu
chmod +x highcpu-triage.sh
sudo ./highcpu-triage.sh
```

Save a report when supported:

```bash
sudo ./highcpu-triage.sh --output /tmp
```

## Documentation

Tool-specific documentation is inside each scenario folder.

For the Linux High CPU tool:

- [Linux High CPU Triage](linux/high-cpu/)
- [Linux High CPU Output Guide](linux/high-cpu/OUTPUT-GUIDE.md)

Other Linux troubleshooting folders:

- [Linux Disk Full](linux/disk-full/)
- [Linux High Memory](linux/high-memory/)
- [Linux Service Down](linux/service-down/)
- [Linux Slow SSH](linux/slow-ssh/)

## Recommended Dependencies

The tools are designed to work with standard Linux utilities when possible. Some tools may produce better reports when optional packages are installed.

For Linux CPU and performance tools, `sysstat` is recommended.

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y sysstat
```

RHEL/CentOS/Amazon Linux:

```bash
sudo yum install -y sysstat
```

## Safety

The tools in this repository are designed to be read-only unless clearly documented otherwise.

Before running any script on a production system:

- Read the script.
- Run it first in a test environment when possible.
- Save the output before taking action.
- Avoid sharing reports publicly if they contain hostnames, IP addresses, usernames, paths, service names, or customer data.

These tools do not replace operational judgment. They are meant to speed up evidence collection and guide the next investigation step.

## Roadmap

Future areas:

- AWS real-time issues
- Azure real-time issues
- Terraform IaC troubleshooting
- Root cause analysis runbooks
- Automation and monitoring helpers

## Contributing

Issues, suggestions, and practical troubleshooting scenarios are welcome.

Good contribution ideas:

- Bug reports with sanitized output
- New checks for existing tools
- Manual command improvements
- Documentation fixes
- Real-world troubleshooting patterns with sensitive data removed

## Contact

Website:

```text
https://www.automyx.tech
```

Email:

```text
contact@automyx.tech
```

YouTube:

```text
AutoMyx
```

## License

This project is licensed under the [MIT License](LICENSE).
