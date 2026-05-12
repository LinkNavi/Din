include {
    std.kernel,
    exceptions,
}

// IDT storage — 256 entries × 16 bytes = 512 bytes = 64 × uint64.
// Only entries 0, 6, 8, 13, 14 are wired up; the rest stay zero.
static uint64 _idt_q00; static uint64 _idt_q01;
static uint64 _idt_q02; static uint64 _idt_q03;
static uint64 _idt_q04; static uint64 _idt_q05;
static uint64 _idt_q06; static uint64 _idt_q07;
static uint64 _idt_q08; static uint64 _idt_q09;
static uint64 _idt_q10; static uint64 _idt_q11;
static uint64 _idt_q12; static uint64 _idt_q13;
static uint64 _idt_q14; static uint64 _idt_q15;
static uint64 _idt_q16; static uint64 _idt_q17;
static uint64 _idt_q18; static uint64 _idt_q19;
static uint64 _idt_q20; static uint64 _idt_q21;
static uint64 _idt_q22; static uint64 _idt_q23;
static uint64 _idt_q24; static uint64 _idt_q25;
static uint64 _idt_q26; static uint64 _idt_q27;
static uint64 _idt_q28; static uint64 _idt_q29;

// Fill one 16-byte IDT entry (interrupt gate, DPL=0, selector=0x08).
//
// Entry layout (Intel SDM Vol.3A §6.14.1):
//   Low  qword: handler[15:0] | selector(0x08)<<16 | type_attr(0x8E)<<40 | handler[31:16]<<48
//   High qword: handler[63:32]
//
// All the bit-packing is computable arithmetic — no ASM needed.
void _idt_set_gate(uint64 entry_ptr, uint64 handler) {
    uint64 low  = (handler & 0xFFFF)
                | 0x00080000
                | 0x00008E0000000000
                | ((handler >> 16) & 0xFFFF) << 48;
    uint64 high = handler >> 32;
    *entry_ptr       = low;
    *(entry_ptr + 8) = high;
}

// Register an ISR by vector number.
// entry address = base + vector * 16  (each IDT entry is 16 bytes)
void _idt_register(uint64 vector, uint64 handler) {
    uint64 entry = &_idt_q00 + vector * 16;
    _idt_set_gate(entry, handler);
}

// Load the IDTR — the only instruction here that requires ASM.
// limit = 256 entries × 16 bytes − 1 = 4095
void _idt_load() {
    asm {
        sub  rsp, 16
        lea  rax, [rel _idt_q00]
        mov  [rsp + 2], rax
        mov  word [rsp], 4095
        lidt [rsp]
        add  rsp, 16
    }
}

Error? idt_init() {
    _idt_register(0,  addrof_fn(isr0));
    _idt_register(6,  addrof_fn(isr6));
    _idt_register(8,  addrof_fn(isr8));
    _idt_register(13, addrof_fn(isr13));
    _idt_register(14, addrof_fn(isr14));

    _idt_load();

    println("IDT loaded.");
    return nil;
}
