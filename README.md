# WD My Book World Edition II (Blue Rings) Recovery

Recovery documentation and a reproducible firmware thermal-monitor fix for the
Western Digital **My Book World Edition II (Blue Rings)** NAS.

This repository documents the restoration of a WD10000D033 / WDG2NC10000
two-drive unit and a firmware 02.00.18 compatibility problem discovered while
using a replacement Toshiba hard drive.

The recovered NAS is operating successfully with firmware 02.00.18, both
drives healthy, Gigabit Ethernet, SMB storage, and Plex media service through
a Mac mini.

## What This Repository Covers

The recovery investigation includes:

- replacement-drive compatibility and exact disk geometry;
- installation and analysis of firmware 02.00.18;
- recovery after an apparent failed firmware upgrade;
- examination of the firmware boot and upgrade process;
- diagnosis of a repeatable shutdown approximately four minutes after boot;
- reverse engineering of the firmware `heat-monitor` program;
- identification of a SMART attribute 194 parsing incompatibility;
- a reproducible one-byte correction to `heat-monitor`;
- safe installation of the corrected binary on both root RAID1 members;
- SMB read/write validation and return to normal service.

The complete chronological procedure is in:

    docs/recovery-procedure.md

The technical analysis of the thermal issue is in:

    docs/thermal-shutdown-bug.md

Hardware and drive-geometry findings are in:

    docs/hardware.md

## Affected Hardware

The recovery was performed on:

    Western Digital My Book World Edition II
    Generation: Blue Rings
    Model: WD10000D033 / WDG2NC10000
    Original capacity: 1 TB
    Original drives: 2 x 500 GB
    Firmware: 01.01.18 --> 02.00.18

This repository should not be assumed to apply to later My Book World
generations merely because they have similar product names.

## Firmware 02.00.18 Thermal-Monitor Problem

The firmware contains:

    /usr/local/wdc/heat-monitor

During this recovery, a Toshiba DT01ACA050 replacement drive caused the NAS to
enter its thermal emergency state approximately four minutes after boot.

The drive itself was healthy and its actual temperature was normal.

The cause was traced to the firmware's interpretation of SMART attribute 194
(`Temperature_Celsius`).

The Toshiba drive reported the raw value:

    0x003400060016

The first raw byte contains the current temperature:

    0x16 = 22 C

However, the firmware checks the remaining bytes of the six-byte SMART raw
field. If any of them are nonzero, it substitutes:

    255 C

The Toshiba legitimately uses some of those additional bytes, so the firmware
incorrectly treats a normal drive as being at 255 C.

This causes the thermal state machine to:

1. set the fan to full speed;
2. activate the over-temperature LED indication;
3. signal BusyBox `init`;
4. perform an orderly shutdown.

The monitor's polling interval is:

    248 seconds

This accounts for the highly repeatable shutdown approximately four minutes
after boot.

## The Correction

The tested correction changes exactly one byte in the firmware 02.00.18
`heat-monitor` binary.

File offset:

    0x1367

Original byte:

    0x0A

Patched byte:

    0xEA

At the ARM instruction level this changes a conditional branch into an
unconditional branch, bypassing the erroneous code that substitutes 255 C
when the upper SMART raw bytes are nonzero.

The existing thermal state machine remains operational and continues to use
the temperature stored in the first SMART raw byte.

Known original `heat-monitor` SHA-256:

    901cdf88cdbecff23920ed141361f3d1ed7994c3268febf6d84bfa91bc165fa4

Known corrected `heat-monitor` SHA-256:

    7cf731288c4f55b8ca4babbf716958c31ff1ad42e1cd139e09cc4b17a805c10e

A reproducible patch utility is provided in:

    patches/patch-heat-monitor.sh

The utility verifies the original binary before modifying a copy and verifies
the resulting binary afterward.

See:

    patches/README.md

for usage and verification instructions.

## Obtaining Firmware 02.00.18

