#!/bin/sh
#
# Copyright (C) 2017
# Lukasz Majewski, DENX Software Engineering, lukma@denx.de
#
# NOTE:
# This file is tunned to work with busybox's sh shell (ash = !bash)
#
#set -x

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

ctrl_c() {
    echo "** Trapped CTRL-C"
    rm -rf /mnt/${fn}*
    umount /mnt/ && ubidetach -d 0
    kill -KILL -${$}
}

echoErr() { echo "$@" 1>&2; exit 1; }

usage() {
    echo "" 1>&2
    echo -n "Usage: $0 -d <mtd device - e.g. 0,1,2> [-c <loop count>\
 -m <max file size MiB> -u <ubi device> -s]" 1>&2
    echo "" 1>&2
    exit 1
}

tests_count=1
device=-1
max_file_size=50
ubi_device=0

fn="test_file"

while getopts "c:hd:m:u:s" opt; do
    case $opt in
	c)
	    tests_count=${OPTARG}
	    ;;
	d)
	    device=${OPTARG}
	    ;;
	m)
	    max_file_size=${OPTARG}
	    ;;
	u)
	    ubi_device=${OPTARG}
	    ;;
	s)
	    small_files=1
	    ;;
	h)
	    usage
	    ;;
	*)
	    usage
	    ;;
    esac
done

[ ${device} -eq "-1" ] && usage
[ $((device+1)) -ge $(cat /proc/mtd | wc -l) ] && \
    echoErr "No /dev/mtd${device} !"

if [ -z "${small_files}" ]; then
	unit="MiB"
	BS="1M"
else
	unit="B"
	BS="1"
fi

echo "################################################"
echo "# Test script for mtd/UBI/UBIFS NAND validation"
echo "#"
echo "# Tests count: ${tests_count}"
echo "# Device: /dev/mtd${device}"
echo "# Max file size: ${max_file_size} ${unit}"
echo "################################################"

flash_erase /dev/mtd${device} 0 0 || echoErr "flash_erase failed!"
ubiformat /dev/mtd${device} || echoErr "ubiformat failed!"
ubiattach -p /dev/mtd${device} || echoErr "ubiattach failed!"

ubimkvol /dev/ubi${ubi_device} -N bk3_test_vol -m || echoErr "ubimkvol failed!"
mkfs.ubifs /dev/ubi${ubi_device}_0 || echoErr "mkfs.ubifs failed!"
ubinfo -a

mount -t ubifs ubi${ubi_device}:bk3_test_vol /mnt ||\
    echoErr "ubivolume mount failed!"

count=1

while :;
do

    echo -e "\r"
    echo "NAND (UBIFS) Test no: ${count}"
    count=$((count+1))

    # Write file to UBI volume
    size=$(shuf -i 1-${max_file_size} -n1)
    fn_mod=$(shuf -i 1-50 -n1)
    tf="${fn}${fn_mod}.img"

    echo -n "---> FILE: /mnt/${tf} SIZE: ${size} ${unit} md5sum: "
    dd if=/dev/urandom of=/mnt/${tf} bs=${BS} count=${size} 2> /dev/null ||\
	echoErr "dd failed!"
    sync
    IFS='%'
    md5=$(md5sum /mnt/${tf})
    echo ${md5} > /mnt/${tf}.md5sum
    unset IFS
    sync

    # Check files md5sums
    md5sum -c /mnt/${tf}.md5sum || break
    rm -rf /mnt/${tf}*

    [ "${count}" -gt "${tests_count}" ] && break
done

echo ""
rm -rf /mnt/${fn}*
umount /mnt/ && ubidetach -d ${ubi_device}

echo -e "\r"
echo ""

exit 0
