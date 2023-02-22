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

# recreate partitions
(
  # print the partition table
  echo p
  # delete /dev/mmcblk0p4 partition
  echo d
  echo 4
  # delete /dev/mmcblk0p3 partition
  echo d
  echo 3
  # add new /dev/mmcblk0p3 partition
  echo n
  echo 3
  echo
  echo +27G
  # add new /dev/mmcblk0p4 partition
  echo n
  echo 4
  echo
  echo
  # print the partition table
  echo p
  echo w
) | fdisk /dev/mmcblk0
sfdisk --part-uuid /dev/mmcblk0 3 42424242-1120-1120-1120-424242424242
sfdisk --part-uuid /dev/mmcblk0 4 66666666-1120-1120-1120-666666666666

# provision data
mkfs.ext2 -q /dev/mmcblk0p4
mkdir -p /data
mount /dev/mmcblk0p4 /data
mkdir -p /data/.image
chown 1001:1001 /data/.image
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