Western Digital firmware is **not distributed by this repository**.

The firmware package used during this recovery was obtained from Western
Digital's official download infrastructure:

[Western Digital firmware 02.00.18 download](https://download.wdc.com/nas/wdgxnc-02.00.18.wdg)

Package filename:

    wdgxnc-02.00.18.wdg

The exact package used during this recovery had:

SHA-256:

    7e9dc3a63c18cd2fa3cb1d3dceb9b2761c2ded1fa62bc78955677e3d0ac61c25

MD5:

    e2d56542584d7484270438c6f53d0e85

Verify the downloaded package before relying on the procedures documented
here.

The URL is provided for provenance and convenience. Availability remains
under Western Digital's control and may change in the future.

## Proprietary Files Are Not Included

This repository does **not** contain:

- Western Digital firmware packages;
- Western Digital `heat-monitor` binaries;
- extracted Western Digital root filesystems;
- bootloader or kernel images from the firmware.

Users must obtain the applicable firmware themselves.

The patch utility operates on a user-supplied copy of the known firmware
02.00.18 `heat-monitor` binary.

## Important: Both Root RAID Members

The NAS stores its system partitions using RAID1.

During testing, patching only one root RAID member was not sufficient. Once
both drives were installed, the system could execute the unmodified copy from
the other RAID member and the thermal shutdown returned.

For the documented recovery, the corrected `heat-monitor` was installed on
**both root RAID1 members**.

See the recovery procedure before modifying any NAS disk.

## Replacement-Drive Geometry

A nominal capacity such as "500 GB" does not guarantee that a replacement disk
is large enough for the original partition layout.

The original WD5000AAVS drives contain:

    976,773,168 sectors
    500,107,862,016 bytes

A WD5000AAKX-75U6AA0 tested during recovery contained:

    975,724,592 sectors
    499,570,991,104 bytes

It was:

    1,048,576 sectors
    512 MiB

smaller than the original disk and could not accommodate the existing
partition geometry.

The successful Toshiba DT01ACA050 replacement contained exactly:

    976,773,168 sectors
    500,107,862,016 bytes

See `docs/hardware.md` before selecting a replacement disk.

## SMB Security

This generation of My Book World uses SMB1/NT1.

SMB1 is obsolete and should not be exposed to untrusted networks.

The recovered NAS is intended for use on a trusted local network. Where
possible, enable legacy SMB compatibility only for connections to the NAS
rather than weakening SMB requirements system-wide.

Do not expose this NAS directly to the Internet.

## Known Remaining Issue

The firmware 02.00.18 web interface limits the selectable year in its
date/time configuration page to **2020**.

This does not prevent storage operation, but dates configured through the web
interface cannot currently be set correctly.

The limitation remains under investigation.

## Repository Layout

    .
    |-- docs/
    |   |-- hardware.md
    |   |-- recovery-procedure.md
    |   `-- thermal-shutdown-bug.md
    |
    |-- patches/
    |   |-- patch-heat-monitor.sh
    |   `-- README.md
    |
    |-- tools/
    |   `-- firmware-server/
    |       |-- list.asp
    |       `-- README.md
    |
    |-- .gitignore
    |-- LICENSE
    `-- README.md

## Recovery Result

The documented system was returned to normal operation with:

    Firmware 02.00.18
    Both drives detected
    Drive Status OK
    Thermal shutdown corrected
    Gigabit Ethernet operational
    SMB read/write verified
    Persistent Mac mini SMB mounts
    Plex libraries operational
    Apple TV media access operational

## Disclaimer

These procedures involve obsolete hardware, disk partitioning, Linux software
RAID, firmware files, and modification of an executable from the NAS
firmware.

A mistake can make the NAS unbootable or destroy data.

Read the complete documentation, verify device names and checksums, and keep
backups of anything important before modifying disks or firmware.

This project is independent and is not affiliated with or endorsed by
Western Digital.
