FROM rockylinux:9

# Install required packages
RUN yum install -y \
    systemd \
    epel-release \
    && yum install -y \
    spawn-fcgi \
    php \
    php-cli \
    mod_fcgid \
    httpd \
    && yum clean all

# Configure systemd in container
ENV container docker

# Remove unnecessary systemd services for container
RUN (cd /lib/systemd/system/sysinit.target.wants/; \
    for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*; \
    rm -f /etc/systemd/system/*.wants/*; \
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*; \
    rm -f /lib/systemd/system/anaconda.target.wants/*

WORKDIR /workspace

VOLUME [ "/sys/fs/cgroup" ]

CMD ["/usr/sbin/init"]
