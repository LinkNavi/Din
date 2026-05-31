include {
    std.kernel,
    mm.pmm,
    mm.heap,
    boot.tss,
}

// ── Process table storage ─────────────────────────────────────────────────────
// Each entry is 72 bytes (9 × uint64).  We keep a flat array and address
// fields by byte offset so no struct support is needed.
//
// Offsets:
//   0  pid        8  state      16 kstack_top  24 kstack_rsp
//  32  entry     40  is_user    48 ipc_dst     56 ipc_src
//  64  ipc_msgptr

static uint64 _proc_table[576];   // 64 entries × 72 bytes / 8
static int    _count;
static int    _current;

// Top-level stub so addrof_fn() can reference the user-entry trampoline.
// addrof_fn() only accepts plain identifiers, not Module.fn paths.
naked void _proc_enter_user_stub() {
    asm { iretq }
}

module Proc {
    // Process states
    public const int UNUSED  = 0;
    public const int READY   = 1;
    public const int RUNNING = 2;
    public const int BLOCKED = 3;
    public const int DEAD    = 4;

    // Field offsets (bytes)
    const uint64 OFF_PID      = 0;
    const uint64 OFF_STATE    = 8;
    const uint64 OFF_KSTKTOP  = 16;
    const uint64 OFF_KSTRSP   = 24;
    const uint64 OFF_ENTRY    = 32;
    const uint64 OFF_ISUSER   = 40;
    const uint64 OFF_IPCDST   = 48;
    const uint64 OFF_IPCSRC   = 56;
    const uint64 OFF_IPCMSG   = 64;

    const int MAX     = 64;
    const int KPAGES  = 2;
    const int UPAGES  = 4;
    const uint64 ENTRY_SIZE = 72;

    // ── Table helpers ─────────────────────────────────────────────────────────

    uint64 addr(int pid) {
        return cast<uint64>(&_proc_table) + cast<uint64>(pid) * Proc.ENTRY_SIZE;
    }

    uint64 get(int pid, uint64 off) {
        return *(addr(pid) + off);
    }

    void set(int pid, uint64 off, uint64 val) {
        *(addr(pid) + off) = val;
    }

    int alloc_slot() {
        int i = 0;
        while (i < Proc.MAX) {
            if (get(i, Proc.OFF_STATE) == cast<uint64>(Proc.UNUSED)) { return i; }
            i = i + 1;
        }
        return -1;
    }

    // Allocate `pages` PMM pages and return the HHDM virtual top of the last.
    uint64 alloc_stack(int pages) {
        uint64 first_phys = Pmm.alloc();
        if (first_phys == 0) { return 0; }
        uint64 virt = Pmm.phys_to_virt(first_phys);
        memset(cast<*void>(virt), 0, 4096);
        int i = 1;
        while (i < pages) {
            uint64 p = Pmm.alloc();
            if (p == 0) { return 0; }
            memset(cast<*void>(Pmm.phys_to_virt(p)), 0, 4096);
            i = i + 1;
        }
        return virt + cast<uint64>(pages) * 4096;
    }

    // ── Context switch stub ───────────────────────────────────────────────────
    // rdi = &old_rsp_save, rsi = new_rsp

    public naked void switch_asm() {
        asm {
            push rbp
            push rbx
            push r12
            push r13
            push r14
            push r15
            pushfq
            mov [rdi], rsp
            mov rsp, rsi
            popfq
            pop r15
            pop r14
            pop r13
            pop r12
            pop rbx
            pop rbp
            ret
        }
    }

