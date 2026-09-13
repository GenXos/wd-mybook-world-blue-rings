# WD My Book World Edition II Recovery Procedure

## Purpose

This document records the recovery of a Western Digital My Book World
Edition II (Blue Rings) NAS after failure of one original hard drive
and a subsequent firmware 02.00.18 thermal-shutdown problem.

The objective is to preserve enough information to reproduce the
recovery if this NAS needs to be repaired or rebuilt again.

This is a record of the procedure used on this specific unit. Commands
that write directly to disks or RAID filesystems should not be applied
blindly to another system.

## Final Working Configuration

At the completion of recovery:

- NAS: Western Digital My Book World Edition II (Blue Rings)
- Model: WD10000D033 / WDG2NC10000
- Firmware: 02.00.18
- Drive type: Linear
- Drive A: WD5000AAVS-00ZTB0
- Drive B: Toshiba DT01ACA050
- Both drives: 500,107,862,016 bytes
- Both drives: 976,773,168 logical sectors
- Drive Status: OK
- Network: Gigabit Ethernet
- NAS IP during recovery: 192.168.2.144
- File sharing protocol: SMB1 / NT1
- Media shares: MOVIES and TVSHOWS
- Media server: Plex Media Server on Mac mini
- Plex clients successfully see the NAS-hosted libraries

The Toshiba replacement requires the patched firmware 02.00.18
`heat-monitor` described in `thermal-shutdown-bug.md`.

## Initial Condition

The NAS originally contained two Western Digital drives:

    WD5000AAVS-00ZTB0

Each original disk has an exact capacity of:

    500,107,862,016 bytes
    976,773,168 sectors
    512 bytes per logical sector

The NAS was configured as a linear volume.

The original Drive B failed. When connected through a known-good,
externally powered SATA-to-USB adapter, the disk would not spin and
Linux reported no usable media.

A control disk and the surviving original Drive A worked through the
same adapter.

Data preservation was not required, so the objective became restoring
the NAS to reliable operation rather than recovering the old data.

## Replacement-Drive Investigation

A nominal 500 GB Western Digital replacement was initially obtained:

    WDC WD5000AAKX-75U6AA0

SMART testing showed that this disk was healthy.

However, its actual capacity was:

    499,570,991,104 bytes
    975,724,592 sectors

This is:

    1,048,576 sectors
    512 MiB

smaller than the original WD5000AAVS.

The NAS did not accept this disk as a valid replacement even after the
existing partition information was removed.

Inspection of the original partition geometry explained the problem.
The final data partition extends close to the end of the original
976,773,168-sector disk, so the smaller WD5000AAKX cannot contain the
original layout.

The important lesson is:

> Do not select a replacement for this NAS solely by its advertised
> capacity. Verify its exact logical sector count.

Further details are recorded in `hardware.md`.

## Successful Replacement Drive

A Toshiba DT01ACA050 was subsequently obtained.

Its capacity is:

    500,107,862,016 bytes
    976,773,168 sectors

This is an exact LBA-capacity match for the original WD5000AAVS.

SMART testing showed:

- Overall SMART status: PASSED
- Reallocated sectors: 0
- Pending sectors: 0
- Offline uncorrectable sectors: 0
- Interface CRC errors: 0
- Extended SMART test: completed without error

Existing NTFS/MBR information on the Toshiba was intentionally removed
because preservation of its previous contents was not required.

The Toshiba was installed as Drive B while the surviving original
WD5000AAVS remained in Drive A.

The NAS recognized the replacement.

## Reinitializing Storage

The storage volume was formatted using the NAS web interface.

After initialization and synchronization, the system reported
approximately:

    Total Space:      953,454,724K
    Available Space:  953,323,496K
    Percentage Free:  99%

Drive Status eventually reported:

    OK

At this stage the NAS was operational on its original firmware:

    01.01.18

The replacement-drive problem was therefore considered resolved before
attempting the firmware upgrade.

