include {
    std.kernel,
}

void exception_halt() {
    while (true) {
        cli();
        halt();
    }
}

naked void isr0() {
    asm{
        cli
        push 0
        push r15
        push r14
        push r13
        push r12
        push r11
        push r10
        push r9
        push r8
        push rbp
        push rdi
        push rsi
        push rdx
        push rcx
        push rbx
        push rax
        mov rdi, 0x4F
        call hylian_vga_set_color
        lea rdi, [rel .name]
        mov rsi, 31
        call hylian_println
        call exception_halt
    .name: db "EXCEPTION #DE: Division by Zero", 0
    }
}

naked void isr6() {
    asm{
        cli
        push 0
        push r15
        push r14
        push r13
        push r12
        push r11
        push r10
        push r9
        push r8
        push rbp
        push rdi
        push rsi
        push rdx
        push rcx
        push rbx
        push rax
        mov rdi, 0x4F
        call hylian_vga_set_color
        lea rdi, [rel .name]
        mov rsi, 29
        call hylian_println
        call exception_halt
    .name: db "EXCEPTION #UD: Invalid Opcode", 0
    }
}

naked void isr8() {
    asm{
        cli
        push r15
        push r14
        push r13
        push r12
        push r11
        push r10
        push r9
        push r8
        push rbp
        push rdi
        push rsi
        push rdx
        push rcx
        push rbx
        push rax
        mov rdi, 0x4F
        call hylian_vga_set_color
        lea rdi, [rel .name]
        mov rsi, 27
        call hylian_println
        call exception_halt
    .name: db "EXCEPTION #DF: Double Fault", 0
    }
}

naked void isr13() {
    asm{
        cli
        push r15
        push r14
        push r13
        push r12
        push r11
        push r10
        push r9
        push r8
        push rbp
        push rdi
        push rsi
        push rdx
        push rcx
        push rbx
        push rax
        mov rdi, 0x4F
        call hylian_vga_set_color
        lea rdi, [rel .name]
        mov rsi, 33
        call hylian_println
        call exception_halt
    .name: db "EXCEPTION #GP: General Protection", 0
    }
}

void _handle_page_fault() {
    uint64 fault_addr = read_cr(2);
    vga_set_color(0x4F);
    println("EXCEPTION #PF: Page Fault");
    vga_set_color(0x07);
    print("Fault address: ");
    println(fault_addr);
    exception_halt();
}

naked void isr14() {
    asm{
        cli
        push r15
        push r14
        push r13
        push r12
        push r11
        push r10
        push r9
        push r8
        push rbp
        push rdi
        push rsi
        push rdx
        push rcx
        push rbx
        push rax
        call _handle_page_fault
    }
}
