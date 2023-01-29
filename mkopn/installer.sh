#!/bin/sh

# disable terminal receiver
stty -cread

# DFU mounted /dev/mmcblk1p4 on /mnt, unmount to adjust partitions
unmount /mnt

# log and redirect everything
mount /dev/mmcblk1p1 /internal
exec &> >(tee -a /internal/dfu.log)
# enable tracing
set -euxo pipefail

# sanity check
[ ${1} -eq /dev/mmcblk1p3 ] || exit 1
[ ${2} -eq /dev/mmcblk1p4 ] || exit 1

IMAGE_FILE=${3}

# recreate partitions
parted --script /dev/mmcblk1 \
  "rm 4" \
  "rm 3" \
  "mkpart primary ext4 200MiB 20GiB" \
  "mkpart primary ext4 20GiB -0" \
  "print"
sfdisk --part-uuid /dev/mmcblk1 3 42424242-1120-1120-1120-424242424242
sfdisk --part-uuid /dev/mmcblk1 4 66666666-1120-1120-1120-666666666666

# write root
ROOT_IMAGE_OFFSET=$(printf "%d" "0x$(hexdump -s136 -n8 -v -e "8/1 \"%02x\"")")
dd if=${IMAGE_FILE} bs=1024 skip=$((${ROOT_IMAGE_OFFSET} / 1024)) | gunzip -c | dd of=/dev/mmcblk1p3
sync
resize2fs /dev/mmcblk1p3
sync

# provision data
mkfs.ext4 -q /dev/mmcblk1p4
mount /dev/mmcblk1p4 /data
mkdir -p /data/.image
umount /data

# disable image
rm -f ${IMAGE_FILE}
sync

# reboot
umount -fr $(mount | grep '^/dev' | cut -d' ' -f3)
sync
sleep 2
/usr/libexec/chest-harakiri -r

# the root disk is placed after this script at the next multiple of 1024 bytes

exit
