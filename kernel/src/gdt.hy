include {
    std.kernel,
}

// GDT entries — three 8-byte descriptors: null, code (ring 0), data (ring 0).
// Descriptor values (Intel SDM Vol.3 §3.4.5):
//   null : all-zero
//   code : 64-bit, present, DPL=0, execute/read  → 0x00AF9A000000FFFF
//   data : 32/64-bit, present, DPL=0, read/write → 0x00CF92000000FFFF
static uint64 _gdt_null;
static uint64 _gdt_code;
static uint64 _gdt_data;

// Load the GDTR and atomically switch to the new code segment.
// Only privileged instructions that have no Hylian equivalent stay in ASM:
//   lgdt, retfq (far-return to flush CS), and the segment-register moves.
void _gdt_flush(uint64 base, uint64 limit) {
    asm {
        ; Build the 10-byte GDTR on the stack: [limit:2][base:8]
        sub  rsp, 16
        mov  rax, [rbp - 8]   ; base
        mov  rcx, [rbp - 16]  ; limit
        mov  [rsp + 2], rax
        mov  [rsp],     cx
        lgdt [rsp]
        add  rsp, 16

        ; Far-return flushes CS with selector 0x08 (ring-0 code segment)
        push 0x08
        lea  rax, [rel .cs_flush]
        push rax
        retfq
    .cs_flush:
        ; Reload data-segment registers with selector 0x10 (ring-0 data segment)
        mov ax, 0x10
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax
        mov ss, ax
    }
}

void gdt_init() {
    *&_gdt_null = 0x0000000000000000;
    *&_gdt_code = 0x00AF9A000000FFFF;
    *&_gdt_data = 0x00CF92000000FFFF;

    // limit = 3 descriptors * 8 bytes - 1 = 23
    _gdt_flush(&_gdt_null, 23);

    println("GDT loaded.");
}
