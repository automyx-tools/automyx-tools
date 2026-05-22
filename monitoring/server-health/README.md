# Server Health Check

CSV health check tool for Linux servers and VMs.

This scenario belongs to the AutoMyx **Automation & Monitoring** playlist.

The script writes one CSV row per run, which makes it easy to schedule from cron and collect reports in S3 or on a centralized server.

## Files

| File | Purpose |
| --- | --- |
| [server-health-check.sh](server-health-check.sh) | CSV server/VM health check script |
| [OUTPUT-GUIDE.md](OUTPUT-GUIDE.md) | Explains CSV columns and interpretation |

## Run

```bash
chmod +x server-health-check.sh
./server-health-check.sh
```

Default output:

```text
./server-health.csv
```

Print to terminal:

```bash
./server-health-check.sh --stdout
```

Watch selected services:

```bash
./server-health-check.sh --services ssh,nginx
```

Upload to S3:

```bash
./server-health-check.sh --output /var/tmp/server-health.csv --s3 s3://my-bucket/server-health/
```

Upload to a central server:

```bash
./server-health-check.sh --output /var/tmp/server-health.csv --remote monitor@10.0.0.10:/data/reports/
```

## Cron Examples

Run every 5 minutes and keep a local CSV:

```cron
*/5 * * * * /opt/automyx/server-health-check.sh --services ssh,nginx --output /var/tmp/server-health.csv >/var/tmp/server-health.log 2>&1
```

Run every 15 minutes and upload to S3:

```cron
*/15 * * * * /opt/automyx/server-health-check.sh --services ssh,nginx --output /var/tmp/server-health.csv --s3 s3://my-bucket/server-health/ >/var/tmp/server-health.log 2>&1
```

## What It Checks

- Timestamp, hostname, primary IP, OS, kernel, uptime
- CPU cores and load averages
- Memory total, available, and used percentage
- Swap total and used percentage
- Root filesystem size GB, available GB, and used percentage
- Maximum filesystem size GB, available GB, used percentage, and mount
- Maximum inode usage and mount
- Zombie process count
- Runnable and total tasks
- Top CPU and memory process
- Failed systemd services
- Optional watched services
- Overall status: `OK` or `WARN`

## Safety

This tool is read-only apart from writing the CSV report and optionally uploading that report. It does not restart services, modify system configuration, install packages, or change monitoring settings.
