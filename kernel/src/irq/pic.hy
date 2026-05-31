include {
    std.kernel,
    proc.proc,
}

static int _ticks;

module Pic {
    const int CMD1  = 0x20;
    const int DATA1 = 0x21;
    const int CMD2  = 0xA0;
    const int DATA2 = 0xA1;
    const int EOI   = 0x20;
    const int OFFSET1 = 0x20;   // IRQ0–7  → vectors 32–39
    const int OFFSET2 = 0x28;   // IRQ8–15 → vectors 40–47

    void io_wait() { outb(0x80, 0); }

    public void init() {
        _ticks = 0;

        // ICW1 — start init sequence
        outb(Pic.CMD1,  0x11); io_wait();
        outb(Pic.CMD2,  0x11); io_wait();
        // ICW2 — vector offsets
        outb(Pic.DATA1, Pic.OFFSET1); io_wait();
        outb(Pic.DATA2, Pic.OFFSET2); io_wait();
        // ICW3 — cascade wiring
        outb(Pic.DATA1, 0x04); io_wait();
        outb(Pic.DATA2, 0x02); io_wait();
        // ICW4 — 8086 mode
        outb(Pic.DATA1, 0x01); io_wait();
        outb(Pic.DATA2, 0x01); io_wait();
        // Mask all except IRQ0 (timer) and IRQ1 (keyboard)
        outb(Pic.DATA1, 0xFC);
        outb(Pic.DATA2, 0xFF);

        println("PIC remapped.");
    }

    // Send End-of-Interrupt.
    public void eoi(int irq) {
        if (irq >= 8) { outb(Pic.CMD2, Pic.EOI); }
        outb(Pic.CMD1, Pic.EOI);
    }

    // Timer IRQ0 handler.
    public void handle_timer() {
        _ticks = _ticks + 1;
        eoi(0);
        Proc.schedule();
    }

    // Keyboard IRQ1 handler — read and discard scancode.
    public void handle_keyboard() {
        int scancode = inb(0x60);
        eoi(1);
    }

    public int get_ticks() {
        return _ticks;
    }
}
