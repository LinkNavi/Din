include {
    std.kernel,
}

// ── TSS storage ───────────────────────────────────────────────────────────────
// 104 bytes = 13 × uint64.  RSP0 lives at byte offset 4.

static uint64 _tss[13];

module Tss {
    // Set RSP0 — kernel stack used on ring-3 → ring-0 transition.
    public void set_rsp0(uint64 rsp0) {
        uint64 base   = cast<uint64>(&_tss);
        uint64 lo     = rsp0 & 0xFFFFFFFF;
        uint64 hi     = (rsp0 >> 32) & 0xFFFFFFFF;
        volatile *(base + 4) = lo;
        volatile *(base + 8) = hi;
    }

    // Base address of the TSS (for GDT descriptor construction).
    public uint64 base() {
        return cast<uint64>(&_tss);
    }

    // TSS limit = 104 − 1 = 103.
    public uint64 limit() {
        return 103;
    }

    // Zero the TSS and write the IOPB offset past the end (no port access from ring 3).
    public void init() {
        memset(cast<*void>(&_tss), 0, 104);
        uint64 base = cast<uint64>(&_tss);
        volatile *(base + 102) = cast<uint64>(104);
        println("TSS ready.");
    }

    // Load TR with selector 0x28 (GDT index 5).
    public void load() {
        asm {
            mov ax, 0x28
            ltr ax
        }
    }
}
