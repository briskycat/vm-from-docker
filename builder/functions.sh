#!/bin/bash

DRIVE_IMAGE_SIZE=$((2 * 1024 * 1024 * 1024))

SECTOR_SIZE=512

REPO="vm-from-docker"

echo_blue() {
    local font_blue="\033[94m"
    local font_bold="\033[1m"
    local font_end="\033[0m"

    echo -e "\n${font_blue}${font_bold}${1}${font_end}"
}

echo_green() {
    local font_green="\033[0;32m"
    local font_bold="\033[1m"
    local font_end="\033[0m"

    echo -e "\n${font_green}${font_bold}${1}${font_end}"
}

echo_red() {
    local font_red="\033[0;31m"
    local font_bold="\033[1m"
    local font_end="\033[0m"

    echo -e "\n${font_red}${font_bold}${1}${font_end}"
}

create_os_tar() {
    local os="$1"
    local os_tar_file="$2"

    if [ "$os/Dockerfile" -nt "$os_tar_file" ]; then
        echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"
        docker build -f "$os/Dockerfile" -t "${REPO}/$os" "$os"

        local container_id=$(docker run -d "${REPO}/$os" /bin/true)
        docker export -o "$os_tar_file" "$container_id"
        docker container rm "$container_id"
    fi
    echo_blue " <<< ${FUNCNAME}"
}

create_builder() {
    echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"
    docker build -f Dockerfile -t "${REPO}/builder" builder
    echo_blue " <<< ${FUNCNAME}"
}

run_in_builder() {
    local host_dir="$1"
    local work_dir="$2"
    local mnt_dir="$3"
    local cmd="$4"

    echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"
    docker run --rm -it \
        -v "${host_dir}:/home:ro" \
        -v "${work_dir}:/work:rw" \
        -v "${mnt_dir}:/mnt:rw" \
        "${REPO}/builder" bash -e -c "$cmd"
    echo_blue " <<< ${FUNCNAME}"
}

run_in_builder_with_dev() {
    local host_dir="$1"
    local work_dir="$2"
    local mnt_dir="$3"
    local dev1="$4"
    local cmd="$5"

    echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"
    docker run --rm -it \
        -v "${host_dir}:/home:ro" \
        -v "${work_dir}:/work:rw" \
        -v "${mnt_dir}:/mnt:rw" \
        --device "${dev1}:/dev/sda" \
        --device "${dev1}p1:/dev/sda1" \
        --device "${dev1}p2:/dev/sda2" \
        --cap-add SYS_ADMIN --security-opt apparmor=unconfined \
        "${REPO}/builder" bash -e -c "$cmd"
    echo_blue " <<< ${FUNCNAME}"
}

run_in_builder_interactive() {
    local host_dir="$1"
    local work_dir="$2"
    local mnt_dir="$3"

    echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"
    docker run --rm -it \
        -v "${host_dir}:/home:ro" \
        -v "${work_dir}:/work:rw" \
        -v "${mnt_dir}:/mnt:rw" \
        --cap-add SYS_ADMIN --security-opt apparmor=unconfined \
        "${REPO}/builder" bash
    echo_blue " <<< ${FUNCNAME}"
}

run_in_builder_priv() {
    local host_dir="$1"
    local work_dir="$2"
    local mnt_dir="$3"
    local cmd="$4"

    echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"
    docker run --rm -it \
        -v "${host_dir}:/home:ro" \
        -v "${work_dir}:/work:rw" \
        -v "${mnt_dir}:/mnt:rw" \
        --privileged \
        "${REPO}/builder" bash -e -c "$cmd"
    echo_blue " <<< ${FUNCNAME}"
}

