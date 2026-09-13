# Firmware 02.00.18 False Thermal Shutdown

## Summary

Western Digital My Book World Edition II (Blue Rings) firmware
02.00.18 contains a restrictive SMART temperature parser in:

    /usr/local/wdc/heat-monitor

When used with a Toshiba DT01ACA050 replacement drive, the program
incorrectly interprets the drive's valid SMART attribute 194 raw
encoding as an invalid temperature and substitutes 255 degrees C.

This triggers the firmware's genuine over-temperature protection:

1. Fan is set to 100%.
2. Over-temperature LEDs are activated.
3. SIGUSR2 is sent to PID 1 (BusyBox init).
4. init executes the normal rcK shutdown sequence.
5. The NAS powers down.

The resulting shutdown therefore appears orderly in the system logs.
The Toshiba drive itself is healthy and is not actually overheating.

## Observed Symptom

After upgrading the NAS from firmware 01.01.18 to 02.00.18:

- The NAS boots normally.
- Ethernet initializes successfully.
- The system operates for approximately four minutes.
- The fan increases to full speed.
- Both blue rings indicate the thermal fault state.
- The system performs an orderly shutdown.

The behavior was repeatable.

The firmware upgrade itself completed successfully. Evidence on the
system partitions confirmed:

    /var/lib/current-version = 02.00.18

and the upgrade log recorded:

    upgrade complete

The failure therefore occurred after a successful normal boot of
02.00.18 rather than during firmware installation.

## Temperature Monitor

Firmware 02.00.18 contains:

    /usr/local/wdc/heat-monitor

The original binary is 11,344 bytes.

SHA-256:

    901cdf88cdbecff23920ed141361f3d1ed7994c3268febf6d84bfa91bc165fa4

The original binary is not distributed by this repository.

## SMART Attribute 194 Parsing

Reverse engineering showed that `heat-monitor` searches the SMART
attribute table for attribute 194 (`Temperature_Celsius`).

For attribute 194 it effectively performs:

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

This assumes that only the first byte of SMART `RAW_VALUE` contains
useful data and that all five remaining bytes must be zero.

That assumption is valid for the original Western Digital drive but
not for the Toshiba replacement.

## Original Western Digital Drive

The original WD5000AAVS reports SMART attribute 194 as:

    194 Temperature_Celsius ... 0x000000000022

The six raw bytes interpreted in little-endian order are:

    22 00 00 00 00 00

Therefore:

    raw[0] = 0x22 = 34 degrees C
    raw[1..5] = 0

The WD firmware accepts this value normally.

## Toshiba DT01ACA050

The Toshiba replacement reports:

    194 Temperature_Celsius ... 0x003400060016

The six raw bytes interpreted by the firmware are:

    16 00 06 00 34 00

Therefore:

    raw[0] = 0x16 = 22 degrees C

The actual temperature is a normal 22 degrees C.

However, the Toshiba legitimately places additional information in
other bytes of SMART attribute 194. Nonzero values therefore appear
in the upper raw bytes.

The original WD parser consequently changes the result to:

    255 degrees C

This is the direct cause of the false thermal shutdown.

## Thermal State Machine

Reverse engineering of `heat-monitor` revealed a hysteretic thermal
state machine.

The approximate transitions are:

- State 0:
  - <= 54 C: remain in state 0
  - > 54 C: state 1

- State 1:
  - <= 49 C: state 0
  - 50-64 C: remain in state 1
  - > 64 C: state 2

- State 2:
  - <= 54 C: state 1
  - 55-69 C: remain in state 2
  - > 69 C: state 3

- State 3:
  - <= 59 C: state 2
  - > 59 C: state 4

A resulting state greater than 3 invokes the shutdown path.

A false temperature of 255 C therefore advances the monitor into the
over-temperature shutdown condition.

## Shutdown Path

The over-temperature routine attempts to execute:

    /usr/local/wdc/overtemp-poweroff

That helper is absent from the inspected firmware filesystem.

Failure to execute the helper does not prevent shutdown.

The parent `heat-monitor` process subsequently:

1. Activates the over-temperature LED indicator.
2. Sends signal 12 (`SIGUSR2`) to PID 1.

Conceptually:

    kill(1, SIGUSR2)

BusyBox init then invokes the normal shutdown actions defined in
`/etc/inittab`, including:

    ::shutdown:/etc/init.d/rcK
    ::shutdown:/bin/sync
    ::shutdown:/usr/bin/killall klogd
    ::shutdown:/usr/bin/killall syslogd
    ::shutdown:/sbin/swapoff -a
    ::shutdown:/bin/umount -a -r

