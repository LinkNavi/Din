include {
    std.kernel,
    boot.gdt,
    irq.exceptions,
    irq.idt,
    mm.pmm,
    mm.heap,
    proc.proc,
    proc.syscall,
}

void main() {
    vga_clear();
    vga_set_color(0x0B);
    println("Din kernel v0.1.0");
    vga_set_color(0x07);

    Gdt.init();

    Error? e = Idt.init();
    if (e) {
        vga_set_color(0x0C);
        println("IDT init failed!");
        vga_set_color(0x07);
    }

    sti();

    vga_set_color(0x0A);
    println("Interrupts enabled.");
    vga_set_color(0x07);

    Pmm.init();
    Heap.init();
    Proc.init();
    Syscall.init();

    vga_set_color(0x0A);
    println("Kernel ready.");
    vga_set_color(0x07);

    while (true) {
        cli();
        halt();
    }
}