## Firmware 02.00.18

The firmware selected for the Blue Rings NAS was:

    wdgxnc-02.00.18.wdg

The package used during this recovery was obtained from Western
Digital's official download infrastructure:

https://download.wdc.com/nas/wdgxnc-02.00.18.wdg

Size:

    48,549,415 bytes

SHA-256:

    7e9dc3a63c18cd2fa3cb1d3dceb9b2761c2ded1fa62bc78955677e3d0ac61c25

MD5:

    e2d56542584d7484270438c6f53d0e85

The firmware package is a self-extracting shell archive containing,
among other components:

    rootfs.ext2
    uImage
    uImage.1
    u-boot.bin
    stage1.bin
    upgrade1.sh
    upgrade1-xdelta.sh
    upgrade2.sh
    uUpgradeRootfs

The package metadata identifies the root filesystem version as:

    ROOTFSVERSION=02.00.18

## Local Firmware Server

The NAS firmware interface normally obtains update information from a
Western Digital server.

To make the downloaded 02.00.18 package available locally during
recovery, a simple firmware server was run on the LMDE workstation.

During recovery:

    LMDE workstation: 192.168.2.27
    NAS:              192.168.2.144
    Gateway:          192.168.2.1

The local server supplied:

    list.asp
    wdgxnc-02.00.18.wdg

The NAS successfully requested:

    GET /list.asp?type=wdg2nc&fw=01.01.18
    GET /wdgxnc-02.00.18.wdg

The web interface then proceeded to the firmware application stage and
rebooted the NAS.

## Apparent Firmware Upgrade Failure

After the upgrade, the NAS initially appeared to have failed badly.

Observed symptoms included:

- Web interface unavailable
- No response to ping
- No NAS entry visible through normal network discovery
- Ethernet port lights absent during the fault state
- Inner and outer blue rings flashing simultaneously
- Fan running at high speed

The NAS remained in this condition long enough that the upgrade
initially appeared to have failed or left the unit unbootable.

A controlled power cycle did not permanently resolve the behavior.

Because the firmware package contained bootloader, kernel, initrd, and
root filesystem components, further blind firmware writes were avoided.

The next step was direct read-only inspection of the system disks.

## Firmware Upgrade Architecture

Inspection of the 02.00.18 upgrade scripts showed that the first-stage
upgrade writes boot components to raw disk locations on both drives.

Important values from `upgrade1.sh` include:

    STAGE1_START=1
    UPGRADE_FLAG_OFFSET=63
    UBOOT_START=64
    KERNEL_START=300
    INITRD_START=6000
    INITK_START=6512

Backup locations are also used for several components.

For the two-drive model, the script:

1. Checks the system RAID arrays.
2. Checks the filesystem used for persistent `/var` data.
3. Preserves the pending root filesystem image.
4. Writes stage1, U-Boot, upgrade initrd, and upgrade kernel.
5. Sets an upgrade flag at raw sector 63 on both disks.
6. Reboots.

The dedicated upgrade environment then:

1. Mounts the persistent system volume.
2. Prepares the new root filesystem.
3. Formats the root RAID filesystem.
4. Copies the new root filesystem into it.
5. Writes the normal kernel.
6. Clears the raw upgrade flag.
7. Reboots into the installed firmware.

This information made sector 63 and the system RAID filesystems useful
indicators of how far the upgrade had progressed.

## Read-Only Disk Investigation

The surviving original Drive A was removed and attached to the LMDE
workstation.

Its partition table remained intact:

| Partition | Start | End | Sectors | Approx. Size |
|---|---:|---:|---:|---:|
| 1 | 48,195 | 5,927,984 | 5,879,790 | 2.8 GiB |
| 2 | 5,927,985 | 6,136,829 | 208,845 | 102 MiB |
| 3 | 6,136,830 | 8,112,824 | 1,975,995 | 964.8 MiB |
| 4 | 8,112,825 | 976,768,064 | 968,655,240 | 461.9 GiB |