create_disk_image() {
    local disk_image_file="$1"

    echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"
    #dd if=/dev/zero of="$disk_image_file" bs=${DRIVE_IMAGE_SIZE} count=1
    truncate -s "$DRIVE_IMAGE_SIZE" "$disk_image_file"

    echo "Creating partition table..."
#     sfdisk --wipe always --wipe-partitions always "$disk_image_file" <<END
# label: gpt
# label-id: 1038a46a-5def-4e6a-90ed-29f8d9d84990
# device: linux.img
# unit: sectors

# linux.img1 : type="21686148-6449-6E6F-744E-656564454649", size="1MiB", attrs="RequiredPartition,LegacyBIOSBootable"
# linux.img2 : type="4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709", bootable, attrs="RequiredPartition,LegacyBIOSBootable"
# END

    parted --script "$disk_image_file" \
        mklabel gpt \
        mkpart primary ext2 1MiB 2MiB \
        set 1 bios_grub on \
        name 1 "BIOS_Boot" \
        mkpart primary ext4 2MiB 100% \
        name 2 "/" \
        quit

    echo_blue " <<< ${FUNCNAME}"
}

setup_loopback_devices() {
    local disk_image_file="$1"
    local env_file="$2"

    echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"
    # local root_part_start_sectors=$(sfdisk -l "$disk_image_file" | grep "^${disk_image_file}2" | awk '{print $2}')
    sudo losetup -D
    LOOPDEVICE_DRIVE=$(sudo losetup -P -f --show "$disk_image_file")
    echo -e "\n[Using ${LOOPDEVICE_DRIVE} loop device for the drive image]"
    LOOPDEVICE_ROOT_PART="${LOOPDEVICE_DRIVE}p2"
    echo -e "\n[Using ${LOOPDEVICE_ROOT_PART} loop device for the root partition]"
    cat >"$env_file" <<END
LOOPDEVICE_DRIVE="${LOOPDEVICE_DRIVE}"
LOOPDEVICE_BBOOT_PART="${LOOPDEVICE_DRIVE}p1"
LOOPDEVICE_ROOT_PART="${LOOPDEVICE_DRIVE}p2"
END
    echo_blue " <<< ${FUNCNAME}"
}

free_loopback_devices() {
    echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"
    sudo losetup -D
    echo_blue " <<< ${FUNCNAME}"
}

format_root_partition() {
    local loopback_dev="$1"
    local uuid="$2"

    echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"
    mkfs.ext4 -L "/" -U "$uuid" "${loopback_dev}"
    echo_blue " <<< ${FUNCNAME}"
}

mount_fs() {
    local loopback_dev="$1"
    local directory="$2"

    echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"
    sudo mount -t auto "$loopback_dev" "$directory"
    echo_blue " <<< ${FUNCNAME}"
}

umount_fs() {
    local directory="$1"

    echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"
    sudo umount "$directory"
    echo_blue " <<< ${FUNCNAME}"
}

install_grub() {
    local loopback_dev="$1"
    local loopback_dev_root_part="$2"
    local root_part_directory="$3"
    local root_part_uuid="$4"

    echo_blue " >>> ${FUNCNAME}$(printf ' %s' "$@")"

    mkdir -p "${root_part_directory}/boot/grub"

    cat >"${root_part_directory}/etc/fstab" <<END
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a device; this may
# be used with UUID= as a more robust way to name devices that works even if
# disks are added and removed. See fstab(5).
#
# <file_system>                           <mount_point>  <type>  <options>                          <dump>  <pass>
UUID=${root_part_uuid} /              ext4    errors=remount-ro,noatime,discard  0       1
END

    for i in /dev /dev/pts /proc /sys /run; do mount -B "$i" "${root_part_directory}/$i"; done

    chroot "${root_part_directory}" grub-mkconfig -o /boot/grub/grub.cfg
    chroot "${root_part_directory}" grub-install --modules part_gpt --no-floppy ${loopback_dev}
    chroot "${root_part_directory}" update-grub

    for i in /dev/pts /dev /proc /sys /run; do umount "${root_part_directory}/$i"; done

    echo_blue " <<< ${FUNCNAME}"
}
