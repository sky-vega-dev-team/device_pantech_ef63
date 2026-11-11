#!/sbin/sh
#
# Put the video firmware of the variant in place.
#
# The S, K and L sign their firmware for their own model id, and the trust
# zone takes Venus only signed for the model id of the modem firmware on the
# phone: D004 for the S, D503 for the K and DA03 for the L. Read it from the
# modem firmware rather than the model name, which an S with the firmware of
# the L also has. The firmware of the S is the default; copy that of the K or
# L over it.
#

MODEM=/dev/block/platform/msm_sdcc.1/by-name/modem

model=$(grep -a -o -m 1 "007BC0E10000[0-9A-F]\{4\} HW_ID" $MODEM | head -n 1 | cut -c 13-16)
case "$model" in
  D503) variant=ef63k ;;
  DA03) variant=ef63l ;;
  *) variant= ;;
esac
echo "device_check: modem firmware for model ${model:-unknown}, ${variant:-default} video firmware"

# Mount the system partition as backuptool does. The fstab of TWRP puts the
# mount point first, that of the LineageOS recovery the device.
SYSDEV=$(grep -v "^#" /etc/recovery.fstab | grep -E "(^|[[:blank:]])/system[[:blank:]]" | \
    tail -n1 | tr -s "[:blank:]" "\n" | grep "^/dev/" | head -n1)
[ -b "$SYSDEV" ] || SYSDEV=/dev/block/platform/msm_sdcc.1/by-name/system
[ -b "$SYSDEV" ] || exit 1
if grep -q -e "^$SYSDEV" /proc/mounts; then
  umount $(grep -e "^$SYSDEV" /proc/mounts | cut -d" " -f2)
fi
if [ -d /mnt/system ]; then
  SYSMOUNT=/mnt/system
elif [ -d /system_root ]; then
  SYSMOUNT=/system_root
else
  SYSMOUNT=/system
fi
mount -t ext4 $SYSDEV $SYSMOUNT -o rw,discard || exit 1
S=$SYSMOUNT/system

# Write into the files in place, so that they keep their labels
ret=0
if [ -n "$variant" ]; then
  for f in $S/vendor/etc/firmware_$variant/*; do
    cat $f > $S/vendor/firmware/${f##*/} || ret=1
  done
fi
rm -rf $S/vendor/etc/firmware_ef63k $S/vendor/etc/firmware_ef63l

umount $SYSMOUNT
exit $ret
