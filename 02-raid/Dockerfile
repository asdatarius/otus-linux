FROM rockylinux:9

# Install RAID and disk management tools
RUN yum install -y \
    mdadm \
    smartmontools \
    hdparm \
    gdisk \
    parted \
    xfsprogs \
    util-linux \
    && yum clean all

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
