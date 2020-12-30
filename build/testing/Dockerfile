## Test container for sysvik
FROM centos:8
ENV container docker

LABEL com.example.version="0.0.1-beta"
LABEL vendor1="Opin Kerfi hf."
LABEL com.example.release-date="2019-11-14"

# Systemd - preparation
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
    systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*;\
    rm -f /etc/systemd/system/*.wants/*;\
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;\
    rm -f /lib/systemd/system/anaconda.target.wants/*;
# Systemd - preparation ends

# Install prerequsites part 1
RUN yum -y update && yum -y install perl && yum clean all
# Generate systemctl for testing
RUN echo "#!/bin/sh" > /usr/bin/systemctl
RUN echo "exit 0" >> /usr/bin/systemctl

# Install prerequsites part 2
VOLUME [ "/sysvik" ]
CMD ["/usr/sbin/init"]
WORKDIR /sysvik

