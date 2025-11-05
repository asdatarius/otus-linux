# 08-package_management: RPM Building and Custom Repository

This homework demonstrates how to:
1. Build custom RPM packages (nginx with custom OpenSSL)
2. Create and manage a YUM/DNF repository
3. Host packages via HTTP/nginx

## Learning Objectives

- Understand RPM package structure and build process
- Learn to customize SRPM (Source RPM) packages
- Create repository metadata with `createrepo`
- Host and serve RPM repositories
- Configure YUM/DNF to use custom repositories

## Prerequisites

### Option 1: Docker (Recommended for 2025+)
- Docker Desktop 4.0+ (macOS/Windows) or Docker Engine 20.10+ (Linux)
- Docker Compose v2+
- **Works on**: macOS (Intel/ARM), Linux, Windows with WSL2

### Option 2: Vagrant (Legacy)
- VirtualBox 6.1+
- Vagrant 2.2+
- ⚠️ **Limited support on Apple Silicon Macs**

## Quick Start (Docker)

### Automated Build (Recommended)

```bash
# Start the build environment
docker compose up -d builder

# Run the automated build script
docker compose exec builder bash /workspace/build-nginx-rpm.sh

# Start the repository server
docker compose up -d repo-server

# Access the repository
open http://localhost:8080/repo/
# or: curl http://localhost:8080/repo/
```

### Manual Build Process

```bash
# Start build environment
docker compose up -d builder
docker compose exec builder bash

# Inside the container:
cd ~

# 1. Download nginx SRPM
wget https://nginx.org/packages/centos/9/SRPMS/nginx-1.24.0-1.el9.ngx.src.rpm
rpm -i nginx-1.24.0-1.el9.ngx.src.rpm

# 2. Download OpenSSL
wget https://www.openssl.org/source/openssl-3.0.13.tar.gz
tar -xzf openssl-3.0.13.tar.gz

# 3. Install build dependencies
yum-builddep -y ~/rpmbuild/SPECS/nginx.spec

# 4. Modify nginx.spec to use custom OpenSSL
vi ~/rpmbuild/SPECS/nginx.spec
# Add: --with-openssl=/root/openssl-3.0.13 \
# to the ./configure line

# 5. Build the RPM
cd ~/rpmbuild/SPECS
rpmbuild -bb nginx.spec

# 6. Check results
ls -lh ~/rpmbuild/RPMS/x86_64/

# 7. Copy to repository
mkdir -p /var/www/repo
cp ~/rpmbuild/RPMS/x86_64/nginx-*.rpm /var/www/repo/

# 8. Add additional packages (optional)
wget http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm \
    -O /var/www/repo/percona-release-0.1-6.noarch.rpm

# 9. Create repository metadata
createrepo /var/www/repo/

# 10. Exit and start nginx server
exit
docker compose up -d repo-server
```

### Verify Repository

```bash
# Browse the repository
curl http://localhost:8080/repo/

# Should show:
# - nginx-1.24.0-1.el9.ngx.x86_64.rpm
# - percona-release-0.1-6.noarch.rpm
# - repodata/ directory
```

### Test Installation

```bash
# Start a test Rocky Linux container
docker run -it --rm rockylinux:9 bash

# Inside the test container:
# Add the custom repository
cat > /etc/yum.repos.d/custom.repo <<EOF
[custom]
name=Custom Repository
baseurl=http://host.docker.internal:8080/repo
gpgcheck=0
enabled=1
EOF

# Check repository is available
yum repolist

# Install a package from custom repo
yum install -y percona-release

# Verify
rpm -qa | grep percona
```

## Architecture

The Docker setup consists of two services:

### 1. Builder Service
- **Image**: Rocky Linux 9 with RPM build tools
- **Purpose**: Build custom RPM packages
- **Volumes**:
  - `./:/workspace` - Your homework directory
  - `rpmbuild:/root/rpmbuild` - RPM build directory (persistent)
  - `repo:/var/www/repo` - Shared repository storage

### 2. Repo-Server Service
- **Image**: nginx:alpine
- **Purpose**: Serve the RPM repository over HTTP
- **Port**: 8080 → 80
- **Volume**: `repo:/usr/share/nginx/html/repo` - Repository files

### Persistent Volumes

