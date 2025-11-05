# 03-lvm: Logical Volume Management

This homework demonstrates LVM (Logical Volume Manager) operations:
- Creating physical volumes, volume groups, and logical volumes
- Mirrored volumes (/var)
- Snapshots (/home)
- Resizing volumes

## Quick Start (Docker)

```bash
# Start container
docker compose up -d

# Setup complete LVM demonstration
docker compose exec lvm /workspace/setup-lvm.sh

# Explore
docker compose exec lvm bash
pvs
vgs
lvs
df -h | grep /mnt
```

## What It Does

The `setup-lvm.sh` script demonstrates:

1. **Physical Volumes**: Creates 4 loop devices (10GB, 2GB, 1GB, 1GB)
2. **Volume Groups**:
   - `VolGroup00` for root/home/swap
   - `vg_var` for mirrored /var
3. **Logical Volumes**:
   - `LogVol00` (8GB) - root filesystem
   - `LogVol01` (1.5GB) - swap
   - `LogVol_Home` (2GB) - home with snapshot demo
   - `lv_var` (950MB, mirrored) - var with redundancy
4. **Snapshots**: Demonstrates snapshot creation, file deletion, and restoration

## LVM Architecture

```
Physical Devices (loop devices)
        ↓
Physical Volumes (PV)
        ↓
Volume Groups (VG)
        ↓
Logical Volumes (LV)
        ↓
Filesystems (XFS, ext4)
```

### Created Structure

```
VolGroup00 (VG on /dev/loop0 - 10GB)
├── LogVol00 (LV 8GB) → /mnt/root (XFS)
├── LogVol01 (LV 1.5GB) → swap
└── LogVol_Home (LV 2GB) → /mnt/home (XFS)

vg_var (VG on /dev/loop2 + /dev/loop3 - mirrored)
└── lv_var (LV 950MB, mirrored) → /mnt/var (ext4)
```

## Key LVM Operations

### View LVM Structure

```bash
# Quick view
pvs   # Physical volumes
vgs   # Volume groups
lvs   # Logical volumes

# Detailed view
pvdisplay
vgdisplay
lvdisplay

# View mirror details
lvs -a -o +devices vg_var/lv_var
```

### Snapshots

```bash
# Create snapshot
lvcreate -L 100M -s -n my_snap /dev/VolGroup00/LogVol_Home

# View snapshots
lvs

# Mount snapshot (read-only)
mkdir /mnt/snap
mount -o ro /dev/VolGroup00/my_snap /mnt/snap

# Restore from snapshot (merge)
umount /mnt/home
lvconvert --merge /dev/VolGroup00/my_snap
# Reactivate and remount
lvchange -ay /dev/VolGroup00/LogVol_Home
mount /dev/VolGroup00/LogVol_Home /mnt/home
```

### Resizing

```bash
# Extend logical volume
lvextend -L +500M /dev/VolGroup00/LogVol_Home

# Grow filesystem (XFS)
xfs_growfs /mnt/home

# Or for ext4:
# resize2fs /dev/VolGroup00/LogVol_Home
```

### Mirroring

```bash
# View mirror status
lvs -a -o +devices vg_var/lv_var

# The output shows:
# lv_var          vg_var  ...
#   lv_var_rimage_0  ...  /dev/loop2(0)
#   lv_var_rimage_1  ...  /dev/loop3(0)
#   lv_var_rmeta_0   ...  /dev/loop2(0)
#   lv_var_rmeta_1   ...  /dev/loop3(0)
```

## Manual Setup

See `README_VAGRANT.md` for detailed step-by-step instructions for each operation.

## Testing

```bash
# Write data
echo "test data" > /mnt/home/testfile
cat /mnt/home/testfile

# Create and test snapshot
lvcreate -L 100M -s -n test_snap /dev/VolGroup00/LogVol_Home
rm /mnt/home/testfile
# File is deleted

# Restore
umount /mnt/home
lvconvert --merge /dev/VolGroup00/test_snap
lvchange -ay /dev/VolGroup00/LogVol_Home
mount /dev/VolGroup00/LogVol_Home /mnt/home
cat /mnt/home/testfile
# File is back!

# Test mirror by viewing both copies
lvs -a -o +devices vg_var/lv_var
```

## Common Commands

```bash
# Create PV
pvcreate /dev/sdX

# Create VG
vgcreate my_vg /dev/sdX /dev/sdY

# Create LV
lvcreate -n my_lv -L 10G my_vg

# Create mirrored LV
lvcreate -L 1G -m1 -n my_mirror my_vg

# Create snapshot
lvcreate -L 100M -s -n my_snap /dev/my_vg/my_lv

# Extend LV
lvextend -L +5G /dev/my_vg/my_lv

# Remove LV
lvremove /dev/my_vg/my_lv

# Remove VG
vgremove my_vg

# Remove PV
pvremove /dev/sdX
```

## Troubleshooting

```bash
# Activate volume
lvchange -ay /dev/VolGroup00/LogVol_Home

# Deactivate volume
lvchange -an /dev/VolGroup00/LogVol_Home

# Scan for volume groups
vgscan

# Repair filesystem
xfs_repair /dev/VolGroup00/LogVol_Home

# Check space
vgs  # VG free space
lvs  # LV usage
df -h  # Filesystem usage
```

## Cleanup

```bash
# Unmount
umount /mnt/*

# Remove LVs
lvremove /dev/VolGroup00/LogVol00
lvremove /dev/VolGroup00/LogVol01
lvremove /dev/VolGroup00/LogVol_Home
lvremove /dev/vg_var/lv_var

# Remove VGs
vgremove VolGroup00
vgremove vg_var

# Remove PVs
pvremove /dev/loop*

# Detach loop devices
losetup -D
```

## References

- [LVM HOWTO](https://tldp.org/HOWTO/LVM-HOWTO/)
- [Red Hat LVM Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_logical_volumes/)
- [lvm(8) man page](https://linux.die.net/man/8/lvm)
