# Hardware

## NAS

- Product: Western Digital My Book World Edition II
- Generation: Blue Rings
- Model: WD10000D033 / WDG2NC10000
- Original capacity: 1 TB
- Drive bays: 2
- Original configuration: 2 × 500 GB SATA
- Drive type: Linear

## Original Drives

- Manufacturer: Western Digital
- Model: WD5000AAVS-00ZTB0
- Capacity: 500,107,862,016 bytes
- Logical sectors: 976,773,168
- Logical sector size: 512 bytes

Replacement drives must be large enough to accommodate the original
partition geometry. A drive marketed as "500 GB" is not necessarily
large enough.

## Drive A

- Model: WDC WD5000AAVS-00ZTB0
- Capacity: 500,107,862,016 bytes
- Logical sectors: 976,773,168
- Status: Working original drive

## Original Drive B

- Model: WD5000AAVS-00ZTB0
- Status: Failed
- Failure symptom: Would not spin when connected to a known-good
  powered SATA-to-USB adapter
- Data preservation was not required

## Rejected Replacement

- Model: WDC WD5000AAKX-75U6AA0
- Capacity: 499,570,991,104 bytes
- Logical sectors: 975,724,592
- SMART status: Healthy
- Result: Too small for the original NAS partition geometry

Although sold as a 500 GB drive, this disk is 1,048,576 sectors
(512 MiB) smaller than the original WD5000AAVS.

## Successful Replacement Drive B

- Manufacturer: Toshiba
- Model: DT01ACA050
- Additional Product ID: DELL(tm)
- Firmware: MS1OA7S0
- Capacity: 500,107,862,016 bytes
- Logical sectors: 976,773,168
- SMART status: PASSED
- Reallocated sectors: 0
- Pending sectors: 0
- Offline uncorrectable sectors: 0
- Interface CRC errors: 0

The Toshiba is an exact LBA-capacity match for the original
WD5000AAVS and was accepted by the NAS.

## Original Partition Geometry

The original 500 GB disks use an MBR partition table:

| Partition | Start | End | Sectors | Approx. Size | Type |
|---|---:|---:|---:|---:|---|
| 1 | 48,195 | 5,927,984 | 5,879,790 | 2.8 GiB | Linux RAID |
| 2 | 5,927,985 | 6,136,829 | 208,845 | 102 MiB | Linux RAID |
| 3 | 6,136,830 | 8,112,824 | 1,975,995 | 964.8 MiB | Linux RAID |
| 4 | 8,112,825 | 976,768,064 | 968,655,240 | 461.9 GiB | Linux RAID |

Partitions 1 through 3 are RAID1 system partitions. Partition 4 is
used for the linear data volume.

## Important Replacement-Drive Requirement

Do not select a replacement solely by its advertised capacity.

For this NAS and partition layout, use a disk with at least:

- 500,107,862,016 bytes
- 976,773,168 logical 512-byte sectors

An undersized nominal 500 GB disk may be healthy but still be
incompatible with the existing partition layout.
