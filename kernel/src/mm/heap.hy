include {
    std.kernel,
    mm.pmm,
}

// Head of the free-list chain (HHDM virtual address of first block header).
static uint64 _heap_head;

module Heap {
    // Block header layout: [size: uint64][flags: uint64][...data...]
    const uint64 HDR  = 16;
    const uint64 FREE = 1;

    // ── Header accessors ──────────────────────────────────────────────────────

    uint64 hdr_size(uint64 h)          { return *h; }
    uint64 hdr_flags(uint64 h)         { return *(h + 8); }
    void   set_size(uint64 h, uint64 v) { *h = v; }
    void   set_flags(uint64 h, uint64 v){ *(h + 8) = v; }

    // Allocate one physical page via PMM and return its HHDM virtual address.
    uint64 alloc_page() {
        uint64 phys = Pmm.alloc();
        if (phys == 0) { return 0; }
        uint64 virt = Pmm.phys_to_virt(phys);
        memset(cast<*void>(virt), 0, 4096);
        return virt;
    }

    // ── Public API ────────────────────────────────────────────────────────────

    public void init() {
        uint64 page = alloc_page();
        if (page == 0) {
            vga_set_color(0x4F);
            println("HEAP: init failed - out of physical memory");
            return;
        }
        _heap_head = page;
        set_size(_heap_head,  4096 - Heap.HDR);
        set_flags(_heap_head, Heap.FREE);
        println("Heap ready.");
    }

    // Allocate `size` bytes.  Returns HHDM virtual address, or 0 on OOM.
    public uint64 alloc(uint64 size) {
        if (size == 0)      { return 0; }
        if (_heap_head == 0){ return 0; }

        uint64 aligned = (size + 7) & ~cast<uint64>(7);
        uint64 cur = _heap_head;

        while (cur != 0) {
            uint64 flags = hdr_flags(cur);
            uint64 blksz = hdr_size(cur);

            if (blksz == 0) { break; }

            if ((flags & Heap.FREE) != 0) {
                if (blksz >= aligned) {
                    uint64 leftover = blksz - aligned;
                    if (leftover > Heap.HDR + 8) {
                        uint64 next_hdr = cur + Heap.HDR + aligned;
                        set_size(next_hdr,  leftover - Heap.HDR);
                        set_flags(next_hdr, Heap.FREE);
                        set_size(cur, aligned);
                    }
                    set_flags(cur, 0);
                    return cur + Heap.HDR;
                }
            }

            uint64 next = cur + Heap.HDR + blksz;

            // Last block — grow the heap by one page
            if (hdr_size(next) == 0 && hdr_flags(next) == 0) {
                uint64 new_page = alloc_page();
                if (new_page == 0) { return 0; }
                set_size(new_page,  4096 - Heap.HDR);
                set_flags(new_page, Heap.FREE);
                set_size(next,  8);
                set_flags(next, 0);
                *cast<uint64>(next + Heap.HDR) = new_page;
                cur = new_page;
            } else {
                cur = next;
            }
        }

        return 0;
    }

    // Free a pointer previously returned by Heap.alloc.
    public void free(uint64 ptr) {
        if (ptr == 0) { return; }
        uint64 hdr   = ptr - Heap.HDR;
        set_flags(hdr, Heap.FREE);

        // Coalesce with the immediately following block if also free
        uint64 blksz      = hdr_size(hdr);
        uint64 next       = hdr + Heap.HDR + blksz;
        uint64 next_flags = hdr_flags(next);
        uint64 next_size  = hdr_size(next);
        if (next_size != 0 && (next_flags & Heap.FREE) != 0) {
            set_size(hdr, blksz + Heap.HDR + next_size);
        }
    }

    public uint64 used_bytes() {
        uint64 used = 0;
        uint64 cur  = _heap_head;
        while (cur != 0) {
            uint64 flags = hdr_flags(cur);
            uint64 blksz = hdr_size(cur);
            if (blksz == 0) { break; }
            if ((flags & Heap.FREE) == 0) { used = used + blksz; }
            cur = cur + Heap.HDR + blksz;
        }
        return used;
    }
}
