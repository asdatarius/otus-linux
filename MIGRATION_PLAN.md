# OTUS Linux: Vagrant to Docker Migration Plan

## Executive Summary

This document outlines a comprehensive migration strategy from Vagrant/VirtualBox to Docker/Docker Compose for the OTUS Linux homework repository. The migration addresses compatibility issues with modern macOS (especially Apple Silicon) and improves portability, performance, and developer experience.

## Current State Analysis

### Repository Overview
- **Purpose**: Educational Linux system administration homework assignments
- **Current Stack**: Vagrant + VirtualBox + CentOS 7
- **Homework Count**: 7 assignments (01-kernel, 02-raid, 03-lvm, 04-bash, 05-proc, 07-systemd, 08-package_management)

### Vagrant Usage Patterns

| Homework | Resources | Special Requirements | Provisioning |
|----------|-----------|---------------------|--------------|
| 01-kernel | 4 CPU, 1GB RAM | Packer for custom box creation | Kernel build tooling |
| 02-raid | 4 CPU, 2GB RAM | 4×250MB additional disks | mdadm, RAID 10 setup |
| 03-lvm | 1 CPU, 256MB RAM | 4 disks (10GB, 2GB, 1GB, 1GB) | LVM tools, complex volume operations |
| 04-bash | 4 CPU, 2GB RAM | None | mailx, systemd timers |
| 05-proc | 4 CPU, 2GB RAM | None | Custom /proc reading scripts |
| 07-systemd | 4 CPU, 2GB RAM | None | systemd services and timers |
| 08-package_management | 4 CPU, 2GB RAM | None | RPM build tools, Docker (already used!) |

### Problems with Current Vagrant Setup

1. **macOS Compatibility Issues**
   - VirtualBox has poor support for Apple Silicon (M1/M2/M3)
   - Vagrant development has slowed significantly
   - VirtualBox GUI and kernel extensions cause issues on modern macOS

2. **Resource Inefficiency**
   - Full VMs consume significant RAM and CPU
   - Slow boot times (30-60 seconds per VM)
   - Large disk footprint for VM images

3. **Developer Experience**
   - Complex setup requiring VirtualBox + Vagrant installation
   - Platform-specific VirtualBox disk management
   - Difficult to run multiple environments simultaneously

4. **Maintenance Burden**
   - CentOS 7 is EOL (June 2024)
   - Security vulnerabilities in outdated base images
   - Difficult to update and maintain custom boxes

## Migration Strategy

### Core Principles

1. **Preserve Educational Value**: Maintain hands-on learning of Linux system concepts
2. **Maximize Compatibility**: Ensure cross-platform support (macOS Intel/ARM, Linux, Windows)
3. **Minimize Disruption**: Keep homework structure and objectives intact
4. **Improve DX**: Faster startup, easier setup, better documentation
5. **Use Modern Tools**: Docker, Docker Compose, modern base images

### Phased Approach

#### Phase 1: Foundation (Week 1-2)
- Create base Docker images for different homework types
- Establish docker-compose patterns
- Migrate simple homeworks (04-bash, 05-proc, 07-systemd)

#### Phase 2: Complex Storage (Week 3-4)
- Implement volume strategies for disk-based homeworks
- Migrate 02-raid and 03-lvm with Docker volume mounts
- Test RAID/LVM operations in privileged containers

#### Phase 3: Specialized Cases (Week 5)
- Handle 01-kernel (may remain Vagrant or use alternative approach)
- Migrate 08-package_management
- Complete testing and documentation

#### Phase 4: Finalization (Week 6)
- Update README files
- Create migration guide
- Preserve Vagrant files in `legacy/` directory

## Technical Architecture

### Base Image Strategy

**Option 1: Official Images (Recommended)**
```dockerfile
FROM rockylinux:9
# Rocky Linux is the CentOS successor, actively maintained
```

**Option 2: AlmaLinux**
```dockerfile
FROM almalinux:9
# Another RHEL-compatible alternative
```

**Benefits over CentOS 7:**
- Active maintenance and security updates
- Better ARM64 support for Apple Silicon
- Modern kernel and systemd versions
- Long-term support (until 2032 for Rocky 9)

### Docker Compose Architecture

