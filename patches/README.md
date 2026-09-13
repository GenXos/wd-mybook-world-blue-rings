# heat-monitor Patch Utility

## Purpose

`patch-heat-monitor.sh` reproduces the tested firmware 02.00.18
`heat-monitor` correction used on this WD My Book World Edition II
(Blue Rings).

The script does not modify the source binary in place.

It:

1. Verifies the input SHA-256 against the known stock 02.00.18 binary.
2. Verifies the expected original byte at file offset `0x1367`.
3. Copies the source to a separate output file.
4. Changes exactly one byte:

       offset 0x1367: 0x0A -> 0xEA

5. Verifies the SHA-256 of the completed patched binary.
6. Deletes the generated output if final verification fails.

## Known Binary Hashes

Stock firmware 02.00.18 `heat-monitor`:

    901cdf88cdbecff23920ed141361f3d1ed7994c3268febf6d84bfa91bc165fa4

Patched `heat-monitor`:

    7cf731288c4f55b8ca4babbf716958c31ff1ad42e1cd139e09cc4b17a805c10e

## Usage

The original Western Digital `heat-monitor` binary is not distributed
by this repository. Supply a copy extracted from firmware 02.00.18
that you obtained separately.

From the repository root:

    patches/patch-heat-monitor.sh \
      /path/to/heat-monitor.original \
      /tmp/heat-monitor.generated

The script first verifies that the supplied binary has the known
original SHA-256 before making any modification.

Successful execution reports:

    Patch successful.

Verify the generated file with:

    sha256sum /tmp/heat-monitor.generated

The result must be:

    7cf731288c4f55b8ca4babbf716958c31ff1ad42e1cd139e09cc4b17a805c10e

The script performs this final verification automatically and removes
the generated output if verification fails.

## Important

This utility is specific to the known `heat-monitor` binary from
firmware 02.00.18.

It intentionally refuses to patch a binary whose SHA-256 does not
match the known original.

Do not remove this validation merely to make the script operate on a
different firmware version.

The thermal-monitor bug and binary modification are documented in:

    docs/thermal-shutdown-bug.md

The complete NAS recovery is documented in:

    docs/recovery-procedure.md
