#!/bin/bash
# Script to build custom nginx RPM with OpenSSL

set -e

echo "🔧 Building custom nginx RPM with OpenSSL..."
echo ""

# Download nginx SRPM
echo "📦 Downloading nginx source RPM..."
cd ~
wget -q https://nginx.org/packages/centos/9/SRPMS/nginx-1.24.0-1.el9.ngx.src.rpm -O nginx.src.rpm

# Install SRPM (creates rpmbuild structure)
echo "📂 Installing source RPM..."
rpm -i nginx.src.rpm 2>/dev/null || true

# Download latest OpenSSL
echo "🔐 Downloading OpenSSL..."
cd ~
wget -q https://www.openssl.org/source/openssl-3.0.13.tar.gz
tar -xzf openssl-3.0.13.tar.gz

# Install build dependencies
echo "🔨 Installing build dependencies..."
yum-builddep -y ~/rpmbuild/SPECS/nginx.spec 2>&1 | grep -v "warning:" || true

# Modify nginx.spec to include OpenSSL
echo "✏️  Modifying nginx.spec to use custom OpenSSL..."
SPEC_FILE=~/rpmbuild/SPECS/nginx.spec
OPENSSL_PATH=~/openssl-3.0.13

# Add OpenSSL to configure options
sed -i "/\.\/configure %{BASE_CONFIGURE_ARGS}/a \    --with-openssl=${OPENSSL_PATH} \\\\" ${SPEC_FILE}

# Build RPM
echo "🏗️  Building RPM (this may take several minutes)..."
cd ~/rpmbuild/SPECS
rpmbuild -bb nginx.spec 2>&1 | tail -20

# Check results
echo ""
echo "✅ Build complete!"
echo ""
echo "📦 Created RPMs:"
ls -lh ~/rpmbuild/RPMS/x86_64/nginx-*.rpm

# Copy to shared repository location
echo ""
echo "📋 Copying to repository..."
mkdir -p /var/www/repo
cp ~/rpmbuild/RPMS/x86_64/nginx-*.rpm /var/www/repo/

# Download additional package for repo demo
echo "📥 Adding Percona release package..."
wget -q http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm \
    -O /var/www/repo/percona-release-0.1-6.noarch.rpm || true

# Create repository metadata
echo "🗂️  Creating repository metadata..."
createrepo /var/www/repo/

echo ""
echo "✅ Repository ready at /var/www/repo"
echo ""
echo "Next steps:"
echo "  1. Start nginx: docker compose up -d repo-server"
echo "  2. Browse repo: http://localhost:8080/repo/"
echo "  3. Test installation (in another Rocky Linux container)"
