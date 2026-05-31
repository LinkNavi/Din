#!/usr/bin/env bash
set -e

KERNEL="kernel/build/bin/Din"
ISO="Din.iso"
LIMINE_DIR="/usr/share/limine"

echo "» Building ISO..."

rm -rf isoroot
mkdir -p isoroot/boot/limine
mkdir -p isoroot/EFI/BOOT

cp "$KERNEL"                         isoroot/boot/Din
cp "$LIMINE_DIR/limine-bios.sys"     isoroot/boot/limine/
cp "$LIMINE_DIR/limine-bios-cd.bin"  isoroot/boot/limine/
cp "$LIMINE_DIR/limine-uefi-cd.bin"  isoroot/boot/limine/
cp "$LIMINE_DIR/BOOTX64.EFI"         isoroot/EFI/BOOT/
cp scripts/limine.conf               isoroot/boot/limine/

xorriso -as mkisofs -R -r -J \
    -b boot/limine/limine-bios-cd.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table -hfsplus \
    -apm-block-size 2048 \
    --efi-boot boot/limine/limine-uefi-cd.bin \
    -efi-boot-part --efi-boot-image --protective-msdos-label \
    isoroot -o "$ISO"

limine bios-install "$ISO"

echo "» ISO ready: $ISO"