Create a consistent pattern across all homeworks:

```yaml
# Example: docker-compose.yml
version: '3.8'

services:
  homework:
    build: .
    container_name: otus-linux-{homework-name}
    hostname: asdatarius-{homework-name}
    privileged: ${PRIVILEGED:-false}  # Only when needed
    cap_add:
      - SYS_ADMIN  # For systemd if needed
    volumes:
      - ./:/workspace:rw
      - /sys/fs/cgroup:/sys/fs/cgroup:ro  # For systemd
    environment:
      - HOMEWORK={homework-name}
    command: /sbin/init  # For systemd-based homeworks
    tmpfs:
      - /run
      - /tmp
```

### Per-Homework Migration Details

#### 01-kernel: Custom Kernel Build
**Challenge**: Packer + custom box creation
**Solution Options**:
1. **Multi-stage Docker build** (Recommended)
   ```dockerfile
   FROM rockylinux:9 AS builder
   RUN yum groupinstall "Development Tools" -y
   WORKDIR /usr/src
   # Download and build kernel

   FROM rockylinux:9
   COPY --from=builder /boot/vmlinuz-* /boot/
   ```

2. **Keep Vagrant** (Alternative)
   - Some kernel-level operations require actual VMs
   - Document clearly as special case
   - Provide Docker alternative for non-kernel tasks

3. **Use GitHub Actions** (Modern Approach)
   - Build custom kernels in CI/CD
   - Distribute as container images
   - More realistic modern workflow

**Recommendation**: Multi-stage Docker build + documentation

---

#### 02-raid: RAID Configuration
**Challenge**: Requires multiple block devices
**Solution**: Docker volumes with loop devices

```dockerfile
FROM rockylinux:9

RUN yum install -y mdadm smartmontools hdparm gdisk util-linux

# Create loop devices for RAID
COPY setup-raid.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/setup-raid.sh

ENTRYPOINT ["/usr/local/bin/setup-raid.sh"]
```

```bash
# setup-raid.sh
#!/bin/bash
# Create sparse files to simulate disks
for i in {1..4}; do
    dd if=/dev/zero of=/tmp/disk${i}.img bs=1M count=250
    losetup /dev/loop${i} /tmp/disk${i}.img
done

# Zero superblocks
mdadm --zero-superblock --force /dev/loop{1..4}

# Create RAID 10
mdadm --create /dev/md0 -l 10 -n 4 /dev/loop{1..4}

# Continue with partitioning...
exec /bin/bash
```

**docker-compose.yml:**
```yaml
services:
  raid:
    build: .
    container_name: otus-linux-raid
    privileged: true  # Required for loop devices
    devices:
      - /dev/loop-control
    cap_add:
      - SYS_ADMIN
      - MKNOD
```

**Limitations**:
- Requires privileged mode (educational context acceptable)
- Loop devices instead of real block devices (still demonstrates concepts)

---

#### 03-lvm: Logical Volume Management
**Challenge**: Multiple disks, complex volume operations
**Solution**: Similar to RAID, using loop devices

```dockerfile
FROM rockylinux:9

RUN yum install -y lvm2 xfsdump

COPY setup-lvm.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/setup-lvm.sh

ENTRYPOINT ["/usr/local/bin/setup-lvm.sh"]
```

```bash
# setup-lvm.sh
#!/bin/bash
# Create sparse files with different sizes
dd if=/dev/zero of=/tmp/sda.img bs=1M count=10240  # 10GB
dd if=/dev/zero of=/tmp/sdb.img bs=1M count=2048   # 2GB
dd if=/dev/zero of=/tmp/sdc.img bs=1M count=1024   # 1GB
dd if=/dev/zero of=/tmp/sdd.img bs=1M count=1024   # 1GB

# Attach as loop devices
for i in {a..d}; do
    losetup /dev/loop${i} /tmp/sd${i}.img
done

# Install required tools for homework
yum install -y xfsdump

exec /bin/bash
```

**Benefits**:
- All LVM operations work identically
- Snapshots, mirrors, resizing all supported
- Faster than VM startup

---

#### 04-bash: Log Monitoring with systemd
**Challenge**: systemd timers and mail functionality
**Solution**: systemd-enabled container

