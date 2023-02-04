#!/bin/sh

# disable terminal receiver
stty -cread

# enable tracing
set -eux

# sanity check
[ ${1} = /dev/mmcblk0p3 ] || exit 1
[ ${2} = /dev/mmcblk0p4 ] || exit 1

IMAGE_FILE=${3}

# write root
ROOT_IMAGE_OFFSET=$(printf "%d" "0x$(hexdump -s136 -n8 -v -e "8/1 \"%02x\"" ${IMAGE_FILE})")
dd if=${IMAGE_FILE} bs=1024 skip=$((${ROOT_IMAGE_OFFSET} / 1024)) | gunzip -c | dd of=/dev/mmcblk0p3
sync

# recreate partitions
(
  echo p  # print the partition table
  echo d  # delete /dev/mmcblk0p4 partition
  echo 4
  echo d  # delete /dev/mmcblk0p3 partition
  echo 3
  echo n  # add new /dev/mmcblk0p3 partition
  echo 3
  echo
  echo +27G
  echo n  # add new /dev/mmcblk0p4 partition
  echo 4
  echo
  echo
  echo p  # print the partition table
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
[ -b ${IMAGE_FILE} ] || (rm -f ${IMAGE_FILE} && sync)

# reboot
MOUNTED_FILE_SYSTEMS=$(mount | grep '^/dev' | cut -d' ' -f3)
[ ! -z "${MOUNTED_FILE_SYSTEMS}" ] && (umount -fr ${MOUNTED_FILE_SYSTEMS} && sync && sleep 2)
chest-ctl --reset
halt -f

# the root disk is placed after this script at the next multiple of 1024 bytes

exit
