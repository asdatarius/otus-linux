# 01-kernel: Custom Kernel Building

## Special Case: Vagrant Recommended

This homework involves building custom Linux kernels and creating Vagrant boxes with VirtualBox Guest Additions. **For this specific homework, Vagrant remains the recommended approach** due to:

1. **True kernel testing**: Requires booting into the custom kernel
2. **Packer integration**: Custom box creation workflow
3. **Guest Additions**: VirtualBox-specific drivers
4. **Bootloader config**: GRUB configuration testing

## Why Not Docker?

Docker containers share the host kernel and cannot:
- Boot into custom-compiled kernels
- Test kernel-level changes
- Demonstrate bootloader configuration
- Create bootable VM images

## Alternative: Docker for Build Only

If you want to use Docker for the *build process* only:

```bash
# Create a build container
FROM rockylinux:9
RUN yum groupinstall "Development Tools" -y
RUN yum install -y ncurses-devel bison flex elfutils-libelf-devel openssl-devel

WORKDIR /build
# Download and build kernel here
# But testing requires a real VM
```

### Hybrid Approach

```bash
# 1. Build kernel in Docker (fast, reproducible)
docker run --rm -v $(pwd):/build rockylinux:9 bash build-kernel.sh

# 2. Test in Vagrant (actual boot)
vagrant up
vagrant ssh
uname -r  # Verify custom kernel
```

## Recommended Workflow

**Continue using the existing Vagrant setup for this homework:**

```bash
cd 01-kernel
vagrant up
# Follow existing instructions
```

## Modern Cloud-Native Alternative

For learning kernel concepts in a modern context:

### Option 1: Kernel Modules (Docker-compatible)

```dockerfile
FROM rockylinux:9
RUN yum groupinstall "Development Tools" -y
RUN yum install -y kernel-devel-$(uname -r)

# Build kernel modules instead of full kernel
# Modules can be loaded in privileged containers
```

### Option 2: CI/CD Kernel Builds

```yaml
# .github/workflows/kernel-build.yml
name: Build Custom Kernel

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    container: rockylinux:9
    steps:
      - name: Install build tools
        run: yum groupinstall "Development Tools" -y

      - name: Download kernel source
        run: wget https://cdn.kernel.org/pub/linux/kernel/...

      - name: Configure kernel
        run: make defconfig

      - name: Build kernel
        run: make -j$(nproc)

      - name: Create artifacts
        run: make modules_install INSTALL_MOD_PATH=./output
```

### Option 3: QEMU/KVM (Docker + Virtualization)

```bash
# Run QEMU inside privileged Docker container
docker run --rm -it --privileged \
  -v $(pwd):/workspace \
  rockylinux:9 bash

# Inside container:
yum install -y qemu-kvm
qemu-system-x86_64 -kernel /workspace/vmlinuz -initrd /workspace/initrd ...
```

## Migration Status

**01-kernel: Keep Vagrant** ✅

This is an intentional exception to the Docker migration. The educational value of this homework specifically requires VM capabilities that Docker cannot provide.

## Summary

| Task | Tool | Reason |
|------|------|--------|
| Kernel compilation | Docker ✅ | Fast, reproducible builds |
| Kernel testing | Vagrant ✅ | Requires actual boot |
| Box creation | Packer + Vagrant ✅ | VirtualBox integration |
| **Overall** | **Vagrant** ✅ | Testing is the key learning objective |

## References

- See `README.md` for original Vagrant-based instructions
- [Linux Kernel in a Nutshell](https://www.kernel.org/doc/ols/2006/ols2006v2-pages-371-380.pdf)
- [Kernel Build System](https://www.kernel.org/doc/html/latest/kbuild/index.html)
