#!/usr/bin/env bash
set -e

KERNEL="build/bin/Din"
ISO="Din.iso"
LIMINE_SYS="/usr/share/limine/limine-bios.sys"
LIMINE_BIOS_CD="/usr/share/limine/limine-bios-cd.bin"
LIMINE_UEFI_CD="/usr/share/limine/limine-uefi-cd.bin"
LIMINE_BOOTX64="/usr/share/limine/BOOTX64.EFI"

echo "» Building ISO..."

rm -rf isoroot
mkdir -p isoroot/boot/limine
mkdir -p isoroot/EFI/BOOT

cp "$KERNEL"        isoroot/boot/Din
cp "$LIMINE_SYS"    isoroot/boot/limine/limine-bios.sys
cp "$LIMINE_BIOS_CD" isoroot/boot/limine/limine-bios-cd.bin
cp "$LIMINE_UEFI_CD" isoroot/boot/limine/limine-uefi-cd.bin
cp "$LIMINE_BOOTX64" isoroot/EFI/BOOT/BOOTX64.EFI
cp scripts/limine.conf isoroot/boot/limine/limine.conf

xorriso -as mkisofs \
    -b boot/limine/limine-bios-cd.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    --efi-boot boot/limine/limine-uefi-cd.bin \
    -efi-boot-part --efi-boot-image \
    --protective-msdos-label \
    isoroot -o "$ISO"

echo "» ISO ready: $ISO"
