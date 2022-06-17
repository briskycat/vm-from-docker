FROM amd64/ubuntu:20.04
LABEL source="vm-from-docker"
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update && apt-get -y install grub-pc \
    udev uuid-runtime sudo e2fsprogs parted fdisk qemu-utils
WORKDIR /home
