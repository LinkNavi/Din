include {
    std.kernel,

    gdt,
    idt,
    exceptions,
}

void main() {
    vga_clear();
    vga_set_color(0x0B); // bright cyan
    println("Din kernel v0.1.0");
    vga_set_color(0x07);

    Error? e = gdt_init();
    if (e) {
        vga_set_color(0x0C);
        println("GDT init failed!");
        vga_set_color(0x07);
    }

    e = idt_init();
    if (e) {
        vga_set_color(0x0C);
        println("IDT init failed!");
        vga_set_color(0x07);
    }

    vga_set_color(0x0A); // bright green
    println("Kernel ready. Halting.");
    vga_set_color(0x07);

    while (true) {
        cli();
        halt();
    }
}
