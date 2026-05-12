# ─────────────────────────────────────────────────────────────────────────────
# Din kernel justfile
# Requires: just, linkle, qemu-system-x86_64, xorriso, limine
#
# just build       — compile the kernel ELF
# just iso         — build + create bootable ISO
# just run         — iso + boot in QEMU (VGA window)
# just run-serial  — iso + boot in QEMU (serial to terminal)
# just run-uefi    — iso + boot with OVMF UEFI firmware
# just debug       — iso + boot with GDB stub on :1234
# just gdb         — attach GDB to a running debug session
# just hdd         — create a raw disk image
# just run-hdd     — boot the raw disk image in QEMU
# just clean       — remove build artifacts and ISO
# ─────────────────────────────────────────────────────────────────────────────

kernel := "kernel/build/bin/Din"
iso := "Din.iso"
hdd := "Din.img"
ovmf := "/usr/share/edk2/x64/OVMF.4m.fd"

qemu_base := "qemu-system-x86_64 -m 256M -no-reboot -no-shutdown -display gtk"

# Default: list recipes
default:
    @just --list

linkle := "python3 ../linkle.py"

# Compile the kernel ELF
build:
    {{ linkle }} build

# Build bootable ISO
iso: build
    @bash scripts/mkiso.sh

# Boot in QEMU — GTK window + serial output in terminal
run: iso
    {{ qemu_base }} -cdrom {{ iso }} -vga std -serial stdio

# Boot in QEMU with ISA VGA + serial output in terminal
run-vga: iso
    {{ qemu_base }} -cdrom {{ iso }} -vga none -device isa-vga -serial stdio

# Boot with serial output in terminal (no window)
run-serial: iso
    qemu-system-x86_64 -m 256M -no-reboot -no-shutdown -nographic -serial mon:stdio -cdrom {{ iso }}

# Boot with OVMF UEFI firmware
run-uefi: iso
    @test -f {{ ovmf }} || (echo "OVMF not found at {{ ovmf }} — install edk2-ovmf" && exit 1)
    {{ qemu_base }} -cdrom {{ iso }} -bios {{ ovmf }} -vga std

# Boot with GDB stub on :1234 (paused, waits for gdb to connect)
debug: iso
    @echo "» GDB stub on :1234 — run 'just gdb' in another terminal"
    {{ qemu_base }} -cdrom {{ iso }} -vga std -s -S

# Attach GDB to a running debug session
gdb:
    gdb {{ kernel }} -ex "target remote :1234" -ex "symbol-file {{ kernel }}"

# Build raw HDD image
hdd: build
    @bash scripts/mkhdd.sh

# Boot the raw HDD image
run-hdd: hdd
    {{ qemu_base }} -drive format=raw,file={{ hdd }} -vga std

# Wipe everything
clean:
    {{ linkle }} clean
    rm -rf isoroot hddroot {{ iso }} {{ hdd }}
    @echo "» Clean done."