    // iretq trampoline for the first switch into a user process.
    public naked void enter_user() {
        asm {
            iretq
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    public void init() {
        memset(cast<*void>(&_proc_table), 0, Proc.MAX * cast<int>(Proc.ENTRY_SIZE));
        _count   = 0;
        _current = -1;
        println("Scheduler ready.");
    }

    // Spawn a process.  entry = virtual address of the entry function.
    // is_user = 1 for ring 3, 0 for kernel thread.
    // Returns pid, or -1 on failure.
    public int spawn(uint64 entry, int is_user) {
        int pid = alloc_slot();
        if (pid == -1) { return -1; }

        uint64 kstack = alloc_stack(Proc.KPAGES);
        if (kstack == 0) { return -1; }

        uint64 rsp = kstack;

        if (is_user != 0) {
            uint64 ustack = alloc_stack(Proc.UPAGES);
            if (ustack == 0) { return -1; }

            rsp = rsp - 8; *rsp = cast<uint64>(0x1B);       // SS
            rsp = rsp - 8; *rsp = ustack - 8;               // user RSP
            rsp = rsp - 8; *rsp = cast<uint64>(0x200);      // rflags IF=1
            rsp = rsp - 8; *rsp = cast<uint64>(0x23);       // CS
            rsp = rsp - 8; *rsp = entry;                    // RIP
            rsp = rsp - 8; *rsp = addrof_fn(_proc_enter_user_stub);
        } else {
            rsp = rsp - 8; *rsp = entry;
        }

        // Zeroed callee-save frame for switch_asm to pop on first switch
        rsp = rsp - 8; *rsp = cast<uint64>(0x200);  // rflags
        rsp = rsp - 8; *rsp = cast<uint64>(0);      // r15
        rsp = rsp - 8; *rsp = cast<uint64>(0);      // r14
        rsp = rsp - 8; *rsp = cast<uint64>(0);      // r13
        rsp = rsp - 8; *rsp = cast<uint64>(0);      // r12
        rsp = rsp - 8; *rsp = cast<uint64>(0);      // rbx
        rsp = rsp - 8; *rsp = cast<uint64>(0);      // rbp

        set(pid, Proc.OFF_PID,     cast<uint64>(pid));
        set(pid, Proc.OFF_STATE,   cast<uint64>(Proc.READY));
        set(pid, Proc.OFF_KSTKTOP, kstack);
        set(pid, Proc.OFF_KSTRSP,  rsp);
        set(pid, Proc.OFF_ENTRY,   entry);
        set(pid, Proc.OFF_ISUSER,  cast<uint64>(is_user));
        set(pid, Proc.OFF_IPCDST,  cast<uint64>(-1));
        set(pid, Proc.OFF_IPCSRC,  cast<uint64>(-1));
        set(pid, Proc.OFF_IPCMSG,  cast<uint64>(0));

        _count = _count + 1;
        return pid;
    }

    // Round-robin scheduler — called from the timer IRQ.
    public void schedule() {
        int start = _current + 1;
        int i = 0;
        while (i < Proc.MAX) {
            int cand = (start + i) % Proc.MAX;
            if (get(cand, Proc.OFF_STATE) == cast<uint64>(Proc.READY)) {
                int old = _current;

                if (old >= 0) {
                    if (get(old, Proc.OFF_STATE) == cast<uint64>(Proc.RUNNING)) {
                        set(old, Proc.OFF_STATE, cast<uint64>(Proc.READY));
                    }
                }

                _current = cand;
                set(cand, Proc.OFF_STATE, cast<uint64>(Proc.RUNNING));
                Tss.set_rsp0(get(cand, Proc.OFF_KSTKTOP));

                uint64 new_rsp = get(cand, Proc.OFF_KSTRSP);

                if (old >= 0) {
                    uint64 old_rsp_addr = addr(old) + Proc.OFF_KSTRSP;
                    Proc.switch_asm(old_rsp_addr, new_rsp);
                } else {
                    uint64 scratch = 0;
                    Proc.switch_asm(cast<uint64>(&scratch), new_rsp);
                }
                return;
            }
            i = i + 1;
        }
    }

    public int current_pid() { return _current; }
    public int count()       { return _count; }

    public void exit(int pid) {
        if (pid < 0)         { return; }
        if (pid >= Proc.MAX) { return; }
        set(pid, Proc.OFF_STATE, cast<uint64>(Proc.DEAD));
        _count = _count - 1;
        if (_current == pid) {
            _current = -1;
            Proc.schedule();
        }
    }

    public void block(int pid) {
        set(pid, Proc.OFF_STATE, cast<uint64>(Proc.BLOCKED));
    }

    public void unblock(int pid) {
        set(pid, Proc.OFF_STATE, cast<uint64>(Proc.READY));
    }

    public int  ipc_dst(int pid)    { return cast<int>(get(pid, Proc.OFF_IPCDST)); }
    public int  ipc_src(int pid)    { return cast<int>(get(pid, Proc.OFF_IPCSRC)); }
    public uint64 ipc_msgptr(int pid) { return get(pid, Proc.OFF_IPCMSG); }

    public void set_ipc(int pid, int dst, int src, uint64 msgptr) {
        set(pid, Proc.OFF_IPCDST, cast<uint64>(dst));
        set(pid, Proc.OFF_IPCSRC, cast<uint64>(src));
        set(pid, Proc.OFF_IPCMSG, msgptr);
    }

    public uint64 get_state(int pid) {
        return get(pid, Proc.OFF_STATE);
    }
}
