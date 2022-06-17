FROM amd64/ubuntu:20.04
LABEL source="vm-from-docker"
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update \
  && apt-get -y install \
  linux-image-virtual systemd overlayroot plymouth plymouth-theme-ubuntu-text \
  software-properties-common \
  cloud-guest-utils cloud-initramfs-copymods cloud-initramfs-dyn-netconf open-vm-tools \
  netplan.io ethtool \
  openssh-server openssh-client curl \
  htop vim nano \
  ubuntu-minimal
COPY wired.network /etc/systemd/network/20-wired.network
RUN systemctl enable systemd-networkd
RUN echo "root:root" | chpasswd
