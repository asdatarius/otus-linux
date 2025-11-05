#!/bin/bash
# Setup script to install and start the log-alert service

set -e

echo "🔧 Setting up log-alert service..."

# Create symlinks for systemd units
echo "📋 Installing systemd units..."
ln -sf /workspace/asdatarius-log-alert-docker.service /etc/systemd/system/asdatarius-log-alert.service
ln -sf /workspace/asdatarius-log-alert.timer /etc/systemd/system/asdatarius-log-alert.timer

# Create config directory and link config
echo "⚙️  Installing configuration..."
mkdir -p /etc/sysconfig
ln -sf /workspace/asdatarius-log-alert-docker /etc/sysconfig/asdatarius-log-alert-docker

# Reload systemd
echo "🔄 Reloading systemd..."
systemctl daemon-reload

# Start and enable the timer
echo "🚀 Starting timer..."
systemctl enable asdatarius-log-alert.timer
systemctl start asdatarius-log-alert.timer

# Show status
echo ""
echo "✅ Setup complete!"
echo ""
echo "📊 Timer status:"
systemctl status asdatarius-log-alert.timer --no-pager

echo ""
echo "📧 Email will be sent to: vagrant@localhost"
echo "📬 Check mail with: docker compose exec bash mail"
echo ""
echo "🔍 Monitor with:"
echo "  docker compose exec bash systemctl status asdatarius-log-alert.timer"
echo "  docker compose exec bash journalctl -u asdatarius-log-alert.service -f"
