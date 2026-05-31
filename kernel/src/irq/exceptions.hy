include {
    std.kernel,
    irq.pic,
}

module Exceptions {
    // Spin forever — used by fatal handlers.
    void halt_forever() {
        while (true) {
            cli();
            halt();
        }
    }

    // ── Exception handlers ────────────────────────────────────────────────────

    public void handle_div_zero() {
        vga_set_color(0x4F);
        println("EXCEPTION #DE: Division by Zero");
        halt_forever();
    }

    public void handle_invalid_opcode() {
        vga_set_color(0x4F);
        println("EXCEPTION #UD: Invalid Opcode");
        halt_forever();
    }

    public void handle_double_fault() {
        vga_set_color(0x4F);
        println("EXCEPTION #DF: Double Fault");
        halt_forever();
    }

    public void handle_gpf() {
        vga_set_color(0x4F);
        println("EXCEPTION #GP: General Protection");
        halt_forever();
    }

    public void handle_page_fault() {
        uint64 fault_addr = read_cr(2);
        vga_set_color(0x4F);
        println("EXCEPTION #PF: Page Fault");
        vga_set_color(0x07);
        print("Fault address: ");
        println(fault_addr);
        halt_forever();
    }
}

// ── Naked ISR stubs ───────────────────────────────────────────────────────────
// These must be top-level naked functions (not inside a module) so their
// symbols are globally visible for addrof_fn() and the IDT registration.

// CPU exceptions — no error code pushed by CPU
naked void isr0() {
    save_regs(1); cli();
    Exceptions.handle_div_zero();
    restore_regs(1); iret();
}

naked void isr6() {
    save_regs(1); cli();
    Exceptions.handle_invalid_opcode();
    restore_regs(1); iret();
}

// CPU exceptions — CPU pushes an error code
naked void isr8() {
    save_regs(); cli();
    Exceptions.handle_double_fault();
    restore_regs(1); iret();
}

naked void isr13() {
    save_regs(); cli();
    Exceptions.handle_gpf();
    restore_regs(1); iret();
}

naked void isr14() {
    save_regs(); cli();
    Exceptions.handle_page_fault();
    restore_regs(1); iret();
}

// Hardware IRQs — no CPU error code
naked void isr32() {
    save_regs(1);
    Pic.handle_timer();
    restore_regs(1); iret();
}

naked void isr33() {
    save_regs(1);
    Pic.handle_keyboard();
    restore_regs(1); iret();
}
