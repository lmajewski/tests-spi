Testing SPI-NOR memories (/dev/mtd6 and /dev/mtd7)
running on vf610 (Vybrid) on fsl-quadspi.c driver:
---------------------------------------------------

1. Testing the UBI/UBIFS writes:

./ubi_nand_tests.sh -d7 -m 1024 -c 1024 -u 1 -s && \
./ubi_nand_tests.sh -d7 -m 12 -c 100 -u 1 && \
./ubi_nand_tests.sh -d6 -m 1024 -c 1024 -s -u1 && \
./ubi_nand_tests.sh -d6 -m 12 -c 100 -u 1

2. Testing raw writes to MTD devices:

./spi_nor_quadspi_test.sh -d7 -c1   (or -d6)
