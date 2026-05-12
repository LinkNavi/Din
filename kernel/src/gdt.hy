include {
    std.kernel,
}

packed class GDTEntry {
    uint16 limit_low;
    uint16 base_low;
    uint8  base_mid;
    uint8  access;
    uint8  granularity;
    uint8  base_high;
}

packed class GDTPtr {
    uint16 limit;
    uint64 base;
}

static GDTEntry gdt_null;
static GDTEntry gdt_code;
static GDTEntry gdt_data;
static GDTPtr   gdt_ptr;

Error? gdt_init() {
    // null descriptor — all zero
    gdt_null.limit_low   = 0;
    gdt_null.base_low    = 0;
    gdt_null.base_mid    = 0;
    gdt_null.access      = 0;
    gdt_null.granularity = 0;
    gdt_null.base_high   = 0;

    // kernel code: base=0, limit=0xFFFFFFFF, access=0x9A, gran=0xCF
    gdt_code.limit_low   = 0xFFFF;
    gdt_code.base_low    = 0;
    gdt_code.base_mid    = 0;
    gdt_code.access      = 0x9A;
    gdt_code.granularity = 0xCF;
    gdt_code.base_high   = 0;

    // kernel data: base=0, limit=0xFFFFFFFF, access=0x92, gran=0xCF
    gdt_data.limit_low   = 0xFFFF;
    gdt_data.base_low    = 0;
    gdt_data.base_mid    = 0;
    gdt_data.access      = 0x92;
    gdt_data.granularity = 0xCF;
    gdt_data.base_high   = 0;

    // GDT pointer: 3 entries * 8 bytes - 1 = 23
    gdt_ptr.limit = 23;

    // only asm we truly need: load address, lgdt, retfq to reload CS
    asm{
        lea rax, [rel gdt_null]
        mov [rel gdt_ptr + 2], rax
        lgdt [rel gdt_ptr]
        push 0x08
        lea rax, [rel .flush]
        push rax
        retfq
    .flush:
        mov ax, 0x10
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax
        mov ss, ax
    }

    println("GDT loaded.");
    return nil;
}