The first three partitions contained Linux RAID1 metadata.

The fourth partition belonged to the linear data volume.

The raw upgrade flag at sector 63 contained zeros.

This was significant because the upgrade environment clears that flag
near the end of the dedicated upgrade process.

The evidence therefore indicated that the upgrade had progressed much
further than the front-panel symptoms suggested.

## Root Filesystem Evidence

The root filesystem on partition 1 was inspected read-only.

It was a clean ext3 filesystem containing the expected installed
02.00.18 system tree.

The persistent system partition corresponding to partition 3 was also
inspected read-only.

It contained the firmware installation state and saved upgrade
components.

Most importantly:

    /var/lib/current-version

contained:

    02.00.18

The upgrade log also contained an entry equivalent to:

    02.00.18:...:upgrade complete

The upgrade directory contained only the completion marker:

    fwinstalled

Saved firmware components were present under `/var/lib`, including:

    rootfs.ext2
    stage1.bin
    u-boot.bin
    uImage
    uImage.1
    uUpgradeRootfs
    md5sum.lst

These findings established that firmware 02.00.18 had actually been
installed successfully.

## Boot Log Evidence

System logs provided further confirmation.

During normal boots after the upgrade:

- The new root filesystem mounted.
- The kernel continued into normal userspace.
- Ethernet hardware initialized.
- The Ethernet link negotiated at 1000 Mb/s full duplex.

The system therefore was not failing during bootloader execution,
kernel startup, or Ethernet-driver initialization.

Instead, several boots showed a striking pattern.

After approximately four minutes, init started:

    /etc/init.d/rcK

The system then performed its normal shutdown sequence.

Two particularly useful observations were approximately:

    Boot -> about 4 minutes -> rcK -> orderly shutdown
    Boot -> about 4 minutes -> rcK -> orderly shutdown

This changed the diagnosis substantially.

The NAS was not crashing.

Something in normal userspace was deliberately asking BusyBox init to
shut the system down.

## Investigating the Four-Minute Shutdown

The repeatable timing and high-speed fan suggested that the shutdown
might be related to thermal monitoring.

Firmware inspection identified:

    /usr/local/wdc/heat-monitor

Strings in the binary included references to:

    WD NetCenter/2NC Temperature Monitor
    /usr/local/wdc/overtemp-poweroff
    /sys/devices/platform/wdc-fan/speed
    /sys/class/leds/wdc-leds:over-temp/brightness

The program therefore directly controlled the fan and over-temperature
LED state and contained an over-temperature shutdown path.

Reverse engineering this binary ultimately identified the root cause
of the recovery problem.

## Root Cause: SMART Attribute 194

The original Western Digital drive reports SMART attribute 194 as:

    0x000000000022

Interpreted as the six raw bytes examined by the firmware:

    22 00 00 00 00 00

The first byte represents:

    0x22 = 34 degrees C

All remaining raw bytes are zero.

The Toshiba DT01ACA050 instead reports:

    0x003400060016

The six raw bytes are:

    16 00 06 00 34 00

Its actual temperature is represented by the first byte:

    0x16 = 22 degrees C

The additional nonzero bytes are legitimate data supplied by the
Toshiba drive.

Reverse engineering showed that the WD `heat-monitor` parser accepts
the first raw byte as the temperature only if all five remaining raw
bytes are zero.

Its effective logic is:

```c
if (attribute.id == 194) {
    temperature = attribute.raw[0];

    if (attribute.raw[1] ||
        attribute.raw[2] ||
        attribute.raw[3] ||
        attribute.raw[4] ||
        attribute.raw[5]) {
        temperature = 255;
    }
}
```

Consequently, the Toshiba's legitimate SMART encoding causes the
firmware to substitute:

    255 degrees C

The drive itself was not overheating.

This false value causes the firmware thermal state machine to enter
its emergency state.

