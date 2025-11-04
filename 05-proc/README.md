# 05-proc: Process Filesystem Exploration

This homework demonstrates how to recreate common process inspection tools (`ps` and `lsof`) by reading directly from the `/proc` filesystem.

## Learning Objectives

- Understand the `/proc` filesystem structure
- Learn how to extract process information from `/proc/[pid]/` entries
- Recreate `ps ax` functionality by parsing `/proc/[pid]/stat`, `/proc/[pid]/cmdline`, etc.
- Recreate `lsof` functionality by reading file descriptors from `/proc/[pid]/fd/`

## Scripts

1. **`asdatarius_ps_ax.sh`** - Recreates `ps ax` command output
   - Shows PID, TTY, STATUS, TIME, and COMMAND
   - Reads from `/proc/[pid]/stat`, `/proc/[pid]/cmdline`, `/proc/[pid]/fd/0`

2. **`asdatarius_lsof.sh`** - Recreates `lsof` command output
   - Shows COMMAND, PID, USER, FD, TYPE, DEVICE, SIZE/OFF, NODE, and NAME
   - Displays open files, directories, sockets, pipes, and memory-mapped files
   - Reads from `/proc/[pid]/fd/`, `/proc/[pid]/maps`, `/proc/[pid]/exe`, etc.

## Prerequisites

### Option 1: Docker (Recommended for 2025+)
- Docker Desktop 4.0+ (macOS/Windows) or Docker Engine 20.10+ (Linux)
- Docker Compose v2+
- **Works on**: macOS (Intel/ARM), Linux, Windows with WSL2

### Option 2: Vagrant (Legacy)
- VirtualBox 6.1+
- Vagrant 2.2+
- ⚠️ **Limited support on Apple Silicon Macs**

## Quick Start

### Using Docker (Recommended)

```bash
# Build and start the container
docker-compose up -d

# Enter the container
docker-compose exec proc bash

# Inside the container, run the scripts:
./asdatarius_ps_ax.sh
./asdatarius_lsof.sh

# Compare with real commands:
ps ax
lsof | head -50

# Exit container
exit

# Stop and remove container
docker-compose down
```

**One-liner for quick testing:**
```bash
docker-compose up -d && docker-compose exec proc bash
```

### Using Vagrant (Legacy)

```bash
# Start the VM
vagrant up

# SSH into the VM
vagrant ssh

# Run the scripts
cd /vagrant
./asdatarius_ps_ax.sh
./asdatarius_lsof.sh

# Exit VM
exit

# Destroy the VM
vagrant destroy -f
```

## Running the Scripts

### Test `ps ax` Recreation

```bash
# Run our custom implementation
./asdatarius_ps_ax.sh

# Compare with the real ps command
ps ax
```

**Expected output format:**
```
PID     TTY             STATUS      TIME    CMD
1       /dev/console    S           0       /usr/lib/systemd/systemd
2       ?               S           0       [kthreadd]
...
```

### Test `lsof` Recreation

```bash
# Run our custom implementation
./asdatarius_lsof.sh

# Compare with the real lsof command
lsof | head -100
```

**Expected output format:**
```
COMMAND         PID     USER       FD    TYPE     DEVICE     SIZE/OFF   NODE     NAME
systemd         1       root       cwd   DIR      0,0        4096       2        /
systemd         1       root       rtd   DIR      0,0        4096       2        /
systemd         1       root       txt   REG      0,0        1624520    12345    /usr/lib/systemd/systemd
systemd         1       root       0u    CHR      1,3        0          6        /dev/null
...
```

## Understanding the Code

### `asdatarius_ps_ax.sh` Key Concepts

The script reads process information from:
- `/proc/[pid]/stat` - Process status (state, CPU time, etc.)
- `/proc/[pid]/cmdline` - Full command line (null-separated)
- `/proc/[pid]/fd/0` - Standard input (to determine TTY)

```bash
# Get process state (3rd field in /proc/[pid]/stat)
stat=$(awk '{print $3}' /proc/$pid/stat)

# Get command line (replace null bytes with spaces)
cmdline=$(cat /proc/$pid/cmdline | tr "\0" " ")
```

### `asdatarius_lsof.sh` Key Concepts

The script reads file information from:
- `/proc/[pid]/fd/` - Directory of open file descriptors
- `/proc/[pid]/cwd` - Symlink to current working directory
- `/proc/[pid]/exe` - Symlink to executable
- `/proc/[pid]/maps` - Memory-mapped files
- `/proc/[pid]/status` - Process status including UID

```bash
# Read file descriptor target
fd_target=$(readlink -f /proc/$pid/fd/$fd_num)

# Get file type
if [ -f "$fd_target" ]; then
    ftype="REG"
elif [ -d "$fd_target" ]; then
    ftype="DIR"
elif [ -c "$fd_target" ]; then
    ftype="CHR"
fi

# Get file metadata (device, size, inode)
stat_info=$(stat -c "%t,%T %s %i" "$fd_target")
```

## Implementation Notes

### Differences from Real Commands

1. **Output Formatting**: Our scripts use simpler formatting
2. **Limited Output**: `lsof` output is limited to 100 lines to avoid overwhelming the terminal
3. **Socket Details**: Real `lsof` shows detailed socket information (addresses, ports), ours shows basic info
4. **Performance**: Real commands are optimized C code, ours are bash scripts

### Educational Value

These scripts demonstrate:
- How process information is stored in the kernel
- The structure and purpose of the `/proc` filesystem
- How system tools like `ps` and `lsof` work under the hood
- Bash scripting techniques for parsing system data

## Troubleshooting

### Docker Issues

**Container won't start:**
```bash
# Check container logs
docker-compose logs

# Rebuild from scratch
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

**Permission denied on scripts:**
```bash
# Make scripts executable
chmod +x asdatarius_ps_ax.sh asdatarius_lsof.sh
```

**Can't see processes:**
The container uses `pid: host` mode to access host processes for demonstration purposes. If you want to see only container processes, remove this line from `docker-compose.yml`.

### Vagrant Issues

**VM won't start:**
```bash
# Check VirtualBox is installed
VBoxManage --version

# Check Vagrant status
vagrant status

# Try destroying and recreating
vagrant destroy -f
vagrant up
```

**Script errors inside VM:**
```bash
# Ensure you're in the right directory
cd /vagrant

# Check script permissions
ls -la *.sh

# Make executable if needed
chmod +x *.sh
```

## Performance Comparison

| Environment | Startup Time | RAM Usage | Notes |
|-------------|--------------|-----------|-------|
| Docker      | ~2-5 seconds | ~50MB     | Native macOS support |
| Vagrant     | ~30-60 seconds | ~2GB    | Full VM overhead |

## Next Steps

After completing this homework, you can:
1. Extend the scripts to show more information (network connections, environment variables)
2. Add filtering options (by user, by process name, etc.)
3. Improve output formatting to match real commands exactly
4. Explore other `/proc` entries (`/proc/meminfo`, `/proc/cpuinfo`, etc.)
5. Try writing similar scripts for other system tools (`netstat`, `top`, etc.)

## References

- [Linux `/proc` filesystem documentation](https://www.kernel.org/doc/Documentation/filesystems/proc.txt)
- [proc(5) man page](https://man7.org/linux/man-pages/man5/proc.5.html)
- [ps(1) man page](https://man7.org/linux/man-pages/man1/ps.1.html)
- [lsof(8) man page](https://man7.org/linux/man-pages/man8/lsof.8.html)
