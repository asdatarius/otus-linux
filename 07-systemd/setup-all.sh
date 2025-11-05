#!/bin/bash
# Complete setup script for all three systemd homework exercises

set -e

echo "🔧 Setting up all systemd homework exercises..."
echo ""

# ============================================================================
# Exercise 1: Log Monitoring Service with Timer
# ============================================================================

echo "📋 Exercise 1: Log Monitoring Service"
echo "======================================"

# Create config
cat > /etc/sysconfig/asdatarius-watchlog <<EOF
# Configuration file for watchlog service
WORD="ALERT"
LOG_FILE="/var/log/asdatarius-watchlog.log"
EOF

# Create log file with test content
cat > /var/log/asdatarius-watchlog.log <<EOF
Some shitty log with AL3rTZ.
Every line could be complete fail.
Disaster.
alert!
EOF

# Create monitoring script
cat > /opt/asdatarius-watchlog.sh <<'EOF'
#!/bin/bash
WORD=$1
LOG_FILE=$2
DATE=$(date)

function usage {
    echo "usage: $0 STR_TO_FIND FULL_PATH_TO_LOG"
    exit 1
}

if [ -f "$LOG_FILE" ]; then
    if [ -z "$WORD" ]; then
        echo "Can't search for an empty substring."
        usage
    else
        if grep -i "$WORD" "$LOG_FILE" &> /dev/null
        then
            logger "$DATE: bingo bongo!"
        fi
        exit 0
    fi
else
    echo "The file '$LOG_FILE' does not exist."
    usage
fi
EOF

chmod +x /opt/asdatarius-watchlog.sh

# Create service
cat > /etc/systemd/system/asdatarius-watch.service <<EOF
[Unit]
Description="asdatarius watchlog service"

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/asdatarius-watchlog
ExecStart=/opt/asdatarius-watchlog.sh \$WORD \$LOG_FILE
EOF

# Create timer
cat > /etc/systemd/system/asdatarius-watch.timer <<EOF
[Unit]
Description="Run watchlog script every 30 seconds"
Requires=asdatarius-watch.service

[Timer]
OnUnitActiveSec=30s
AccuracySec=1s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable asdatarius-watch.timer
systemctl start asdatarius-watch.timer

echo "✅ Log monitoring service configured"
systemctl status asdatarius-watch.timer --no-pager | head -10
echo ""

# ============================================================================
# Exercise 2: spawn-fcgi Service
# ============================================================================

echo "📋 Exercise 2: spawn-fcgi Service"
echo "=================================="

# Create spawn-fcgi config
cat > /etc/sysconfig/spawn-fcgi <<EOF
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s \$SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
EOF

# Create spawn-fcgi service
cat > /etc/systemd/system/spawn-fcgi.service <<EOF
[Unit]
Description=Spawn-fcgi startup service
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n \$OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable spawn-fcgi.service
systemctl start spawn-fcgi.service

echo "✅ spawn-fcgi service configured"
systemctl status spawn-fcgi.service --no-pager | head -10
echo ""

# ============================================================================
# Exercise 3: httpd Template Service
# ============================================================================

echo "📋 Exercise 3: httpd Template Service"
echo "======================================"

# Create template service
cat > /etc/systemd/system/httpd@.service <<EOF
[Unit]
Description=The Apache HTTP Server (instance %I)
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd-%i
ExecStart=/usr/sbin/httpd \$OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd \$OPTIONS -k graceful
ExecStop=/bin/kill -WINCH \${MAINPID}
KillSignal=SIGCONT
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Create first instance config
cat > /etc/sysconfig/httpd-first <<EOF
OPTIONS=-f /etc/httpd/conf/first.conf
EOF

# Create second instance config
cat > /etc/sysconfig/httpd-second <<EOF
OPTIONS=-f /etc/httpd/conf/second.conf
EOF

# Copy base httpd config and modify for first instance
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
sed -i 's/^Listen 80/Listen 8081/' /etc/httpd/conf/first.conf
sed -i '/^#\?PidFile/c\PidFile \/var/run\/httpd-first.pid' /etc/httpd/conf/first.conf
echo 'ServerName localhost' >> /etc/httpd/conf/first.conf

# Copy base httpd config and modify for second instance
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf
sed -i 's/^Listen 80/Listen 8082/' /etc/httpd/conf/second.conf
sed -i '/^#\?PidFile/c\PidFile \/var/run\/httpd-second.pid' /etc/httpd/conf/second.conf
echo 'ServerName localhost' >> /etc/httpd/conf/second.conf

systemctl daemon-reload
systemctl enable httpd@first.service
systemctl enable httpd@second.service
systemctl start httpd@first.service
systemctl start httpd@second.service

echo "✅ httpd template service configured"
systemctl status httpd@first.service --no-pager | head -10
echo ""
systemctl status httpd@second.service --no-pager | head -10
echo ""

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "🎉 All exercises configured successfully!"
echo ""
echo "📊 Service Status Summary:"
echo "=========================="
echo "1. Log monitoring: $(systemctl is-active asdatarius-watch.timer)"
echo "2. spawn-fcgi:     $(systemctl is-active spawn-fcgi.service)"
echo "3. httpd@first:    $(systemctl is-active httpd@first.service)"
echo "4. httpd@second:   $(systemctl is-active httpd@second.service)"
echo ""
echo "🔍 Testing Commands:"
echo "==================="
echo "# Watch log monitoring in action:"
echo "  journalctl -u asdatarius-watch.service -f"
echo ""
echo "# Check spawn-fcgi processes:"
echo "  ps aux | grep php-cgi"
echo ""
echo "# Test httpd instances:"
echo "  curl http://localhost:8081"
echo "  curl http://localhost:8082"
echo ""
echo "  # From host machine:"
echo "  curl http://localhost:8081"
echo "  curl http://localhost:8082"
