FROM rockylinux:9

# Install LVM and disk management tools
RUN yum install -y \
    lvm2 \
    xfsdump \
    xfsprogs \
    util-linux \
    && yum clean all

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
