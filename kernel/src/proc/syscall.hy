include {
    std.kernel,
    proc.proc,
    proc.ipc,
}

static uint64 _syscall_stack[512];
static uint64 _syscall_stack_top;
static uint64 _user_rsp_scratch;

module Syscall {
    public const int SYS_EXIT  = 0;
    public const int SYS_YIELD = 1;
    public const int SYS_SEND  = 2;
    public const int SYS_RECV  = 3;

    const uint64 MSR_EFER   = 0xC0000080;
    const uint64 MSR_STAR   = 0xC0000081;
    const uint64 MSR_LSTAR  = 0xC0000082;
    const uint64 MSR_SFMASK = 0xC0000084;

    void wrmsr(uint64 msr, uint64 val) {
        asm {
            mov rcx, [rbp - 8]
            mov rax, [rbp - 16]
            mov rdx, rax
            shr rdx, 32
            and eax, 0xFFFFFFFF
            wrmsr
        }
    }

    // Read an MSR. Result is returned via a local variable written from asm.
    uint64 rdmsr(uint64 msr) {
        uint64 result = 0;
        asm {
            mov  rcx, [rbp - 8]     ; msr arg
            rdmsr                   ; edx:eax = MSR value
            shl  rdx, 32
            or   rax, rdx
            mov  [rbp - 16], rax   ; store into result
        }
        return result;
    }

    // Syscall entry stub — must be a public naked fn so addrof_fn works.
    public naked void entry() {
        asm {
            mov [rel _user_rsp_scratch], rsp
            mov rsp, [rel _syscall_stack_top]

            push rcx        ; user RIP
            push r11        ; user rflags
            push rdi        ; arg0
            push rsi        ; arg1
            push rdx        ; arg2
            push rax        ; syscall number

            mov  rdi, rax
            mov  rsi, [rsp + 16]
            mov  rdx, [rsp + 24]
            mov  rcx, [rsp + 32]
            call Syscall__dispatch

            pop rax
            pop rdx
            pop rsi
            pop rdi
            pop r11
            pop rcx

            mov rsp, [rel _user_rsp_scratch]
            db 0x48, 0x0F, 0x07   ; sysretq
        }
    }

    // High-level dispatcher.
    public void dispatch(int num, uint64 a0, uint64 a1, uint64 a2) {
        int pid = Proc.current_pid();

        if (num == Syscall.SYS_EXIT) {
            Proc.exit(pid);
            return;
        }
        if (num == Syscall.SYS_YIELD) {
            Proc.schedule();
            return;
        }
        if (num == Syscall.SYS_SEND) {
            Ipc.send(pid, cast<int>(a0), a1);
            return;
        }
        if (num == Syscall.SYS_RECV) {
            Ipc.recv(pid, cast<int>(a0), a1);
            return;
        }
    }

    public void init() {
        _syscall_stack_top = cast<uint64>(&_syscall_stack) + 512 * 8;

        // Read current EFER and OR in SCE (bit 0) — never overwrite LME/LMA
        uint64 efer = rdmsr(Syscall.MSR_EFER);
        wrmsr(Syscall.MSR_EFER, efer | cast<uint64>(0x1));
        uint64 star = (cast<uint64>(0x0008) << 32) | (cast<uint64>(0x0013) << 48);
        wrmsr(Syscall.MSR_STAR,   star);
        wrmsr(Syscall.MSR_LSTAR,  addrof_fn(Syscall__entry));
        wrmsr(Syscall.MSR_SFMASK, cast<uint64>(0x200));

        println("Syscall ready.");
    }
}
