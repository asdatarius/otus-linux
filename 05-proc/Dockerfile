FROM rockylinux:9

# Install required tools for proc exploration
RUN yum install -y \
    procps-ng \
    util-linux \
    lsof \
    && yum clean all

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
