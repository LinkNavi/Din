#!/usr/bin/env bash
set -e

KERNEL="build/bin/Din"
HDD="Din.img"
LIMINE_SYS="/usr/share/limine/limine-bios.sys"
LIMINE_BIOS_CD="/usr/share/limine/limine-bios-cd.bin"

echo "» Creating raw disk image $HDD..."

mkdir -p hddroot/boot/limine
cp "$KERNEL" hddroot/boot/Din
cp "$LIMINE_SYS"     hddroot/boot/limine/limine-bios.sys    2>/dev/null || true
cp "$LIMINE_BIOS_CD" hddroot/boot/limine/limine-bios-cd.bin 2>/dev/null || true
cp scripts/limine.conf hddroot/boot/limine/limine.conf

dd if=/dev/zero of="$HDD" bs=1M count=64 status=none
parted -s "$HDD" mklabel gpt mkpart primary 2048s 100% set 1 boot on
mformat -i "$HDD"@@1048576 -F ::
mcopy -i "$HDD"@@1048576 -s hddroot/boot ::/boot
limine bios-install "$HDD" 2>/dev/null

echo "» HDD image ready: $HDD"
