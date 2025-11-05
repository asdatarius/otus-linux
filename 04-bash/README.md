# 04-bash: Log Monitoring with systemd Timer

This homework demonstrates how to create a log monitoring system using bash scripting and systemd timers.

## Learning Objectives

- Parse and analyze web server access logs
- Track log file changes incrementally (avoid reprocessing)
- Extract statistics (top IPs, URIs, error codes)
- Send email alerts with monitoring results
- Create and manage systemd services and timers
- Use systemd for scheduled tasks

## What It Does

The `asdatarius-log-alert.sh` script:
1. Monitors an Apache/nginx access log file
2. Tracks the last processed position (incremental processing)
3. Analyzes new log entries for:
   - **Top 10 IP addresses** by request count
   - **Top 10 URIs** by request count
   - **Error codes** (4xx and 5xx responses)
   - **Successful responses** (2xx and 3xx codes)
4. Sends email report via `sendmail`
5. Runs every 30 seconds via systemd timer

## Prerequisites

### Option 1: Docker (Recommended for 2025+)
- Docker Desktop 4.0+ (macOS/Windows) or Docker Engine 20.10+ (Linux)
- Docker Compose v2+
- **Works on**: macOS (Intel/ARM), Linux, Windows with WSL2

### Option 2: Vagrant (Legacy)
- VirtualBox 6.1+
- Vagrant 2.2+
- ⚠️ **Limited support on Apple Silicon Macs**

## Quick Start (Docker)

```bash
# Start the container with systemd
docker compose up -d

# Run setup script to install and start the service
docker compose exec bash /workspace/setup-service.sh

# Check timer status
docker compose exec bash systemctl status asdatarius-log-alert.timer

# Watch service executions in real-time
docker compose exec bash journalctl -u asdatarius-log-alert.service -f

# Check email (mail sent to vagrant@localhost)
docker compose exec bash mail

# Stop everything
docker compose down
```

## Detailed Usage

### 1. Start the Environment

```bash
docker compose up -d
```

This starts a Rocky Linux 9 container with systemd running.

### 2. Setup the Service

```bash
docker compose exec bash /workspace/setup-service.sh
```

This script:
- Installs systemd unit files
- Creates configuration symlinks
- Enables and starts the timer
- Shows initial status

### 3. Monitor Service Activity

**Check timer status:**
```bash
docker compose exec bash systemctl status asdatarius-log-alert.timer
```

**View service logs:**
```bash
docker compose exec bash journalctl -u asdatarius-log-alert.service
```

**Watch in real-time:**
```bash
docker compose exec bash journalctl -u asdatarius-log-alert.service -f
```

**List timer schedule:**
```bash
docker compose exec bash systemctl list-timers
```

### 4. Check Email Reports

```bash
# Launch mail client
docker compose exec bash mail

# Read messages
? 1
? 2
? q  # quit
```

### 5. Manual Testing

```bash
# Run service manually (one-shot)
docker compose exec bash systemctl start asdatarius-log-alert.service

# Check if email was sent
docker compose exec bash mail
```

### 6. Modify Log File

To test incremental processing:

```bash
# Add lines to the log file
docker compose exec bash bash -c 'echo "192.168.1.100 - - [05/Nov/2025:12:00:00 +0000] \"GET /test HTTP/1.1\" 200 1234" >> /workspace/access-4560-644067.log'

# Wait 30 seconds for timer to fire
# Check new email with updated stats
docker compose exec bash mail
```

## Understanding the Components

### 1. Log Monitoring Script (`asdatarius-log-alert.sh`)

```bash
#!/bin/bash

PATH_TO_LOGFILE=$1
PATH_TO_LOCKFILE=/tmp/asdatarius-log-alert.lock
PATH_TO_PROGRESS_STORAGE=/tmp/asdatarius-log-alert.progress
ALERT_EMAIL="vagrant@localhost"

# Lock file prevents concurrent execution
if ( set -o noclobber; echo "$$" > "$PATH_TO_LOCKFILE") 2> /dev/null; then
    # Track file size to process only new entries
    SIZE=$(stat --printf="%s" "${PATH_TO_LOGFILE}")
    PREV_SIZE=$(cat ${PATH_TO_PROGRESS_STORAGE} 2>/dev/null || echo 0)

    # Process new lines since PREV_SIZE
    # Extract IPs, URIs, error codes
    # Send email report
fi
```

**Key Features:**
- **Lock file**: Prevents overlapping executions
- **Progress tracking**: Stores last processed byte position
- **Log rotation handling**: Resets if file shrinks
- **Incremental processing**: Only analyzes new entries

### 2. systemd Service Unit (`asdatarius-log-alert.service`)

```ini
[Unit]
Description="asdatarius log-alert service"

[Service]
Type=oneshot
EnvironmentFile=/workspace/asdatarius-log-alert-docker
ExecStart=/workspace/asdatarius-log-alert.sh ${PATH_TO_LOGFILE}
```

**Type=oneshot**: Runs once per invocation (perfect for timers)

### 3. systemd Timer Unit (`asdatarius-log-alert.timer`)

