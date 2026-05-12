include {
    std.kernel,
}

packed class IDTEntry {
    uint16 offset_low;
    uint16 selector;
    uint8  ist;
    uint8  type_attr;
    uint16 offset_mid;
    uint32 offset_high;
    uint32 zero;
}

packed class IDTPtr {
    uint16 limit;
    uint64 base;
}

static IDTEntry idt_entries_0;
static IDTEntry idt_entries_1;
static IDTEntry idt_entries_2;
static IDTEntry idt_entries_3;
static IDTEntry idt_entries_4;
static IDTEntry idt_entries_5;
static IDTEntry idt_entries_6;
static IDTEntry idt_entries_7;
static IDTEntry idt_entries_8;
static IDTEntry idt_entries_9;
static IDTEntry idt_entries_10;
static IDTEntry idt_entries_11;
static IDTEntry idt_entries_12;
static IDTEntry idt_entries_13;
static IDTEntry idt_entries_14;
static IDTEntry idt_entries_15;
static IDTPtr   idt_ptr;

// set one gate using field access — no asm needed
void idt_set_gate(IDTEntry entry, uint64 handler, uint16 sel) {
    entry.offset_low  = cast<uint16>(handler & 0xFFFF);
    entry.offset_mid  = cast<uint16>((handler >> 16) & 0xFFFF);
    entry.offset_high = cast<uint32>((handler >> 32) & 0xFFFFFFFF);
    entry.selector    = sel;
    entry.ist         = 0;
    entry.type_attr   = 0x8E; // present, interrupt gate
    entry.zero        = 0;
}

Error? idt_init() {
    idt_ptr.limit = 4095;
    asm{
        lea rax, [rel idt_entries_0]
        mov [rel idt_ptr + 2], rax
    }
    idt_set_gate(idt_entries_0,  addrof_fn(isr0),  0x08);
    idt_set_gate(idt_entries_6,  addrof_fn(isr6),  0x08);
    idt_set_gate(idt_entries_8,  addrof_fn(isr8),  0x08);
    idt_set_gate(idt_entries_13, addrof_fn(isr13), 0x08);
    idt_set_gate(idt_entries_14, addrof_fn(isr14), 0x08);
    asm{ lidt [rel idt_ptr] }
    println("IDT loaded.");
    return nil;
}