A detailed analysis is preserved in:

    docs/thermal-shutdown-bug.md

## Explaining the Four-Minute Interval

Disassembly of `heat-monitor` showed that its main polling loop uses:

    sleep(248)

The interval is therefore:

    248 seconds
    4 minutes 8 seconds

This closely matched the observed repeatable interval between normal
boot and thermal shutdown.

The timing provided additional confirmation that `heat-monitor` was
responsible for the behavior.

## Thermal Shutdown Mechanism

When the thermal state machine reaches its emergency state,
`heat-monitor`:

1. Sets the fan to 100 percent.
2. Activates the over-temperature LED state.
3. Attempts to execute `/usr/local/wdc/overtemp-poweroff`.
4. Sends SIGUSR2 to PID 1.

The helper `/usr/local/wdc/overtemp-poweroff` was not present in the
inspected filesystem, but failure to execute it does not prevent the
subsequent shutdown.

The signal sent to PID 1 causes BusyBox init to execute its configured
shutdown actions, including:

    /etc/init.d/rcK

This explains all major observed symptoms:

- Approximately four-minute runtime
- Fan at high speed
- Over-temperature LED indication
- Clean `rcK` shutdown
- Loss of network connectivity after shutdown

## Creating the Minimal Patch

The correction was intentionally kept as small as possible.

The objective was not to disable fan control, temperature monitoring,
or the thermal shutdown state machine.

Instead, the patch prevents the SMART parser from replacing the first
raw temperature byte with 255 merely because the remaining raw bytes
contain nonzero data.

Original instruction:

    Virtual address: 0x9364
    File offset:     0x1364

    0x0A000002    beq 0x9374

Patched instruction:

    0xEA000002    b 0x9374

This changes a conditional branch into an unconditional branch.

The actual binary change is one byte at file offset:

    0x1367

Original:

    0x0A

Patched:

    0xEA

The Western Digital binaries are not distributed by this repository.

A reproducible utility for creating the corrected binary from a
user-supplied copy of the known original is provided as:

    patches/patch-heat-monitor.sh

Original SHA-256:

    901cdf88cdbecff23920ed141361f3d1ed7994c3268febf6d84bfa91bc165fa4

Patched SHA-256:

    7cf731288c4f55b8ca4babbf716958c31ff1ad42e1cd139e09cc4b17a805c10e

A byte-by-byte comparison produces exactly one difference:

    4968  12 352

Because `cmp -l` uses one-based positions and octal byte values, this
corresponds exactly to:

    offset 0x1367
    0x0A -> 0xEA

## Safe Installation Through the RAID Layer

The NAS root filesystems are RAID1.

Directly modifying an individual ext3 RAID member while bypassing the
RAID layer was avoided.

For each drive, the procedure was:

1. Attach only the drive being serviced to the LMDE workstation.
2. Identify the correct disk and partition.
3. Examine its RAID metadata.
4. Stop any automatically created inactive md device if necessary.
5. Assemble the root RAID member as a degraded RAID1 array.
6. Check the assembled filesystem read-only with `e2fsck -fn`.
7. Mount the assembled md device read/write.
8. Install the patched binary.
9. Verify its checksum and permissions.
10. Unmount the filesystem cleanly.
11. Stop the temporary md array.
12. Synchronize pending writes before disconnecting the disk.

The root partition was partition 1 on each disk.

A representative degraded assembly was:

    sudo mdadm --assemble --run /dev/md1 /dev/sdX1

Before making changes, the filesystem was checked with:

    sudo e2fsck -fn /dev/md1

The assembled ext3 filesystem was then mounted through `/dev/md1`,
rather than mounting `/dev/sdX1` directly for writing.

The patched binary was installed with root ownership and executable
permissions:

    sudo install -o root -g root -m 755 \
      /tmp/heat-monitor.patched \
      /mount/path/usr/local/wdc/heat-monitor

The installed file was then verified against the known patched
SHA-256 before unmounting.

