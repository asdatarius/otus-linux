# 02-raid: RAID Configuration

This homework demonstrates Software RAID configuration using mdadm.

## Learning Objectives

- Create RAID arrays (RAID 10)
- Manage Software RAID with mdadm
- Partition RAID devices
- Create filesystems on RAID partitions

## Quick Start (Docker)

```bash
# Start container
docker compose up -d

# Setup RAID 10
docker compose exec raid /workspace/setup-raid.sh

# Test
docker compose exec raid bash
echo 'test data' > /raid/part1/testfile
cat /raid/part1/testfile
cat /proc/mdstat
mdadm --detail /dev/md0
```

## What It Does

The `setup-raid.sh` script:
1. Creates 4 × 250MB sparse files (simulated disks)
2. Attaches them as loop devices
3. Creates RAID 10 array with `mdadm`
4. Partitions the array (4 partitions, 25% each)
5. Formats with XFS
6. Mounts to `/raid/part{1,2,3,4}`

## RAID 10 Overview

RAID 10 (1+0) combines mirroring and striping:
- **Striping**: Data split across disks (performance)
- **Mirroring**: Data duplicated (redundancy)
- **Capacity**: 50% of total (4×250MB = 500MB usable)
- **Fault tolerance**: Can lose 1 disk per mirror pair

```
┌─────────┬─────────┐
│  Disk1  │  Disk2  │  Mirror Pair 1
│ (Loop1) │ (Loop2) │
├─────────┼─────────┤
│  Disk3  │  Disk4  │  Mirror Pair 2
│ (Loop3) │ (Loop4) │
└─────────┴─────────┘
     ↓         ↓
   Striped Data
```

## Manual Setup

See `README_VAGRANT.md` for step-by-step instructions.

## Testing

```bash
# Check RAID status
cat /proc/mdstat
mdadm --detail /dev/md0

# Check filesystem
df -h | grep /raid
mount | grep /raid

# Write test data
for i in {1..4}; do
    echo "Test data in partition $i" > /raid/part$i/test.txt
done

# Read test data
for i in {1..4}; do
    cat /raid/part$i/test.txt
done

# Check partition info
parted /dev/md0 print
```

## Simulating Disk Failure

```bash
# Fail a disk
mdadm --manage /dev/md0 --fail /dev/loop1

# Check degraded state
cat /proc/mdstat
mdadm --detail /dev/md0

# Remove failed disk
mdadm --manage /dev/md0 --remove /dev/loop1

# Add replacement disk (would need new loop device)
# mdadm --manage /dev/md0 --add /dev/loopX
```

## Key Commands

```bash
# Create array
mdadm --create /dev/md0 -l 10 -n 4 /dev/sd{b,c,d,e}

# Check status
cat /proc/mdstat
mdadm --detail /dev/md0

# Save config
mdadm --detail --scan >> /etc/mdadm/mdadm.conf

# Stop array
mdadm --stop /dev/md0

# Assemble array
mdadm --assemble /dev/md0

# Zero superblock (cleanup)
mdadm --zero-superblock /dev/sdX
```

## Troubleshooting

```bash
# Array won't start
losetup -a  # Check loop devices exist
mdadm --assemble --scan  # Try auto-assembly

# Can't create array
mdadm --zero-superblock --force /dev/loop*  # Clear old metadata

# Permission denied
# Container must run in privileged mode (required for loop devices)
```

## Limitations (Docker vs VM)

✅ **Works the same**:
- RAID creation and management
- Partitioning
- Filesystem operations
- Failure simulation

⚠️ **Differences**:
- Uses loop devices instead of real block devices
- Requires privileged container
- Loop devices shared with host (cleanup needed)

## Cleanup

```bash
# Inside container
umount /raid/part*
mdadm --stop /dev/md0
losetup -D  # Detach all loop devices

# From host
docker compose down
```

## References

- [mdadm man page](https://linux.die.net/man/8/mdadm)
- [Linux RAID Wiki](https://raid.wiki.kernel.org/)
- [Software RAID HOWTO](https://www.tldp.org/HOWTO/Software-RAID-HOWTO.html)
