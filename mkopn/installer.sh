#!/bin/sh

# disable terminal receiver
stty -cread

# enable tracing
set -eux

# sanity check
[ "${1}" = /dev/mmcblk0p3 ] || exit 1
[ "${2}" = /dev/mmcblk0p4 ] || exit 1

IMAGE_FILE="${3}"

# write root
ROOT_IMAGE_OFFSET=$(printf "%d" "0x$(hexdump -s136 -n8 -v -e "8/1 \"%02x\"" "${IMAGE_FILE}")")
INPUT_BLOCKSIZE=4096
OUTPUT_BLOCKSIZE=4096
dd if="${IMAGE_FILE}" bs="${INPUT_BLOCKSIZE}" skip=$((ROOT_IMAGE_OFFSET / INPUT_BLOCKSIZE)) | gunzip -c | dd of=/dev/mmcblk0p3 bs="${OUTPUT_BLOCKSIZE}"
sync

# before adjusting partitions, unmount everything
MOUNTED_FILE_SYSTEMS=$(mount | grep '^/dev' | cut -d' ' -f3)
[ -n "${MOUNTED_FILE_SYSTEMS}" ] && (umount -fr "${MOUNTED_FILE_SYSTEMS}" && sync && sleep 2)

# provision data
mkfs.ext2 -U 66666666-1120-1120-1120-666666666666 -L data -q /dev/mmcblk0p4
mkdir -p /data
mount /dev/mmcblk0p4 /data
mkdir -p /data/home/nao /data/.work-home-nao /data/.image
chown 1001:1001 /data/home/nao /data/.image
umount /data

# disable image
[ -b "${IMAGE_FILE}" ] || (rm -f "${IMAGE_FILE}" && sync)

# reboot
MOUNTED_FILE_SYSTEMS=$(mount | grep '^/dev' | cut -d' ' -f3)
[ -n "${MOUNTED_FILE_SYSTEMS}" ] && (umount -fr "${MOUNTED_FILE_SYSTEMS}" && sync && sleep 2)
chest-ctl --reset
halt -f

# the root disk is placed after this script at the next multiple of 1024 bytes

exit
