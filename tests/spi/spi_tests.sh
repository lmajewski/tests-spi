#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0+
#
# (C) Copyright 2018
# Lukasz Majewski, DENX Software Engineering, lukma@denx.de.
#
#

SPI_FSL_MOD="spi_fsl_dspi"
SPI_MASTER="0"
SPI_SLAVE="3"

lsmod | grep -q ${SPI_FSL_MOD}
[ $? -ne 0 ] && insmod ./spi-fsl-dspi.ko

command -v ./spidev_test || { echo "./spidev_test not accessible !"; exit 0; }

while getopts ":dms" opt; do
	case $opt in
	d)
		echo "DEBUG mode" >&2
		DBG="-v"
	;;
	s)
		echo "Test SLAVE communication" >&2
		RUN_SLAVE="1"
	;;
	m)
		echo "Test MASTER loopback (single port)" >&2
		RUN_MASTER_LOOP="1"
	;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		exit 0
	;;
	esac
done

vybryd_test_master_loopback() {
	tf1=$(mktemp)
	tf1o=$(mktemp)
	fld="0"
	CNT=${1}
	BPW=${2:-8}

	echo "#########################################"
	echo "# Loopback in SPI: CNT: ${CNT}"
	echo "# MASTER: ${SPI_MASTER}"

	head -c ${CNT} /dev/urandom > ${tf1}
	tf1_sum=$(md5sum ${tf1} | cut -f1 -d ' ')
	# Introduce errors if needed
	# hexdump ${tf1}
	# echo -ne \\xDD | dd conv=notrunc bs=1 count=1 of=${tf1}
	# hexdump ${tf1}
	./spidev_test ${DBG} -D /dev/spidev${SPI_MASTER}.0 -s 3000000 -H -b 8 -i ${tf1} -o ${tf1o}
	echo "${tf1_sum} ${tf1o}" | md5sum -c --quiet -
	ret=$?
	# hexdump ${tf1o}
	echo -n "MASTER LOOPBACK:"
	[ ${ret} -eq 0 ] && { echo "  OK"; } || { echo "  FAILED"; fld="1";}

	rm ${tf1} ${tf1o}

	[ ${fld} -eq 1 ] && exit 0
}

vybryd_test_master_slave() {
	tf1=$(mktemp)
	tf1o=$(mktemp)

	tf2=$(mktemp)
	tf2o=$(mktemp)
	fld="0"
	CNT=${1}
	BPW=${2:-8}

	echo "#########################################"
	echo "# Send/Receive ${CNT}B in SPI:"
	echo "# MASTER: ${SPI_MASTER} SLAVE: ${SPI_SLAVE}"

	head -c ${CNT} /dev/urandom > ${tf1}
	head -c ${CNT} /dev/urandom > ${tf2}

	tf1_sum=$(md5sum ${tf1} | cut -f1 -d ' ')
	tf2_sum=$(md5sum ${tf2} | cut -f1 -d ' ')

	# Introduce errors if needed
	# hexdump ${tf1}
	# echo -ne \\xDD | dd conv=notrunc bs=1 count=1 of=${tf1}
	# hexdump ${tf1}

	( ./spidev_test ${DBG} -D /dev/spidev${SPI_SLAVE}.0 -s 3000000 -H -b ${BPW} -i ${tf2} -o ${tf1o} ) &
	rcpid=$!
	sleep 0.2

	kill -0 ${rcpid} > /dev/null 2>&1
	[ $? -eq 0 ] && ./spidev_test ${DBG} -D /dev/spidev${SPI_MASTER}.0 -s 3000000 -H -b ${BPW} -i ${tf1} -o ${tf2o}

	wait ${rcpid}
	( kill -SIGTERM ${rcpid} 2> /dev/null )

	echo "${tf1_sum} ${tf1o}" | md5sum -c --quiet -
	ret=$?
	echo -n "MASTER -> SLAVE:"
	[ ${ret} -eq 0 ] && { echo "  OK"; } || { echo "  FAILED"; fld="1";}

	echo "${tf2_sum} ${tf2o}" | md5sum -c --quiet -
	ret=$?
	echo -n "SLAVE  -> MASTER:"
	[ ${ret} -eq 0 ] && { echo " OK"; } || { echo " FAILED"; fld="1"; }

	rm ${tf1} ${tf2} ${tf1o} ${tf2o}

	[ ${fld} -eq 1 ] && exit 0
}

if [ "${RUN_MASTER_LOOP}" == "1" ]; then
	vybryd_test_master_loopback 1 8
	vybryd_test_master_loopback 32 8
	vybryd_test_master_loopback 11 8
	vybryd_test_master_loopback 1024 8
	vybryd_test_master_loopback 1240 8
fi

if [ "${RUN_SLAVE}" == "1" ]; then
	# Serialized tests
	vybryd_test_master_slave 32 8
	vybryd_test_master_slave 1 8
	vybryd_test_master_slave 4 8
	vybryd_test_master_slave 35 8
	vybryd_test_master_slave 1024 8
	vybryd_test_master_slave 32 16
	vybryd_test_master_slave 1024 16

	for i in $(seq 1 10);
	do
		vybryd_test_master_slave $(shuf -i1-1024 -n1) 8
	done
fi

exit 0
