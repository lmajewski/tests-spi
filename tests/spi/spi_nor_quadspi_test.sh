#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0+
#
# (C) Copyright 2018
# Lukasz Majewski, DENX Software Engineering, lukma@denx.de.
#
#
#set -x

SPI_FSL_QUADSPI_MOD="fsl_quadspi"

lsmod | grep -q ${SPI_FSL_QUADSPI_MOD}
[ $? -ne 0 ] && insmod ./fsl-quadspi.ko

command -v flash_erase || { echo "./spidev_test not accessibe !"; exit 0; }

count=1

while getopts "d:c:v" opt; do
	case "${opt}" in
	v)
		echo "DEBUG mode" >&2
		DBG="-v"
	;;
	d)
		device=${OPTARG}
		echo "MTD device (/dev/mtd${device})" >&2
	;;
	c)
		count=${OPTARG}
	;;
	\?)
		echo "Invalid option: -${OPTARG}" >&2
		exit 0
	;;
	esac
done

vybryd_test_qspi_write() {
	dev=${1}
	sizeB=${2}
	blockSize=${3:-1}

        tf1=$(mktemp)                                     
        tf1o=$(mktemp)                                    
	fld="0"        

                       
        echo "#########################################"                                                    
        echo "# E/W/R: Bytes: ${sizeB} to SPI-NOR BS: ${blockSize}"
        echo "# Dev: /dev/mtd${dev}"
	vybryd_test_qspi_erase ${dev} ${sizeB}        
                                                                                     
        head -c ${sizeB} /dev/urandom > ${tf1}                                                                           
        tf1_sum=$(md5sum ${tf1} | cut -f1 -d ' ')                                                                      

        # Introduce errors if needed                                                                                   
        # hexdump ${tf1}                                                                                               
        # echo -ne \\xDD | dd conv=notrunc bs=1 count=1 of=${tf1}                                                      
        # hexdump ${tf1}                                                                                               
        
	dd if=${tf1} of=/dev/mtd${dev} oflag=sync > /dev/null 2>&1
	sync
	sleep 0.5 
	dd if=/dev/mtd${dev} of=${tf1o} bs=${blockSize} count=$((${sizeB}/${blockSize})) oflag=sync > /dev/null 2>&1
	sync                 
                                                                                  
        echo "${tf1_sum} ${tf1o}" | md5sum -c --quiet -                     
        ret=$?                                                              
	# hexdump ${tf1o}
        echo -n "SPI WRITE: " 
        [ ${ret} -eq 0 ] && { echo "  OK"; } || { echo "  FAILED"; fld="1";}
                                                                           
        rm ${tf1} ${tf1o}
                                        
        [ ${fld} -eq 1 ] && exit 0
}

vybryd_test_qspi_erase() {
	dev=${1}
	sizeB=${2}

	sizeKiB=$((${sizeB}/1024))
	eraseCNT=$((((${sizeKiB}+3)/64)+1))

	echo "# Erase ${sizeB} [${sizeKiB}] -> cnt: ${eraseCNT}"
	flash_erase /dev/mtd${dev} 0 ${eraseCNT}
}

[ -c "/dev/mtd${device}" ] || { echo "Device /dev/mtd${device} not found!"; exit 0;}

for i in $(seq 1 ${count} );
do	
	echo "******************************************"
	echo "* count: ${i}/${count}"
	vybryd_test_qspi_write ${device} 1 
	vybryd_test_qspi_write ${device} 64
	vybryd_test_qspi_write ${device} 256
	vybryd_test_qspi_write ${device} 1024 64
	vybryd_test_qspi_write ${device} 1024 1024
	vybryd_test_qspi_write ${device} 1025
	vybryd_test_qspi_write ${device} 8192 1024
	vybryd_test_qspi_write ${device} 65536 1024
	vybryd_test_qspi_write ${device} 1048576 1024
	vybryd_test_qspi_write ${device} 5242880 1024
	vybryd_test_qspi_write ${device} 1023
	vybryd_test_qspi_write ${device} 5242880 4096
	vybryd_test_qspi_write ${device} 1024 1
done

exit 0

