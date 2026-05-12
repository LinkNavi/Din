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
        mov rdi, 0x4F
        call hylian_vga_set_color
        lea rdi, [rel .name]
        mov rsi, 25
        call hylian_println
        ; print cr2
        mov rax, cr2
        mov rdi, 0x07
        call hylian_vga_set_color
        lea rdi, [rel .cr2msg]
        mov rsi, 15
        call hylian_print
        sub rsp, 32
        mov rdi, rax
        mov rsi, rsp
        mov rdx, 32
        call hylian_int_to_str
        mov rsi, rax
        mov rdi, rsp
        call hylian_println
        add rsp, 32
        call exception_halt
    .name:   db "EXCEPTION #PF: Page Fault", 0
    .cr2msg: db "Fault address: ", 0
    }
}
