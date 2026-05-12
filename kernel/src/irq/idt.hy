include {
    std.kernel,
    irq.exceptions,
    irq.pic,
}

// IDT storage: 256 entries × 16 bytes = 4096 bytes = 512 × uint64
static uint64 _idt[512];

module Idt {
    const uint64 SELECTOR  = 0x00080000;
    const uint64 TYPE_ATTR = 0x00008E0000000000;

    // Exception vectors
    const int VEC_DE  = 0;
    const int VEC_UD  = 6;
    const int VEC_DF  = 8;
    const int VEC_GP  = 13;
    const int VEC_PF  = 14;

    // Hardware IRQ vectors (after PIC remap)
    public const int IRQ_TIMER    = 0x20;
    public const int IRQ_KEYBOARD = 0x21;

    // Write one 16-byte IDT gate.
    void set_gate(uint64 entry_ptr, uint64 handler) {
        uint64 lo = (handler & 0xFFFF)
                  | Idt.SELECTOR
                  | Idt.TYPE_ATTR
                  | (((handler >> 16) & 0xFFFF) << 48);
        uint64 hi = handler >> 32;
        *entry_ptr       = lo;
        *(entry_ptr + 8) = hi;
    }

    void register(uint64 vector, uint64 handler) {
        uint64 entry = cast<uint64>(&_idt) + vector * 16;
        set_gate(entry, handler);
    }

    void load() {
        asm {
            sub  rsp, 16
            lea  rax, [rel _idt]
            mov  [rsp + 2], rax
            mov  word [rsp], 4095
            lidt [rsp]
            add  rsp, 16
        }
    }

    public Error? init() {
        register(Idt.VEC_DE, addrof_fn(isr0));
        register(Idt.VEC_UD, addrof_fn(isr6));
        register(Idt.VEC_DF, addrof_fn(isr8));
        register(Idt.VEC_GP, addrof_fn(isr13));
        register(Idt.VEC_PF, addrof_fn(isr14));

        Pic.init();

        register(Idt.IRQ_TIMER,    addrof_fn(isr32));
        register(Idt.IRQ_KEYBOARD, addrof_fn(isr33));

        load();

        println("IDT loaded.");
        return nil;
    }
}
