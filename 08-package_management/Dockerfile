FROM rockylinux:9

# Install RPM build tools and dependencies
RUN yum install -y \
    redhat-lsb-core \
    wget \
    rpmdevtools \
    rpm-build \
    createrepo \
    yum-utils \
    gcc \
    make \
    zlib-devel \
    pcre-devel \
    openssl-devel \
    && yum clean all

# Setup RPM build environment
RUN rpmdev-setuptree

# Create workspace
WORKDIR /workspace

# Default to bash for interactive work
CMD ["/bin/bash"]