```dockerfile
FROM rockylinux:9

RUN yum install -y systemd mailx cronie

# Enable systemd
ENV container docker
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*;\
    rm -f /etc/systemd/system/*.wants/*;\
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;\
    rm -f /lib/systemd/system/anaconda.target.wants/*;

VOLUME [ "/sys/fs/cgroup" ]

CMD ["/usr/sbin/init"]
```

**docker-compose.yml:**
```yaml
services:
  bash:
    build: .
    container_name: otus-linux-bash
    privileged: true
    volumes:
      - ./:/vagrant:rw
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    command: /usr/sbin/init
```

**Setup Script:**
```bash
#!/bin/bash
# run-inside-container.sh
ln -sf /vagrant/asdatarius-log-alert.service /etc/systemd/system/
ln -sf /vagrant/asdatarius-log-alert.timer /etc/systemd/system/
systemctl daemon-reload
systemctl start asdatarius-log-alert.timer
```

---

#### 05-proc: Process Filesystem Exploration
**Challenge**: Minimal - just needs /proc access
**Solution**: Simple container, no special requirements

```dockerfile
FROM rockylinux:9

RUN yum install -y procps-ng util-linux

WORKDIR /workspace
COPY *.sh /usr/local/bin/

CMD ["/bin/bash"]
```

**docker-compose.yml:**
```yaml
services:
  proc:
    build: .
    container_name: otus-linux-proc
    volumes:
      - ./:/workspace:rw
    working_dir: /workspace
    command: /bin/bash
```

**Usage:**
```bash
docker-compose run --rm proc bash
# Inside container:
./asdatarius_ps_ax.sh
./asdatarius_lsof.sh
```

**This is the simplest migration!**

---

#### 07-systemd: Service Management
**Challenge**: systemd services, timers, and templates
**Solution**: systemd-enabled container (similar to 04-bash)

```dockerfile
FROM rockylinux:9

RUN yum install -y systemd httpd spawn-fcgi php php-cli mod_fcgid

# systemd setup (same as 04-bash)
ENV container docker
RUN systemctl mask systemd-remount-fs.service \
                   dev-hugepages.mount \
                   sys-fs-fuse-connections.mount \
                   display-manager.service \
                   getty@.service \
                   systemd-logind.service

VOLUME [ "/sys/fs/cgroup" ]
CMD ["/usr/sbin/init"]
```

**Benefits:**
- All systemd operations work identically
- Faster iterations (no VM reboot needed)
- Easy to test multiple configurations

---

#### 08-package_management: RPM Building and Repository
**Challenge**: Already uses Docker for nginx!
**Solution**: Extend existing Docker usage

```dockerfile
FROM rockylinux:9

RUN yum install -y \
    redhat-lsb-core \
    wget \
    rpmdevtools \
    rpm-build \
    createrepo \
    yum-utils \
    nginx

# Setup for RPM building
RUN rpmdev-setuptree

WORKDIR /workspace
CMD ["/bin/bash"]
```

**docker-compose.yml:**
```yaml
services:
  package-mgmt:
    build: .
    container_name: otus-linux-package-mgmt
    volumes:
      - ./:/workspace:rw
      - rpmbuild:/root/rpmbuild
    ports:
      - "8080:80"

  nginx-repo:
    image: nginx:alpine
    container_name: otus-linux-nginx-repo
    volumes:
      - ./www:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    ports:
      - "8081:80"

volumes:
  rpmbuild:
```

**This homework actually becomes SIMPLER with Docker!**

---

## Implementation Roadmap

### Quick Start Template

Create a root-level `docker/` directory with shared resources:

```
otus-linux/
├── docker/
│   ├── base/
│   │   ├── Dockerfile.rockylinux9
│   │   ├── Dockerfile.systemd
│   │   └── Dockerfile.storage
│   ├── scripts/
│   │   ├── setup-loop-devices.sh
│   │   └── init-systemd.sh
│   └── templates/
│       └── docker-compose.template.yml
├── 01-kernel/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── Vagrantfile (legacy)
├── 02-raid/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── Vagrantfile (legacy)
...
```

### Migration Checklist Per Homework

