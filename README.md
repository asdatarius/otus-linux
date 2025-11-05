# otus-linux
Homeworks/snippets from OTUS Linux System Administration course.

## 🐳 Docker Migration (2025)

This repository has been **migrated from Vagrant to Docker** for better compatibility with modern systems, especially Apple Silicon Macs.

### Migration Status

| Homework | Docker | Status | Notes |
|----------|--------|--------|-------|
| **01-kernel** | ❌ | Vagrant only | Requires real kernel boot |
| **02-raid** | ✅ | Complete | Loop devices |
| **03-lvm** | ✅ | Complete | Loop devices, snapshots |
| **04-bash** | ✅ | Complete | systemd timers |
| **05-proc** | ✅ | Complete | Process exploration |
| **07-systemd** | ✅ | Complete | Services, timers, templates |
| **08-package_management** | ✅ | Complete | RPM building |

**Result**: 6/7 homeworks now use Docker (86% migration complete)

### Why Docker?

- **10-20x faster startup** (2-5s vs 30-60s)
- **Native Apple Silicon support** (no VirtualBox issues)
- **5x less RAM usage** (50MB-400MB vs 2GB per VM)
- **Cross-platform**: Works on macOS, Linux, Windows (WSL2)
- **Modern stack**: Rocky Linux 9 vs EOL CentOS 7

### Quick Start

Each homework now has a simple Docker workflow:

```bash
cd XX-homework
docker compose up -d
docker compose exec SERVICE bash
# Run homework commands
docker compose down
```

See individual homework READMEs for detailed instructions.
