#!/usr/bin/env bash

set -euo pipefail

ORIGINAL_SHA256="901cdf88cdbecff23920ed141361f3d1ed7994c3268febf6d84bfa91bc165fa4"
PATCHED_SHA256="7cf731288c4f55b8ca4babbf716958c31ff1ad42e1cd139e09cc4b17a805c10e"

PATCH_OFFSET=$((0x1367))
EXPECTED_ORIGINAL_BYTE="0a"
PATCHED_BYTE="ea"

usage() {
    echo "Usage: $0 <original-heat-monitor> <patched-output>"
    exit 1
}

if [[ $# -ne 2 ]]; then
    usage
fi

INPUT="$1"
OUTPUT="$2"

if [[ ! -f "$INPUT" ]]; then
    echo "ERROR: Input file does not exist: $INPUT" >&2
    exit 1
fi

if [[ "$INPUT" == "$OUTPUT" ]]; then
    echo "ERROR: Input and output must be different files." >&2
    exit 1
fi

actual_original_sha256="$(sha256sum "$INPUT" | awk '{print $1}')"

if [[ "$actual_original_sha256" != "$ORIGINAL_SHA256" ]]; then
    echo "ERROR: Input SHA-256 does not match the known stock 02.00.18 heat-monitor." >&2
    echo "Expected: $ORIGINAL_SHA256" >&2
    echo "Actual:   $actual_original_sha256" >&2
    exit 1
fi

original_byte="$(
    dd if="$INPUT" bs=1 skip="$PATCH_OFFSET" count=1 status=none |
    od -An -tx1 |
    tr -d '[:space:]'
)"

if [[ "$original_byte" != "$EXPECTED_ORIGINAL_BYTE" ]]; then
    echo "ERROR: Unexpected byte at offset 0x1367." >&2
    echo "Expected: 0x$EXPECTED_ORIGINAL_BYTE" >&2
    echo "Actual:   0x$original_byte" >&2
    exit 1
fi

cp -- "$INPUT" "$OUTPUT"

printf '\xea' |
    dd of="$OUTPUT" bs=1 seek="$PATCH_OFFSET" count=1 conv=notrunc status=none

chmod --reference="$INPUT" "$OUTPUT"

actual_patched_sha256="$(sha256sum "$OUTPUT" | awk '{print $1}')"

if [[ "$actual_patched_sha256" != "$PATCHED_SHA256" ]]; then
    echo "ERROR: Patched SHA-256 does not match the expected result." >&2
    echo "Expected: $PATCHED_SHA256" >&2
    echo "Actual:   $actual_patched_sha256" >&2
    rm -f -- "$OUTPUT"
    exit 1
fi

echo "Patch successful."
echo
echo "Input SHA-256:"
echo "  $actual_original_sha256"
echo
echo "Patched SHA-256:"
echo "  $actual_patched_sha256"
echo
echo "Changed byte:"
echo "  offset 0x1367: 0x0A -> 0xEA"
echo
echo "Output:"
echo "  $OUTPUT"