## Both RAID Members Must Be Patched

Drive B, the Toshiba replacement, was patched first.

After the NAS was reassembled, an initially confusing test occurred
because the Drive B SATA connection had become physically loose.
After the cable was reseated and both drives were participating again,
the NAS could still enter the false thermal shutdown state.

Inspection of original Drive A showed that its copy of `heat-monitor`
still had the original SHA-256.

This demonstrated an important practical requirement:

> Both RAID1 root filesystem members must contain the patched binary.

Drive A was then serviced using the same degraded-RAID procedure.

Its original `heat-monitor` was verified before replacement, and the
same known-good patched binary was installed.

After installation, both root RAID members contained:

    7cf731288c4f55b8ca4babbf716958c31ff1ad42e1cd139e09cc4b17a805c10e

The disks were then reinstalled securely in the NAS.

## Successful Boot

With both drives securely installed and both root RAID members
containing the patched `heat-monitor`, the NAS booted normally.

The web interface reported:

    Device Name: MyBookWorld
    Firmware:    02.00.18
    Drive Status: OK

The internal storage volume was available and reported approximately:

    Total Space:      953,454,724K
    Available Space:  953,323,488K
    Percentage Free:  99%

Network status showed:

    Speed:   1000 Mb/s
    IP:      192.168.2.144
    Gateway: 192.168.2.1

Most importantly, the system remained operational beyond the previous
248-second thermal-monitor interval.

The fan did not enter the false emergency state, the over-temperature
LED condition did not recur, and the NAS no longer performed the
four-minute shutdown.

This confirmed the thermal-monitor patch as the effective correction.

## SMB Functional Testing

The NAS uses the legacy SMB1 / NT1 protocol.

A modern LMDE Samba client initially rejected negotiation because its
default minimum protocol was newer than NT1.

Rather than weakening the client configuration globally, SMB1 was
enabled for individual test commands.

Share enumeration was performed with:

    smbclient -L //192.168.2.144 -N \
      --option='client min protocol=NT1' \
      --option='client max protocol=NT1'

The NAS successfully advertised its shares.

A dedicated test share named `TEST` was created through the NAS web
interface with full access for Everyone.

The share was opened with:

    smbclient //192.168.2.144/TEST -N \
      --option='client min protocol=NT1' \
      --option='client max protocol=NT1'

A small local file was uploaded:

    put /etc/hostname hostname-test.txt

The directory listing showed the uploaded file on the NAS.

The file was then downloaded again:

    get hostname-test.txt /tmp/hostname-from-nas.txt

On LMDE, the retrieved file was compared against the original:

    cmp /tmp/hostname-from-nas.txt /etc/hostname

`cmp` produced no output.

This verified a complete byte-for-byte SMB round trip:

    LMDE -> NAS -> LMDE

Therefore:

- SMB share discovery works.
- Directory listing works.
- NAS writes work.
- NAS reads work.
- File contents are preserved correctly.
- The data volume is functional.

## Production Media Shares

After the functional test, two dedicated media shares were created:

    MOVIES
    TVSHOWS

Both reside on the NAS `Main` volume.

These shares provide a cleaner media-server layout than storing the
libraries under the general `PUBLIC` share.

## Mac mini and Plex Validation

The Mac mini is used as the Plex Media Server host.

The `MOVIES` and `TVSHOWS` NAS shares were successfully mounted on the
Mac mini.

Mount persistence was tested across a Mac mini reboot and confirmed
working.

The mounted shares were then added to Plex Media Server as media
library locations.

Plex successfully discovered the new libraries.

The Plex client on Apple TV subsequently displayed the new NAS-hosted
libraries.

This provided an end-to-end functional validation:

    NAS storage
        ->
    SMB network shares
        ->
    persistent Mac mini mounts
        ->
    Plex Media Server
        ->
    Apple TV Plex client

At this point the primary NAS recovery objective was complete.

