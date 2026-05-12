include {
    std.kernel,
    boot.tss,
}

// ── GDT storage: 7 slots × 8 bytes ───────────────────────────────────────────
static uint64 _gdt[7];

module Gdt {
    // Descriptor constants (Intel SDM Vol.3 §3.4.5)
    // ring 0
    public const uint64 KCODE = 0x00AF9A000000FFFF;
    public const uint64 KDATA = 0x00CF92000000FFFF;
    // ring 3
    public const uint64 UDATA = 0x00CFF2000000FFFF;
    public const uint64 UCODE = 0x00AFFA000000FFFF;

    // Selector values
    public const int SEL_KCODE = 0x08;
    public const int SEL_KDATA = 0x10;
    public const int SEL_UDATA = 0x1B;   // 0x18 | RPL 3
    public const int SEL_UCODE = 0x23;   // 0x20 | RPL 3
    public const int SEL_TSS   = 0x28;

    // Build a 16-byte 64-bit TSS descriptor into two consecutive GDT slots.
    void write_tss(uint64 slot_addr, uint64 base, uint64 limit) {
        uint64 lo = (limit & 0xFFFF)
                  | ((base & 0xFFFF) << 16)
                  | (((base >> 16) & 0xFF) << 32)
                  | (cast<uint64>(0x89) << 40)
                  | (((limit >> 16) & 0xF) << 48)
                  | (((base >> 24) & 0xFF) << 56);
        uint64 hi = (base >> 32) & 0xFFFFFFFF;
        *slot_addr       = lo;
        *(slot_addr + 8) = hi;
    }

    // Load GDTR and flush segment registers.
    void flush(uint64 base, uint64 limit) {
        asm {
            sub  rsp, 16
            mov  rax, [rbp - 8]
            mov  rcx, [rbp - 16]
            mov  [rsp + 2], rax
            mov  [rsp],     cx
            lgdt [rsp]
            add  rsp, 16
            push 0x08
            lea  rax, [rel .cs_flush]
            push rax
            retfq
        .cs_flush:
            mov ax, 0x10
            mov ds, ax
            mov es, ax
            mov fs, ax
            mov gs, ax
            mov ss, ax
        }
    }

    public void init() {
        *cast<uint64>(&_gdt)      = 0x0000000000000000;   // null
        *cast<uint64>(&_gdt + 8)  = Gdt.KCODE;
        *cast<uint64>(&_gdt + 16) = Gdt.KDATA;
        *cast<uint64>(&_gdt + 24) = Gdt.UDATA;
        *cast<uint64>(&_gdt + 32) = Gdt.UCODE;

        Tss.init();
        write_tss(cast<uint64>(&_gdt) + 40, Tss.base(), Tss.limit());

        flush(cast<uint64>(&_gdt), 55);
        Tss.load();

        println("GDT loaded.");
    }
}
