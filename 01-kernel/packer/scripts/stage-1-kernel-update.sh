#!/bin/bash

## Install elrepo
#yum install -y http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
## Install new kernel
#yum --enablerepo elrepo-kernel install kernel-ml -y
## Remove older kernels (Only for demo! Not Production!)
#rm -f /boot/*3.10*

# Install dependecies, download kernel sources, config/make/make install
yum install -y ncurses-devel make gcc bc bison flex elfutils-libelf-devel openssl-devel grub2 wget perl bzip2 tar && cd /usr/src/ && wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.5.7.tar.xz && tar -xf linux-5.5.7.tar.xz && cd linux-5.5.7 && cp -v /boot/config-$(uname -r) .config && make olddefconfig && make -j4 && make modules_install && make install

# Update GRUB
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-set-default 0
echo "Grub update done."
# Reboot VM
shutdown -r now
