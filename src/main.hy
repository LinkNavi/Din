include {
    std.kernel,
}

void main() {
    println("Not even booting yet");
    vga_clear();
    vga_set_color(0x0F);
    println("Din kernel booting...");
    vga_set_color(0x07);
    println("Done.");
    while ( true) {
        cli();
        halt();
    }
}