## Known Remaining Issue: Date and Time Interface

Firmware 02.00.18 contains an obsolete date-selection interface.

The web interface year selector only extends through:

    2020

During testing, use of this interface changed the NAS date to 2020.

As a result, files created through the NAS may currently receive
incorrect 2020 timestamps.

This issue is independent of the disk recovery and thermal-monitor
repair.

Do not repeatedly adjust the date through the existing web interface
until its implementation has been investigated.

A future recovery task should inspect the firmware web-interface code
for the hard-coded year limit and determine whether it can be safely
extended.

## Important Future Recovery Notes

### Preserve the Patched Thermal Monitor

Stock firmware 02.00.18 contains the incompatible original
`heat-monitor`.

A firmware reinstall or root filesystem restoration may therefore
restore the thermal-shutdown bug.

After any system restoration, verify:

    /usr/local/wdc/heat-monitor

Expected patched SHA-256:

    7cf731288c4f55b8ca4babbf716958c31ff1ad42e1cd139e09cc4b17a805c10e

Both RAID1 root members should contain this version.

### Verify Replacement Disk Geometry

Do not assume that another disk marketed as 500 GB is large enough.

The original disk geometry requires at least:

    500,107,862,016 bytes
    976,773,168 logical 512-byte sectors

Verify exact capacity before purchasing or installing another
replacement.

### SMB1 Security

This NAS uses SMB1 / NT1, which is obsolete and lacks the security
properties of modern SMB versions.

The NAS should remain on a trusted local network and should not be
directly exposed to the Internet.

Where possible, SMB1 compatibility should be limited specifically to
this NAS rather than enabled globally for unrelated network services.

### Avoid Blind Firmware Recovery Writes

The apparent post-upgrade failure initially resembled a failed
firmware installation.

Disk inspection proved that 02.00.18 had actually installed and
booted successfully.

If similar symptoms recur, inspect the upgrade state, system
filesystems, logs, and `heat-monitor` before rewriting boot sectors or
system partitions.

## Recovery Materials and Reproducibility

Western Digital firmware and extracted firmware binaries are not
distributed by this repository.

The exact firmware package used during this recovery is identified by
its filename and cryptographic hashes earlier in this document. The
top-level `README.md` also records the Western Digital download source.

The thermal-monitor correction can be independently reproduced from a
user-supplied copy of the known original binary using:

    patches/patch-heat-monitor.sh

The utility verifies the original SHA-256 and expected byte before
patching, creates a separate output file, and verifies the resulting
SHA-256 afterward.

Additional documentation is provided in:

    docs/hardware.md
    docs/thermal-shutdown-bug.md
    patches/README.md

Together, these materials document the hardware requirements,
firmware failure analysis, binary correction, and recovery procedure
without redistributing Western Digital firmware or extracted
proprietary binaries.

## Recovery Outcome

The recovery progressed through several distinct problems:

1. Original Drive B hardware failure.
2. Discovery that a nominal 500 GB replacement was physically too
   small for the original partition geometry.
3. Installation of an exact-capacity Toshiba replacement.
4. Successful upgrade from firmware 01.01.18 to 02.00.18.
5. Investigation of an apparent post-upgrade failure.
6. Proof that the firmware installation and normal boot had actually
   succeeded.
7. Identification of a repeatable 248-second thermal shutdown.
8. Reverse engineering of the SMART attribute 194 parser.
9. Identification of the Toshiba/WD SMART encoding incompatibility.
10. Creation and verification of a one-byte `heat-monitor` patch.
11. Installation of the patch on both RAID1 root filesystem members.
12. Successful stable boot with both drives reporting OK.
13. Successful SMB read/write integrity testing.
14. Persistent mounting of the media shares on the Mac mini.
15. Successful Plex Media Server and Apple TV validation.

The WD My Book World Edition II is therefore restored to useful
service with firmware 02.00.18 and the documented thermal-monitor
correction.
