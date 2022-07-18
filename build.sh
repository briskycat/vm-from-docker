#!/bin/bash

set -e

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd 2>/dev/null)"

. "$DIR/builder/functions.sh"

IMG_FILE="linux.img"

echo_green '[Builder]'
create_builder

echo_green '[Guest OS Archive]'
create_os_tar ubuntu "$DIR/work/os.tar"

run_in_builder "$DIR/builder" "$DIR/work" "$DIR/mnt" "
. ./functions.sh

echo_green '[Disk Image]'
create_disk_image /work/${IMG_FILE}
"

run_in_builder_priv "$DIR/builder" "$DIR/work" "$DIR/mnt" "
. ./functions.sh

echo_green '[Loopback Devices]'
setup_loopback_devices /work/${IMG_FILE} /work/loopback.env
"

. "$DIR/work/loopback.env"

run_in_builder_with_dev "$DIR/builder" "$DIR/work" "$DIR/mnt" "${LOOPDEVICE_DRIVE}" "
. ./functions.sh

ROOT_PART_UUID=\$(uuidgen)

echo_green '[Filesystem]'
format_root_partition /dev/sda2 \$ROOT_PART_UUID

echo_green '[Root FS Content]'
mount_fs /dev/sda2 /mnt

tar -xvf /work/os.tar -C /mnt
rm -f /mnt/.dockerenv

echo_green '[GRUB]'
install_grub /dev/sda /dev/sda2 /mnt \$ROOT_PART_UUID

echo_green '[Customization]'
ln -sfv ../run/systemd/resolve/resolv.conf /mnt/etc/resolv.conf

echo_green '[Clean Up]'
umount_fs /mnt
"

run_in_builder_priv "$DIR/builder" "$DIR/work" "$DIR/mnt" "
. ./functions.sh

echo_green '[Loopback Devices Clean Up]'
free_loopback_devices
"

exit 0

#echo_blue "[Convert to qcow2]"
#qemu-img convert -c /host/${DISTR}.img -O qcow2 /host/${DISTR}.qcow2
