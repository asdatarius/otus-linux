#!/bin/bash
# Setup LVM with loop devices demonstrating:
# - Volume creation and management
# - /var with mirror
# - /home with snapshots
# - Resizing operations

set -e

echo "🔧 Setting up LVM demonstration..."
echo ""

# ============================================================================
# Create Loop Devices (Simulated Disks)
# ============================================================================

echo "💾 Creating sparse disk files..."
dd if=/dev/zero of=/tmp/sda.img bs=1M count=10240 status=progress  # 10GB
dd if=/dev/zero of=/tmp/sdb.img bs=1M count=2048 status=progress   # 2GB
dd if=/dev/zero of=/tmp/sdc.img bs=1M count=1024 status=progress   # 1GB
dd if=/dev/zero of=/tmp/sdd.img bs=1M count=1024 status=progress   # 1GB
echo ""

echo "🔗 Attaching loop devices..."
LOOP_SDA=$(losetup -f)
losetup "$LOOP_SDA" /tmp/sda.img
echo "  sda.img (10GB) -> $LOOP_SDA"

LOOP_SDB=$(losetup -f)
losetup "$LOOP_SDB" /tmp/sdb.img
echo "  sdb.img (2GB)  -> $LOOP_SDB"

LOOP_SDC=$(losetup -f)
losetup "$LOOP_SDC" /tmp/sdc.img
echo "  sdc.img (1GB)  -> $LOOP_SDC"

LOOP_SDD=$(losetup -f)
losetup "$LOOP_SDD" /tmp/sdd.img
echo "  sdd.img (1GB)  -> $LOOP_SDD"

echo ""

# ============================================================================
# Create Volume Groups and Logical Volumes
# ============================================================================

echo "📦 Creating Physical Volumes..."
pvcreate "$LOOP_SDA" "$LOOP_SDB" "$LOOP_SDC" "$LOOP_SDD"
pvdisplay
echo ""

echo "📁 Creating Volume Group 'VolGroup00' on $LOOP_SDA..."
vgcreate VolGroup00 "$LOOP_SDA"
vgdisplay VolGroup00
echo ""

echo "💿 Creating Logical Volumes in VolGroup00..."
# Root volume (8GB)
lvcreate -n LogVol00 -L 8G VolGroup00
echo "  Created LogVol00 (8GB) for /"

# Swap volume (1.5GB)
lvcreate -n LogVol01 -L 1500M VolGroup00
echo "  Created LogVol01 (1.5GB) for swap"

# Home volume (2GB) - will be used for snapshot demo
lvcreate -n LogVol_Home -L 2G VolGroup00
echo "  Created LogVol_Home (2GB) for /home"

lvdisplay
echo ""

# ============================================================================
# Create /var with Mirror
# ============================================================================

echo "🪞 Creating mirrored volume for /var..."
vgcreate vg_var "$LOOP_SDC" "$LOOP_SDD"
lvcreate -L 950M -m1 -n lv_var vg_var
echo "  Created lv_var (950MB) with mirror"

lvdisplay vg_var/lv_var
echo ""

# ============================================================================
# Format and Mount Filesystems
# ============================================================================

echo "📦 Creating filesystems..."
mkfs.xfs -f /dev/VolGroup00/LogVol00
mkfs.xfs -f /dev/VolGroup00/LogVol_Home
mkfs.ext4 -F /dev/vg_var/lv_var
echo ""

echo "📁 Creating mount points..."
mkdir -p /mnt/root /mnt/home /mnt/var
echo ""

echo "🔗 Mounting filesystems..."
mount /dev/VolGroup00/LogVol00 /mnt/root
mount /dev/VolGroup00/LogVol_Home /mnt/home
mount /dev/vg_var/lv_var /mnt/var
echo ""

# ============================================================================
# Snapshot Demonstration
# ============================================================================

echo "📸 Demonstrating Snapshots..."
echo "  Creating test files in /home..."
for i in {1..20}; do
    echo "Test file $i" > /mnt/home/file$i
done
ls /mnt/home
echo ""

echo "  Creating snapshot of LogVol_Home..."
lvcreate -L 100M -s -n home_snap /dev/VolGroup00/LogVol_Home
echo "  Snapshot created"
lvdisplay /dev/VolGroup00/home_snap
echo ""

echo "  Removing some files..."
rm -f /mnt/home/file{11..20}
ls /mnt/home | wc -l
echo "  Files remaining: $(ls /mnt/home | wc -l) (should be 10)"
echo ""

echo "  Restoring from snapshot (merge)..."
umount /mnt/home
lvconvert --merge /dev/VolGroup00/home_snap
# Reactivate and remount
lvchange -ay /dev/VolGroup00/LogVol_Home
mount /dev/VolGroup00/LogVol_Home /mnt/home
echo ""

echo "  After restoration:"
ls /mnt/home | wc -l
echo "  Files restored: $(ls /mnt/home | wc -l) (should be 20)"
echo ""

# ============================================================================
# Summary
# ============================================================================

echo "✅ LVM setup complete!"
echo ""
echo "📊 Volume Summary:"
echo "=================="
pvdisplay --short
echo ""
vgdisplay --short
echo ""
lvdisplay --short
echo ""

echo "💾 Mounted Filesystems:"
echo "======================"
df -h | grep -E '(Filesystem|/mnt)'
echo ""

echo "🔍 Test Commands:"
echo "================="
echo "# View LVM structure:"
echo "  pvs"
echo "  vgs"
echo "  lvs"
echo ""
echo "# Check mirror status:"
echo "  lvs -a -o +devices vg_var/lv_var"
echo ""
echo "# View snapshot:"
echo "  # Create new snapshot first:"
echo "  lvcreate -L 100M -s -n new_snap /dev/VolGroup00/LogVol_Home"
echo "  lvs"
echo ""
echo "# Resize volume:"
echo "  lvextend -L +500M /dev/VolGroup00/LogVol_Home"
echo "  xfs_growfs /mnt/home"
echo ""
echo "# Test files:"
echo "  echo 'test' > /mnt/home/newfile"
echo "  cat /mnt/home/newfile"