```ini
[Unit]
Description="Run log-alert script every 30 second"
Requires=asdatarius-log-alert.service

[Timer]
OnUnitActiveSec=30s  # Run every 30 seconds
AccuracySec=1s       # High precision

[Install]
WantedBy=multi-user.target
```

**OnUnitActiveSec**: Runs 30s after previous activation

### 4. Configuration File (`asdatarius-log-alert-docker`)

```bash
PATH_TO_LOGFILE=/workspace/access-4560-644067.log
```

## Email Report Format

```
To: vagrant@localhost
From: systemd <root@asdatarius-bash>
Subject: asdatarius-log-alert.service [05/Nov/2025:12:00:00-[05/Nov/2025:12:30:00

LOG:
/workspace/access-4560-644067.log:12345-EOF

IP TOP:
    150 192.168.1.100
    120 10.0.0.50
    ...

URI TOP:
    200 /index.html
    150 /api/users
    ...

ERRORS:
     50 404
     20 500
     ...

REQUESTS:
   1000 200
    500 301
    ...
```

## Log Format Support

The script expects Apache/nginx Combined Log Format:

```
192.168.1.100 - - [05/Nov/2025:12:00:00 +0000] "GET /index.html HTTP/1.1" 200 1234 "-" "Mozilla/5.0"
```

Fields extracted:
- `$1`: IP address
- `$4`: Timestamp (start)
- `"$2"`: Request method, URI, protocol (within quotes)
- 3rd field after quotes: Status code

## Troubleshooting

### Service Not Running

```bash
# Check service status
docker compose exec bash systemctl status asdatarius-log-alert.service

# Check timer status
docker compose exec bash systemctl status asdatarius-log-alert.timer

# View errors
docker compose exec bash journalctl -u asdatarius-log-alert.service -n 50
```

### No Emails Received

```bash
# Check if sendmail is working
docker compose exec bash which sendmail

# Check mail spool
docker compose exec bash ls -la /var/mail/

# Test sendmail manually
docker compose exec bash bash -c 'echo "Test" | mail -s "Test Subject" vagrant@localhost'
docker compose exec bash mail
```

### Timer Not Firing

```bash
# Check timer is enabled
docker compose exec bash systemctl is-enabled asdatarius-log-alert.timer

# Start it manually
docker compose exec bash systemctl start asdatarius-log-alert.timer

# List all timers
docker compose exec bash systemctl list-timers --all
```

### Script Errors

```bash
# Run script manually with debug output
docker compose exec bash bash -x /workspace/asdatarius-log-alert.sh /workspace/access-4560-644067.log

# Check lock file
docker compose exec bash ls -la /tmp/asdatarius-log-alert.lock

# Check progress file
docker compose exec bash cat /tmp/asdatarius-log-alert.progress
```

## Customization

### Change Timer Interval

Edit `asdatarius-log-alert.timer`:
```ini
[Timer]
OnUnitActiveSec=60s  # Changed to 60 seconds
```

Then reload:
```bash
docker compose exec bash systemctl daemon-reload
docker compose exec bash systemctl restart asdatarius-log-alert.timer
```

### Change Email Recipient

Edit `asdatarius-log-alert.sh`:
```bash
ALERT_EMAIL="your-email@example.com"
```

### Monitor Different Log File

Edit `asdatarius-log-alert-docker`:
```bash
PATH_TO_LOGFILE=/var/log/nginx/access.log
```

## Advanced Topics

### systemd Timer vs Cron

**systemd Timers advantages:**
- Better integration with systemd
- Dependency management (Requires=)
- Can trigger on events (not just time)
- Better logging via journalctl
- Resource control (CPU, memory limits)

**Cron advantages:**
- Simpler syntax
- More widely known
- Works without systemd

### Understanding systemd Timer Types

```ini
# Runs at specific time
OnCalendar=*-*-* 12:00:00

# Runs X seconds after boot
OnBootSec=5min

# Runs X seconds after service activation
OnUnitActiveSec=30s

# Runs X seconds after last successful completion
OnUnitInactiveSec=1h
```

### Resource Limits

Add to service file:
```ini
[Service]
CPUQuota=20%
MemoryLimit=100M
```

## Performance Comparison

| Environment | Startup Time | RAM Usage | systemd Support |
|-------------|--------------|-----------|-----------------|
| Docker      | 2-5 seconds  | 200-400MB | Full            |
| Vagrant     | 30-60 seconds| 2GB       | Full            |

## Next Steps

After completing this homework:
1. Add more statistics (user agents, response sizes, request duration)
2. Create multiple timers with different schedules
3. Add alert thresholds (send only if errors > X)
4. Integrate with external monitoring (Prometheus, Grafana)
5. Process multiple log files
6. Add log rotation detection and handling

## References

- [systemd.timer man page](https://www.freedesktop.org/software/systemd/man/systemd.timer.html)
- [systemd.service man page](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Apache Log Format](https://httpd.apache.org/docs/current/logs.html#combined)
- [awk Tutorial](https://www.gnu.org/software/gawk/manual/gawk.html)

---

## Legacy Vagrant Instructions

The original `README.md` contains Vagrant-specific setup. The Docker approach is functionally identical but with faster startup and better cross-platform support.