This explains why the logs showed a clean `rcK` shutdown rather than
a kernel crash or abrupt power failure.

## 248-Second Timing

The `heat-monitor` main loop uses a polling interval of:

    248 seconds

which is:

    4 minutes 8 seconds

The monitor checks the drive temperature and then sleeps for this
interval before repeating.

This closely matches the observed repeatable shutdown approximately
four minutes after boot.

## Patch Strategy

The minimal correction for this incompatibility is to retain the
first raw temperature byte while preventing the parser from replacing
it with 255 solely because `raw[1..5]` contain nonzero data.

The relevant original ARM instruction is:

    Virtual address: 0x9364
    File offset:     0x1364

Original instruction:

    0x0A000002    beq 0x9374

Patched instruction:

    0xEA000002    b 0x9374

The conditional branch is changed to an unconditional branch so the
block that stores 255 is always skipped.

The actual binary modification consists of exactly one byte.

At file offset:

    0x1367

change:

    0x0A -> 0xEA

## Binary Verification

Original bytes around file offset `0x1360`:

    00001360: 000053e3 0200000a 14201be5 ff30a0e3
    00001370: 003082e5 0130a0e3 20300be5 28321be5

Patched bytes:

    00001360: 000053e3 020000ea 14201be5 ff30a0e3

Disassembly of the patched instruction:

    9360: e3530000    cmp r3,#0
    9364: ea000002    b   0x9374

The original 255-degree block remains physically present but is
unconditionally bypassed.

## Patched Binary

The patched binary is not distributed by this repository.

A reproducible patch utility is provided in:

    patches/patch-heat-monitor.sh

SHA-256:

    7cf731288c4f55b8ca4babbf716958c31ff1ad42e1cd139e09cc4b17a805c10e

Comparison of the original and patched files produces exactly one
difference:

    4968  12 352

`cmp -l` reports byte positions starting at 1 and values in octal.

Therefore:

    position 4968 -> zero-based offset 0x1367
    octal 012     -> hexadecimal 0x0A
    octal 352     -> hexadecimal 0xEA

## Installation Requirement

The NAS has mirrored RAID1 system partitions.

The patched `heat-monitor` must be installed on BOTH root filesystem
members.

Patching only one drive is insufficient because the NAS may boot or
read the executable from the unpatched RAID member.

During this recovery:

- Toshiba Drive B was patched first.
- The NAS could still exhibit the thermal shutdown with both drives
  installed.
- Original WD Drive A was then patched identically.
- With both RAID1 root members containing the patched binary, the
  false thermal shutdown ceased.

## Important Warning

Reinstalling or restoring the stock 02.00.18 root filesystem may
restore the original `heat-monitor` binary and reintroduce the false
thermal shutdown.

After any firmware restoration, verify:

    /usr/local/wdc/heat-monitor

Expected patched SHA-256:

    7cf731288c4f55b8ca4babbf716958c31ff1ad42e1cd139e09cc4b17a805c10e

## Result

After installing the patched `heat-monitor` on both drives:

- Firmware 02.00.18 boots normally.
- Both drives are recognized.
- Drive Status reports OK.
- Gigabit Ethernet operates normally.
- The fan no longer enters the false emergency condition.
- The NAS remains running beyond the previous shutdown interval.
- SMB storage is functional.
- Read/write file integrity has been verified.
- The NAS is successfully serving media storage to Plex.

The patch does not disable the temperature state machine or fan
control. It corrects the incompatible interpretation of SMART
attribute 194 by using its first raw temperature byte rather than
forcing a 255-degree reading when the remaining raw bytes are nonzero.

## Recovery Configuration

The working configuration at the completion of recovery is:

- NAS: WD My Book World Edition II (Blue Rings)
- Firmware: 02.00.18
- Drive A: WD5000AAVS-00ZTB0
- Drive B: Toshiba DT01ACA050
- Drive status: OK
- Network link: 1000 Mb/s
- SMB protocol: SMB1 / NT1
- Media shares: `MOVIES` and `TVSHOWS`
- Media server host: Mac mini
- Plex Media Server successfully accesses both NAS shares
- Plex libraries are successfully available to Apple TV

## Reproducing the Correction

Western Digital firmware and extracted firmware binaries are not
distributed by this repository.

Firmware 02.00.18 must be obtained separately. The source and verified
firmware-package checksums used during this recovery are documented in
the top-level `README.md`.

The thermal-monitor correction can be reproduced from a user-supplied
copy of the known original `heat-monitor` binary using:

    patches/patch-heat-monitor.sh

The patch utility verifies the original binary before modifying a copy
and verifies the resulting SHA-256 afterward.

See:

    patches/README.md

for complete usage and verification instructions.
