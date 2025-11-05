# 07-systemd: Service Management

This homework demonstrates three systemd concepts:
1. Log monitoring service with timer (similar to 04-bash)
2. Converting init scripts to systemd units (spawn-fcgi)
3. Using systemd templates for multi-instance services (httpd)

## Quick Start (Docker)

```bash
# Start container with systemd
docker compose up -d

# Run complete setup for all three exercises
docker compose exec systemd /workspace/setup-all.sh

# Test results
docker compose exec systemd journalctl -u asdatarius-watch.service -f
docker compose exec systemd systemctl status spawn-fcgi
docker compose exec systemd systemctl status httpd@first
curl http://localhost:8081
curl http://localhost:8082
```

## What's Included

### Exercise 1: Log Monitoring (Timer + Service)
- Watches `/var/log/asdatarius-watchlog.log` for "ALERT" keyword
- Runs every 30 seconds via systemd timer
- Logs to syslog when match found

### Exercise 2: spawn-fcgi Service
- Converts legacy init script to systemd unit
- Manages PHP FastCGI processes
- Type=simple with PID file

### Exercise 3: httpd Template (@)
- Single service template: `httpd@.service`
- Multiple instances: `httpd@first`, `httpd@second`
- Different ports: 8081, 8082
- Separate configs and PID files

## Manual Setup (Step by Step)

See `README_VAGRANT.md` for detailed manual instructions for each exercise.

## Testing

```bash
# Exercise 1: Watch log monitoring
docker compose exec systemd journalctl -u asdatarius-watch.service -f
docker compose exec systemd systemctl list-timers

# Exercise 2: Check spawn-fcgi
docker compose exec systemd systemctl status spawn-fcgi
docker compose exec systemd ps aux | grep php-cgi

# Exercise 3: Test httpd instances
curl http://localhost:8081
curl http://localhost:8082
docker compose exec systemd systemctl status 'httpd@*'
```

## Key systemd Concepts

**Timer Units**: Schedule service execution
```ini
[Timer]
OnUnitActiveSec=30s
```

**Environment Files**: External configuration
```ini
[Service]
EnvironmentFile=/etc/sysconfig/myservice
```

**Template Units**: Single unit, multiple instances
```ini
# httpd@.service
[Service]
EnvironmentFile=/etc/sysconfig/httpd-%i
```

## Troubleshooting

```bash
# View all services
docker compose exec systemd systemctl list-units --type=service

# Check specific service
docker compose exec systemd systemctl status SERVICE_NAME

# View logs
docker compose exec systemd journalctl -u SERVICE_NAME

# Reload after changes
docker compose exec systemd systemctl daemon-reload
```

## References

- See `README_VAGRANT.md` for complete original documentation
- systemd documentation: https://www.freedesktop.org/software/systemd/man/
- Manual PDFs in `manual/` directory
