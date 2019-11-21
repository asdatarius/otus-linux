# Homework: LVM

Use centos/7 1804.2 vagrant box for:
1) Reduce / size down to 8G
2) Add vol for /var, use mirror
3) Add vol for /home
4) Restore files from snapshot
5) Add necessary records to fstab, test different options and file systems

Additional task: Add volume for /opt with btrfs/zfs, use cache and snapshots (in progress)

## Step by step guide
 ### Reduce / size down to 8G and add vol for /var (with mirror)
  - xfsdump is required for data backup/restore (move)

  ````
  yum install xfsdump -y
  ````

  - Lets create temporary volume:

  ````
  pvcreate /dev/sdb
  vgcreate vg_root /dev/sdb
  lvcreate -n lv_root -l +100%FREE /dev/vg_root
  ````

  - Add file system and mount it (to /mnt). That vol will be used as temporary storage for current /, can't resize volume on the fly.

  ````
  mkfs.xfs /dev/vg_root/lv_root
  mount /dev/vg_root/lv_root /mnt
  ````

  - Dump/restore

  ````
  xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
  ````

  - Prepare new grub config

  ````
  for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
  chroot /mnt/
  grub2-mkconfig -o /boot/grub2/grub.cfg
  ````

  - Update initrd (+ small patch)

  ````
  cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
  ````

 Fix /boot/grub2/grub.cfg - replace `rd.lvm.lv=VolGroup00/LogVol00` to `rd.lvm.lv=vg_root/lv_root`

  - Exit from chroot and reboot 

  ````
  shutdown -r now
  ````

  - After reboot, delete old 40G LV and create new smaller one (8G).

  ````
  lvremove /dev/VolGroup00/LogVol00
  lvcreate -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
  ````

  - Format volume, copy data back (same method)

  ````
  mkfs.xfs /dev/VolGroup00/LogVol00
  mount /dev/VolGroup00/LogVol00 /mnt
  xfsdump -J - /dev/vg_root/lv_root | xfsrestore -J - /mnt
  ````

  - Config grub once again

  ````
  for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
  chroot /mnt/
  grub2-mkconfig -o /boot/grub2/grub.cfg
  cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
  ````

  - Create mirror on unused disks:
  ````
  vcreate /dev/sdc /dev/sdd
  vgcreate vg_var /dev/sdc /dev/sdd
  lvcreate -L 950M -m1 -n lv_var vg_var
  mkfs.ext4 /dev/vg_var/lv_var
  ````
  
  - Format volume, copy data back (same method)

  ````
  mkfs.ext4 /dev/vg_var/lv_var
  mount /dev/vg_var/lv_var /mnt
  cp -aR /var/* /mnt/ 
  # or use rsync:
  # rsync -avHPSAX /var/ /mnt/
  # backup & clean /var
  mkdir /tmp/oldvar && mv /var/* /tmp/oldvar
  ````
  
  - Mount new vol to correct point
  ````
  umount /mnt
  mount /dev/vg_var/lv_var /var
  # Add new /var to fstab for auto maunt (on startup)
  echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
  ````

  - There is no need in config editing, already correct lv for. So just exit from chroot and reboot to new / + /var

  ````
  shutdown -r now
  ````

 - Remove temporary lv/vg/pv

  ````
  lvremove /dev/vg_root/lv_root
  vgremove /dev/vg_root
  pvremove /dev/sdb
  ````

  ### Add volume for /home
  - Create volume

  ````
  lvcreate -n LogVol_Home -L 2G /dev/VolGroup00
  ````

  - Format

  ````
  mkfs.xfs /dev/VolGroup00/LogVol_Home
  ````

  - Mount

  ````
  mount /dev/VolGroup00/LogVol_Home /mnt/
  cp -aR /home/* /mnt/ 
  # or back it up?
  rm -rf /home/*
  umount /mnt
  mount /dev/VolGroup00/LogVol_Home /home/
  ````

  - Add new /home to fstab (mount on startup)

  ````
  echo "`blkid | grep Home | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab
  ````

 ### Restore files from snapshot

 - Let's create number of files in new /home

 ````
 touch /home/file{1..20}
 ````

 - Create snapshot

 ````
 lvcreate -L 100MB -s -n home_snap /dev/VolGroup00/LogVol_Home
 ````

 - Remove subset of files
 
 ````
 rm -f /home/file{11..20}
 ````

 - Restore them from snapshot

 ````
 umount /home
 lvconvert --merge /dev/VolGroup00/home_snap
 mount /home
 ````
 
 ### Final result
 
 ````
 $ vagrant ssh
 Last login: Tue Nov 19 05:47:46 2019 from 10.0.2.2
 [vagrant@lvm ~]$ lsblk
 NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
 sda 8:0 0 40G 0 disk
 ├─sda1 8:1 0 1M 0 part
 ├─sda2 8:2 0 1G 0 part /boot
 └─sda3 8:3 0 39G 0 part
 ├─VolGroup00-LogVol00 253:0 0 8G 0 lvm /
 ├─VolGroup00-LogVol01 253:1 0 1.5G 0 lvm [SWAP]
 └─VolGroup00-LogVol_Home 253:2 0 2G 0 lvm /home
 sdb 8:16 0 10G 0 disk
 sdc 8:32 0 2G 0 disk
 ├─vg_var-lv_var_rmeta_0 253:3 0 4M 0 lvm
 │ └─vg_var-lv_var 253:7 0 952M 0 lvm /var
 └─vg_var-lv_var_rimage_0 253:4 0 952M 0 lvm
 └─vg_var-lv_var 253:7 0 952M 0 lvm /var
 sdd 8:48 0 1G 0 disk
 ├─vg_var-lv_var_rmeta_1 253:5 0 4M 0 lvm
 │ └─vg_var-lv_var 253:7 0 952M 0 lvm /var
 └─vg_var-lv_var_rimage_1 253:6 0 952M 0 lvm
 └─vg_var-lv_var 253:7 0 952M 0 lvm /var
 sde 8:64 0 1G 0 disk
 ````


