# Local Firmware Server

This directory contains the `list.asp` file used during recovery of the
WD My Book World Edition II (Blue Rings).

The NAS firmware updater requested:

    GET /list.asp?type=wdg2nc&fw=01.01.18

The supplied `list.asp` points the NAS to firmware 02.00.18:

    http://192.168.2.27:8000/wdgxnc-02.00.18.wdg

In the documented recovery environment:

    Firmware server: 192.168.2.27
    NAS:             192.168.2.144
    Gateway:         192.168.2.1

When reproducing the procedure, change the IP address in `list.asp` to
the address of the machine hosting the firmware file.

Place the following files in the same directory:

    list.asp
    wdgxnc-02.00.18.wdg

The Western Digital firmware package is not distributed by this
repository.

Firmware 02.00.18 must be obtained separately. The verified filename
and checksums are documented in the top-level `README.md` and in
`docs/recovery-procedure.md`.

A simple HTTP server can be started from this directory with:

    python3 -m http.server 8000

The NAS must be configured to use the local firmware server address
described in `docs/recovery-procedure.md`.
