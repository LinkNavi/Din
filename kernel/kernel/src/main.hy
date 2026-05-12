include {
    std.kernel,
}

// Kernel entry point — loaded by Limine at 0xFFFFFFFF80100000.
// Receives no arguments; Limine fills in protocol response pointers before
// calling _start (which the compiler maps to this function).
void main() {
    vga_clear();
    vga_set_color(0x0F);    // bright white on black
    println("kernel kernel booting...");
    vga_set_color(0x07);    // restore default
    println("Done. Halting.");
    while (1 == 1) {
        cli();
        halt();
    }
}
