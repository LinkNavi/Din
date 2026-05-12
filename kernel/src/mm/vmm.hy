include {
    std.kernel,
    mm.pmm,
}

static uint64 _kernel_pml4;

module Vmm {
    // Page table entry flags
    public const uint64 PTE_PRESENT   = 0x01;
    public const uint64 PTE_WRITABLE  = 0x02;
    public const uint64 PTE_USER      = 0x04;
    public const uint64 PTE_NX        = 0x8000000000000000;
    public const uint64 PTE_ADDR_MASK = 0x000FFFFFFFFFF000;
    public const uint64 KERNEL_RW     = 0x03;
    public const uint64 KERNEL_RO     = 0x01;

    // ── Virtual address decomposition ─────────────────────────────────────────

    uint64 pml4_idx(uint64 vaddr) { return (vaddr >> 39) & 0x1FF; }
    uint64 pdpt_idx(uint64 vaddr) { return (vaddr >> 30) & 0x1FF; }
    uint64 pd_idx(uint64 vaddr)   { return (vaddr >> 21) & 0x1FF; }
    uint64 pt_idx(uint64 vaddr)   { return (vaddr >> 12) & 0x1FF; }

    // ── Page table helpers ────────────────────────────────────────────────────

    // Walk one level: if the entry at table_virt[idx] is absent, allocate a
    // fresh zeroed page, write the entry, and return the child's virtual address.
    uint64 get_or_create(uint64 table_virt, uint64 idx, uint64 flags) {
        uint64 entry_addr = table_virt + idx * 8;
        uint64 entry = *entry_addr;
        if ((entry & Vmm.PTE_PRESENT) != 0) {
            return Pmm.phys_to_virt(entry & Vmm.PTE_ADDR_MASK);
        }
        uint64 phys = Pmm.alloc();
        if (phys == 0) {
            return 0;
        }
        uint64 virt = Pmm.phys_to_virt(phys);
        memset(cast<*void>(virt), 0, 4096);
        *entry_addr = phys | flags;
        return virt;
    }

    // ── Public API ────────────────────────────────────────────────────────────

    public void init() {
        _kernel_pml4 = read_cr(3) & Vmm.PTE_ADDR_MASK;
        print("VMM: PML4 at 0x");
        println(_kernel_pml4);
    }

    // Map vaddr → phys in the given PML4 (physical address).
    // Returns 0 on success, 1 on OOM.
    public int map_page(uint64 pml4_phys, uint64 vaddr, uint64 phys, uint64 flags) {
        uint64 pml4_virt = Pmm.phys_to_virt(pml4_phys);

        uint64 pdpt = get_or_create(pml4_virt, pml4_idx(vaddr), Vmm.KERNEL_RW);
        if (pdpt == 0) { return 1; }

        uint64 pd = get_or_create(pdpt, pdpt_idx(vaddr), Vmm.KERNEL_RW);
        if (pd == 0) { return 1; }

        uint64 pt = get_or_create(pd, pd_idx(vaddr), Vmm.KERNEL_RW);
        if (pt == 0) { return 1; }

        *(pt + pt_idx(vaddr) * 8) = (phys & Vmm.PTE_ADDR_MASK) | flags | Vmm.PTE_PRESENT;
        return 0;
    }

    // Unmap vaddr from the given PML4 and invalidate the TLB entry.
    public void unmap_page(uint64 pml4_phys, uint64 vaddr) {
        uint64 pml4_virt  = Pmm.phys_to_virt(pml4_phys);
        uint64 pml4_entry = *(pml4_virt + pml4_idx(vaddr) * 8);
        if ((pml4_entry & Vmm.PTE_PRESENT) == 0) { return; }

        uint64 pdpt_virt  = Pmm.phys_to_virt(pml4_entry & Vmm.PTE_ADDR_MASK);
        uint64 pdpt_entry = *(pdpt_virt + pdpt_idx(vaddr) * 8);
        if ((pdpt_entry & Vmm.PTE_PRESENT) == 0) { return; }

        uint64 pd_virt  = Pmm.phys_to_virt(pdpt_entry & Vmm.PTE_ADDR_MASK);
        uint64 pd_entry = *(pd_virt + pd_idx(vaddr) * 8);
        if ((pd_entry & Vmm.PTE_PRESENT) == 0) { return; }

        uint64 pt_virt = Pmm.phys_to_virt(pd_entry & Vmm.PTE_ADDR_MASK);
        *(pt_virt + pt_idx(vaddr) * 8) = 0;

        asm {
            mov rax, [rbp - 8]
            invlpg [rax]
        }
    }

    // Convenience wrappers that operate on the live kernel PML4.
    public int kernel_map(uint64 vaddr, uint64 phys, uint64 flags) {
        return map_page(_kernel_pml4, vaddr, phys, flags);
    }

    public void kernel_unmap(uint64 vaddr) {
        unmap_page(_kernel_pml4, vaddr);
    }

    public uint64 kernel_pml4() {
        return _kernel_pml4;
    }
}