- [ ] Create Dockerfile based on appropriate base image
- [ ] Create docker-compose.yml with proper configuration
- [ ] Test all homework objectives in container
- [ ] Update README.md with Docker instructions
- [ ] Add Docker-specific troubleshooting section
- [ ] Keep Vagrantfile in place for backwards compatibility
- [ ] Create CI/CD pipeline to test Docker setup

### Compatibility Strategy

**Support both Vagrant and Docker during transition:**

```markdown
# In each homework README.md

## Prerequisites

### Option 1: Docker (Recommended for 2025+)
- Docker Desktop 4.0+ (macOS/Windows) or Docker Engine 20.10+ (Linux)
- Docker Compose v2+
- Works on: macOS (Intel/ARM), Linux, Windows with WSL2

### Option 2: Vagrant (Legacy)
- VirtualBox 6.1+
- Vagrant 2.2+
- ⚠️ Limited support on Apple Silicon Macs

## Quick Start

### Using Docker
\`\`\`bash
docker-compose up -d
docker-compose exec homework bash
# Run homework commands
docker-compose down
\`\`\`

### Using Vagrant
\`\`\`bash
vagrant up
vagrant ssh
# Run homework commands
vagrant destroy -f
\`\`\`
```

---

## Testing Strategy

### Automated Testing

Create a test suite for each homework:

```bash
#!/bin/bash
# test-docker-setup.sh

HOMEWORK=$1

echo "Testing ${HOMEWORK}..."
cd "${HOMEWORK}"

# Build and start
docker-compose build
docker-compose up -d

# Run homework-specific tests
case ${HOMEWORK} in
  "05-proc")
    docker-compose exec -T homework bash /workspace/asdatarius_ps_ax.sh
    docker-compose exec -T homework bash /workspace/asdatarius_lsof.sh
    ;;
  "02-raid")
    docker-compose exec -T homework bash -c "mdadm --detail /dev/md0"
    docker-compose exec -T homework bash -c "cat /proc/mdstat"
    ;;
  # Add other cases...
esac

# Cleanup
docker-compose down -v

echo "✓ ${HOMEWORK} tests passed"
```

### GitHub Actions CI

```yaml
# .github/workflows/test-docker.yml
name: Test Docker Setups

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        homework:
          - 01-kernel
          - 02-raid
          - 03-lvm
          - 04-bash
          - 05-proc
          - 07-systemd
          - 08-package_management

    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Test ${{ matrix.homework }}
        run: |
          cd ${{ matrix.homework }}
          docker-compose build
          docker-compose up -d
          # Run tests
          docker-compose down -v
```

---

## Benefits of Migration

### Performance Improvements
| Metric | Vagrant | Docker | Improvement |
|--------|---------|--------|-------------|
| Boot time | 30-60s | 2-5s | **10-20x faster** |
| RAM overhead | 256MB-2GB | 50-200MB | **~5x less** |
| Disk space | 2-5GB per VM | 200-500MB per container | **~10x less** |
| CPU overhead | Full virtualization | Process isolation | **Much lower** |

### Developer Experience
- ✅ Works natively on Apple Silicon Macs
- ✅ Consistent behavior across all platforms
- ✅ Faster iteration cycles
- ✅ Easier to run multiple environments simultaneously
- ✅ Better integration with modern dev tools (VS Code, etc.)
- ✅ Easier cleanup (no leftover VMs)

### Maintenance
- ✅ Modern, maintained base images (Rocky Linux 9)
- ✅ Security updates via base image updates
- ✅ Easier to version control configurations
- ✅ Simpler CI/CD integration
- ✅ Container images can be pre-built and distributed

---

## Risks and Mitigations

### Risk: Privileged Containers
**Concern**: Some homeworks require privileged mode
**Mitigation**:
- Document security implications clearly
- Use capability-based restrictions where possible
- Educational use case justifies the approach
- Provide unprivileged alternatives where feasible

### Risk: Different Kernel Between Host and Container
**Concern**: Container shares host kernel
**Mitigation**:
- Most homework objectives don't require kernel differences
- 01-kernel homework may need special handling
- Document limitations clearly
- Provide VM alternative for true kernel work

### Risk: Learning Curve
**Concern**: Students may be unfamiliar with Docker
**Mitigation**:
- Provide detailed documentation
- Create video tutorials
- Offer both options during transition
- Docker is increasingly industry-standard skill

