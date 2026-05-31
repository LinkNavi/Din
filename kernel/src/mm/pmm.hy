include {
    std.kernel,
}

// ── Bitmap storage ────────────────────────────────────────────────────────────
// One bit per 4 KiB page.  Bit = 1 → free, 0 → used/reserved.
// Covers up to 4 GiB physical memory (1 048 576 pages, 131 072 bytes).

static uint64 _bitmap[16384];
static uint64 _total_pages;
static uint64 _free_pages;
static uint64 _hhdm;

module Pmm {
    const uint64 PAGE_SIZE    = 4096;
    const uint64 MAX_PAGES    = 1048576;
    const uint64 BITMAP_SIZE  = 131072;
    const uint64 USABLE       = 0;

    // ── Bitmap helpers ────────────────────────────────────────────────────────

    void set_free(uint64 page) {
        uint64 idx  = page / 64;
        uint64 bit  = page % 64;
        uint64 addr = cast<uint64>(&_bitmap) + idx * 8;
        *addr = *addr | (cast<uint64>(1) << bit);
    }

    void set_used(uint64 page) {
        uint64 idx  = page / 64;
        uint64 bit  = page % 64;
        uint64 addr = cast<uint64>(&_bitmap) + idx * 8;
        *addr = *addr & ~(cast<uint64>(1) << bit);
    }

    int is_free(uint64 page) {
        uint64 idx  = page / 64;
        uint64 bit  = page % 64;
        uint64 addr = cast<uint64>(&_bitmap) + idx * 8;
        uint64 mask = cast<uint64>(1) << bit;
        if ((*addr & mask) != 0) {
            return 1;
        }
        return 0;
    }

    // ── Public API ────────────────────────────────────────────────────────────

    public void init() {
        memset(cast<*void>(&_bitmap), 0, Pmm.BITMAP_SIZE);
        _total_pages = 0;
        _free_pages  = 0;
        _hhdm        = hhdm_offset();

        uint64 count = memmap_count();
        uint64 i = 0;
        while (i < count) {
            if (memmap_type(i) == Pmm.USABLE) {
                uint64 base         = memmap_base(i);
                uint64 len          = memmap_len(i);
                uint64 aligned_base = (base + Pmm.PAGE_SIZE - 1) & ~(Pmm.PAGE_SIZE - 1);
                uint64 aligned_len  = (base + len - aligned_base) & ~(Pmm.PAGE_SIZE - 1);
                uint64 page_count   = aligned_len / Pmm.PAGE_SIZE;
                uint64 first_page   = aligned_base / Pmm.PAGE_SIZE;

                uint64 j = 0;
                while (j < page_count) {
                    uint64 page = first_page + j;
                    if (page < Pmm.MAX_PAGES) {
                        set_free(page);
                        _free_pages  = _free_pages + 1;
                        _total_pages = _total_pages + 1;
                    }
                    j = j + 1;
                }
            }
            i = i + 1;
        }

        set_used(0);   // keep null page reserved

        vga_set_color(0x07);
        print("PMM: ");
        println(_free_pages);
    }

    // Allocate one 4 KiB physical page.  Returns physical address, or 0 on OOM.
    public uint64 alloc() {
        uint64 i = 1;
        while (i < Pmm.MAX_PAGES) {
            if (is_free(i) != 0) {
                set_used(i);
                _free_pages = _free_pages - 1;
                return i * Pmm.PAGE_SIZE;
            }
            i = i + 1;
        }
        return 0;
    }

    // Free a previously allocated physical page.
    public void free(uint64 phys) {
        uint64 page = phys / Pmm.PAGE_SIZE;
        if (page == 0) {
            return;
        }
        if (page < Pmm.MAX_PAGES) {
            set_free(page);
            _free_pages = _free_pages + 1;
        }
    }

    public uint64 free_pages() {
        return _free_pages;
    }

    public uint64 total_pages() {
        return _total_pages;
    }

    // Physical → virtual (HHDM).
    public uint64 phys_to_virt(uint64 phys) {
        return phys + _hhdm;
    }

    // Virtual (HHDM) → physical.
    public uint64 virt_to_phys(uint64 virt) {
        return virt - _hhdm;
    }
}
