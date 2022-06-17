
# VM from Docker

This is a simpler version of the original docker-to-linux set of scripts that build a bootable VM image. This one is different mainly in the use of the GRUB2 bootloader, which is native to Ubuntu. The use of privileged Docker is also minimized to lower the risk of corrupting the host system.

Only Ubuntu is currently supported.

## Building

Simply run:

    make all

A file named `linux.img` will be generated in the `work` directory.