### Risk: Behavioral Differences
**Concern**: systemd/storage may behave differently
**Mitigation**:
- Extensive testing of each homework
- Document any differences
- Adjust homework instructions if needed
- Most operations work identically

---

## Migration Timeline

### Week 1-2: Preparation
- Set up base images
- Create docker-compose templates
- Document patterns
- Test simple migrations (05-proc)

### Week 3-4: Core Migration
- Migrate 04-bash, 07-systemd
- Migrate 08-package_management
- Create comprehensive documentation
- Set up CI/CD testing

### Week 5: Storage Migration
- Migrate 02-raid with loop devices
- Migrate 03-lvm with loop devices
- Extensive testing of storage operations
- Performance benchmarking

### Week 6: Kernel and Finalization
- Handle 01-kernel (special case)
- Final testing all homeworks
- Update main README
- Archive Vagrant files to legacy/
- Publish migration guide

---

## Recommended First Steps

1. **Start with 05-proc** (simplest, already implemented!)
   ```bash
   cd 05-proc
   cat > Dockerfile << 'EOF'
   FROM rockylinux:9
   RUN yum install -y procps-ng util-linux
   WORKDIR /workspace
   CMD ["/bin/bash"]
   EOF

   cat > docker-compose.yml << 'EOF'
   version: '3.8'
   services:
     proc:
       build: .
       container_name: otus-linux-proc
       volumes:
         - ./:/workspace
       command: /bin/bash -c "tail -f /dev/null"
   EOF

   docker-compose up -d
   docker-compose exec proc bash
   ./asdatarius_ps_ax.sh
   ./asdatarius_lsof.sh
   ```

2. **Test and validate** the approach works

3. **Create a pattern** that can be replicated

4. **Document learnings** for next homework

5. **Iterate and improve**

---

## Alternative: Hybrid Approach

If full migration proves challenging, consider:

1. **Keep Vagrant for:**
   - 01-kernel (actual kernel building/testing)
   - 02-raid (if loop devices prove insufficient)
   - 03-lvm (if complex operations fail)

2. **Use Docker for:**
   - 04-bash (simple, systemd works well)
   - 05-proc (trivial migration)
   - 07-systemd (systemd works in containers)
   - 08-package_management (already uses Docker!)

This gives you **~60% of the value** with **~20% of the effort**.

---

## Conclusion

The migration from Vagrant to Docker is **highly recommended** for this repository:

### Key Reasons:
1. **Vagrant is declining** - limited development, poor Apple Silicon support
2. **Docker is industry standard** - students should learn it anyway
3. **Better performance** - 10-20x faster startup times
4. **Lower barriers** - easier setup, cross-platform compatibility
5. **Modern stack** - move from EOL CentOS 7 to supported Rocky Linux 9

### Success Metrics:
- ✅ All homeworks work on macOS (Intel + ARM), Linux, Windows
- ✅ < 10 second startup time for all environments
- ✅ < 500MB disk space per homework
- ✅ Clear documentation for Docker setup
- ✅ Backward compatible with existing Vagrant users
- ✅ CI/CD testing all Docker configurations

### Recommended Action:
**Start migration immediately** using the phased approach, beginning with 05-proc as a proof of concept.

---

## Appendix: Quick Reference Commands

### Docker Compose Cheat Sheet
```bash
# Start environment
docker-compose up -d

# View logs
docker-compose logs -f

# Execute commands
docker-compose exec homework bash

# Stop environment
docker-compose down

# Cleanup everything
docker-compose down -v --rmi local

# Rebuild
docker-compose build --no-cache
docker-compose up -d --force-recreate
```

### Debugging
```bash
# Check container status
docker ps -a

# Inspect container
docker inspect otus-linux-{homework}

# Check logs
docker logs otus-linux-{homework}

# Access shell in running container
docker exec -it otus-linux-{homework} bash

# Check resource usage
docker stats
```

---

## Contact and Support

For questions about this migration plan:
- Create an issue in the repository
- Reference this migration plan document
- Tag issues with `migration` label

**Document Version**: 1.0
**Last Updated**: 2025-11-04
**Author**: Claude (AI Assistant)
**Status**: Draft for Review