- **`otus-rpmbuild`**: Stores rpmbuild directory (so you don't rebuild from scratch)
- **`otus-repo`**: Stores repository files (shared between builder and nginx)

## Understanding RPM Building

### RPM Build Directory Structure

```
~/rpmbuild/
├── BUILD/       # Temporary build files
├── BUILDROOT/   # Install root for packaging
├── RPMS/        # Built binary RPMs
│   └── x86_64/  # Architecture-specific RPMs
├── SOURCES/     # Source tarballs and patches
├── SPECS/       # RPM spec files
└── SRPMS/       # Source RPMs
```

### The .spec File

The spec file defines how to build the RPM:

```spec
%build
./configure %{BASE_CONFIGURE_ARGS} \
    --with-openssl=/root/openssl-3.0.13 \   # Custom OpenSSL
    --with-cc-opt="%{WITH_CC_OPT}" \
    --with-ld-opt="%{WITH_LD_OPT}"
make %{?_smp_mflags}
```

Key sections:
- **`%prep`**: Prepare source code
- **`%build`**: Compile the software
- **`%install`**: Install to BUILDROOT
- **`%files`**: List files to include in RPM
- **`%changelog`**: Package changelog

### Repository Metadata

```bash
createrepo /var/www/repo/
```

This creates:
- `repodata/repomd.xml` - Repository metadata index
- `repodata/primary.xml.gz` - Package list
- `repodata/filelists.xml.gz` - File lists
- `repodata/other.xml.gz` - Additional metadata

## Advanced Topics

### Custom RPM Macros

Create `~/.rpmmacros`:
```
%_topdir /root/rpmbuild
%_tmppath /root/rpmbuild/tmp
```

### Signing RPMs

```bash
# Generate GPG key
gpg --gen-key

# Sign RPM
rpm --addsign /var/www/repo/nginx-*.rpm

# Export public key
gpg --export -a 'Your Name' > /var/www/repo/RPM-GPG-KEY
```

### Multi-Architecture Support

```bash
# Build for different architectures
rpmbuild --target=x86_64 -bb nginx.spec
rpmbuild --target=aarch64 -bb nginx.spec
```

## Troubleshooting

### Build Fails with Missing Dependencies

```bash
# Install missing build dependencies
yum-builddep -y ~/rpmbuild/SPECS/nginx.spec

# Or manually install specific packages
yum install -y gcc make zlib-devel pcre-devel
```

### OpenSSL Build Fails

```bash
# Check OpenSSL version compatibility
cd ~/openssl-3.0.13
./config --help

# Test OpenSSL build separately
./config
make
make test
```

### Repository Not Accessible

```bash
# Check nginx is running
docker compose ps

# Check nginx logs
docker compose logs repo-server

# Test locally
docker compose exec repo-server wget -O- http://localhost/repo/
```

### YUM Can't Find Packages

```bash
# Clean YUM cache
yum clean all

# Regenerate cache
yum makecache

# Check repository is enabled
yum repolist enabled
```

## Cleanup

```bash
# Stop all services
docker compose down

# Remove volumes (careful - deletes built RPMs!)
docker compose down -v

# Remove specific volume
docker volume rm otus-rpmbuild
docker volume rm otus-repo
```

## Performance Comparison

| Environment | Build Time | Setup Time | RAM Usage |
|-------------|-----------|------------|-----------|
| Docker      | ~5-10 min | 2-5s       | 1-2GB     |
| Vagrant     | ~5-10 min | 30-60s     | 2-4GB     |

*Build time is similar (actual compilation), but Docker has much faster startup*

## Next Steps

After completing this homework:
1. Try building other RPM packages (httpd, php, etc.)
2. Set up GPG signing for your packages
3. Create a multi-architecture repository
4. Implement automatic repository updates with CI/CD
5. Explore COPR (Cool Other Package Repo) for public hosting

## References

- [RPM Packaging Guide](https://rpm-packaging-guide.github.io/)
- [Fedora RPM Guide](https://docs.fedoraproject.org/en-US/package-maintainers/Packaging_Tutorial_GNU_Hello/)
- [nginx Configuration Reference](https://nginx.org/en/docs/configure.html)
- [createrepo Documentation](https://linux.die.net/man/8/createrepo)
- [OpenSSL Downloads](https://www.openssl.org/source/)

---

## Legacy Vagrant Instructions

See the original README.md in the repository for Vagrant-based instructions. The process is similar but runs in a full VM instead of containers.
