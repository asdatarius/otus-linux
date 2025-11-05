#!/bin/bash
# Setup RAID 10 using loop devices

set -e

echo "🔧 Setting up RAID 10 with loop devices..."
echo ""

# Create sparse files to simulate disks (250MB each)
echo "💾 Creating sparse disk files..."
for i in {1..4}; do
    dd if=/dev/zero of=/tmp/disk${i}.img bs=1M count=250 status=progress
done
echo ""

# Setup loop devices
echo "🔗 Attaching loop devices..."
for i in {1..4}; do
    LOOP_DEV=$(losetup -f)
    losetup "$LOOP_DEV" /tmp/disk${i}.img
    echo "  disk${i}.img -> $LOOP_DEV"
done

# List loop devices
echo ""
echo "📋 Loop devices created:"
losetup -a
echo ""

# Get loop device names
LOOP1=$(losetup -j /tmp/disk1.img | cut -d: -f1)
LOOP2=$(losetup -j /tmp/disk2.img | cut -d: -f1)
LOOP3=$(losetup -j /tmp/disk3.img | cut -d: -f1)
LOOP4=$(losetup -j /tmp/disk4.img | cut -d: -f1)

echo "Using devices: $LOOP1 $LOOP2 $LOOP3 $LOOP4"
echo ""

# Zero superblocks
echo "🧹 Zeroing superblocks..."
mdadm --zero-superblock --force $LOOP1 $LOOP2 $LOOP3 $LOOP4 2>/dev/null || true
echo ""

# Create RAID 10
echo "⚙️  Creating RAID 10 array..."
mdadm --create /dev/md0 -l 10 -n 4 $LOOP1 $LOOP2 $LOOP3 $LOOP4
echo ""

# Create mdadm config
echo "📝 Creating mdadm.conf..."
mkdir -p /etc/mdadm/
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
echo ""

# Show RAID status
echo "📊 RAID Status:"
cat /proc/mdstat
echo ""
mdadm --detail /dev/md0
echo ""

# Create GPT partition table
echo "💿 Creating partitions..."
parted -s /dev/md0 mklabel gpt
parted /dev/md0 mkpart primary xfs 0% 25%
parted /dev/md0 mkpart primary xfs 25% 50%
parted /dev/md0 mkpart primary xfs 50% 75%
parted /dev/md0 mkpart primary xfs 75% 100%
echo ""

# Format partitions
echo "📦 Creating filesystems..."
for i in $(seq 1 4); do
    echo "  Formatting /dev/md0p$i..."
    mkfs.xfs -f /dev/md0p$i
done
echo ""

# Create mount points and mount
echo "📁 Creating mount points..."
mkdir -p /raid/part{1,2,3,4}
for i in $(seq 1 4); do
    mount /dev/md0p$i /raid/part$i
    echo "  Mounted /dev/md0p$i -> /raid/part$i"
done
echo ""

# Show mounted filesystems
echo "✅ RAID 10 setup complete!"
echo ""
echo "📋 Mounted filesystems:"
df -h | grep -E '(Filesystem|/raid)'
echo ""
echo "🔍 Test with:"
echo "  echo 'test' > /raid/part1/testfile"
echo "  cat /raid/part1/testfile"
echo "  cat /proc/mdstat"
echo "  mdadm --detail /dev/md0"
