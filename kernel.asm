[BITS 64]
[ORG 0x10000]

kernel_main:
    mov dword [0xB800C], 0x2F4B2F4F

    call vga_clear

    call pic_init
    call idt_setup
    lidt [idt_ptr]
    sti

    call shell_banner
    call shell_loop

    cli
.dead:
    hlt
    jmp .dead

VGA_BUF equ 0xB8000
VGA_W   equ 80
VGA_HT  equ 25

vga_x:     dw 0
vga_y:     dw 0
vga_color: db 0x0F

vga_clear:
    push rax
    push rcx
    push rdi
    mov rdi, VGA_BUF
    movzx ax, byte [vga_color]
    shl ax, 8
    or ax, 0x20
    mov rcx, VGA_W * VGA_HT
    rep stosw
    mov word [vga_x], 0
    mov word [vga_y], 0
    pop rdi
    pop rcx
    pop rax
    ret

vga_scroll:
    push rax
    push rcx
    push rsi
    push rdi
    mov rsi, VGA_BUF + VGA_W * 2
    mov rdi, VGA_BUF
    mov rcx, VGA_W * (VGA_HT - 1)
    rep movsw
    movzx ax, byte [vga_color]
    shl ax, 8
    or ax, 0x20
    mov rcx, VGA_W
    rep stosw
    mov word [vga_y], VGA_HT - 1
    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

vga_putc:
    push rbx
    push rcx
    push rdx

    cmp al, 10
    je .newline
    cmp al, 8
    je .backspace

    movzx rbx, word [vga_y]
    imul rbx, VGA_W
    movzx rcx, word [vga_x]
    add rbx, rcx
    shl rbx, 1
    add rbx, VGA_BUF
    mov ah, [vga_color]
    mov [rbx], ax

    inc word [vga_x]
    cmp word [vga_x], VGA_W
    jl .done
    mov word [vga_x], 0
    inc word [vga_y]
    jmp .check_scroll

.newline:
    mov word [vga_x], 0
    inc word [vga_y]
    jmp .check_scroll

.backspace:
    cmp word [vga_x], 0
    je .done
    dec word [vga_x]
    movzx rbx, word [vga_y]
    imul rbx, VGA_W
    movzx rcx, word [vga_x]
    add rbx, rcx
    shl rbx, 1
    add rbx, VGA_BUF
    mov word [rbx], 0x0F20
    jmp .done

.check_scroll:
    cmp word [vga_y], VGA_HT
    jl .done
    call vga_scroll
.done:
    pop rdx
    pop rcx
    pop rbx
    ret

vga_puts:
    push rsi
    push rax
.loop:
    lodsb
    test al, al
    jz .ret
    call vga_putc
    jmp .loop
.ret:
    pop rax
    pop rsi
    ret

vga_puts_col:
    push rax
    mov [vga_color], ah
    call vga_puts
    mov byte [vga_color], 0x0F
    pop rax
    ret

pic_init:
    push rax
    mov al, 0x11
    out 0x20, al
    out 0xA0, al
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al
    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al
    mov al, 0x01
    out 0x21, al
    out 0xA1, al
    mov al, 0xFD
    out 0x21, al
    mov al, 0xFF
    out 0xA1, al
    pop rax
    ret

idt_setup:
    push rax
    push rcx
    push rdi

    mov rdi, idt_table
    xor rax, rax
    mov rcx, 256 * 2
    rep stosq

    mov rdi, idt_table + 33 * 16
    mov rax, kb_isr
    mov word [rdi], ax
    mov word [rdi+2], 0x08
    mov byte [rdi+4], 0
    mov byte [rdi+5], 0x8E
    shr rax, 16
    mov word [rdi+6], ax
    shr rax, 16
    mov dword [rdi+8], eax
    mov dword [rdi+12], 0

    pop rdi
    pop rcx
    pop rax
    ret

idt_ptr:
    dw 256 * 16 - 1
    dq idt_table

kb_isr:
    push rax
    push rbx
    push rcx
    push rsi

    xor eax, eax
    in al, 0x60

    test al, 0x80
    jnz .eoi

    cmp al, 58
    jge .eoi

    lea rsi, [scancode_table]
    movzx rbx, al
    mov al, [rsi + rbx]
    test al, al
    jz .eoi

    movzx rbx, word [kb_head]
    mov [kb_buf + rbx], al
    inc bl
    mov [kb_head], bx

.eoi:
    mov al, 0x20
    out 0x20, al

    pop rsi
    pop rcx
    pop rbx
    pop rax
    iretq

scancode_table:
    db 0, 27
    db '1','2','3','4','5','6','7','8','9','0','-','='
    db 8, 9
    db 'q','w','e','r','t','y','u','i','o','p','[',']'
    db 10, 0
    db 'a','s','d','f','g','h','j','k','l',';',39,'`'
    db 0,'\'
    db 'z','x','c','v','b','n','m',',','.','/'
    db 0,'*',0,' '

kb_buf:  times 256 db 0
kb_head: dw 0
kb_tail: dw 0

kb_getchar:
.wait:
    hlt
    movzx eax, word [kb_head]
    cmp ax, word [kb_tail]
    je .wait
    movzx rbx, word [kb_tail]
    mov al, [kb_buf + rbx]
    inc bl
    mov [kb_tail], bx
    ret

shell_banner:
    push rax
    push rsi

    mov ah, 0x0B
    mov rsi, str_b1
    call vga_puts_col
    mov rsi, str_b2
    call vga_puts_col
    mov rsi, str_b3
    call vga_puts_col
    mov rsi, str_b4
    call vga_puts_col
    mov rsi, str_b5
    call vga_puts_col

    mov ah, 0x0E
    mov rsi, str_sub
    call vga_puts_col

    mov rsi, str_hint
    call vga_puts

    pop rsi
    pop rax
    ret

shell_loop:
    call show_prompt
    mov rdi, cmd_buf
    xor ecx, ecx

.read:
    call kb_getchar

    cmp al, 10
    je .exec
    cmp al, 8
    je .bksp
    cmp cl, 253
    jge .read

    mov [rdi + rcx], al
    inc cl
    call vga_putc
    jmp .read

.bksp:
    test cl, cl
    jz .read
    dec cl
    mov byte [rdi + rcx], 0
    mov al, 8
    call vga_putc
    jmp .read

.exec:
    mov byte [rdi + rcx], 0
    mov al, 10
    call vga_putc
    call run_cmd
    jmp shell_loop

show_prompt:
    push rax
    push rsi
    mov byte [vga_color], 0x0A
    mov rsi, str_god
    call vga_puts
    mov byte [vga_color], 0x0F
    mov rsi, str_arrow
    call vga_puts
    pop rsi
    pop rax
    ret

run_cmd:
    push rax
    push rsi
    push rdi

    mov rsi, cmd_buf
    mov rdi, cmd_help
    call str_cmp
    jz .do_help

    mov rsi, cmd_buf
    mov rdi, cmd_clear
    call str_cmp
    jz .do_clear

    mov rsi, cmd_buf
    mov rdi, cmd_info
    call str_cmp
    jz .do_info

    mov rsi, cmd_buf
    mov rdi, cmd_divine
    call str_cmp
    jz .do_divine

    cmp byte [cmd_buf], 0
    je .ret

    mov byte [vga_color], 0x0C
    mov rsi, str_unk
    call vga_puts
    mov rsi, cmd_buf
    call vga_puts
    mov al, 10
    call vga_putc
    mov byte [vga_color], 0x0F
    jmp .ret

.do_help:
    mov rsi, str_helptext
    call vga_puts
    jmp .ret

.do_clear:
    call vga_clear
    jmp .ret

.do_info:
    mov ah, 0x0B
    mov rsi, str_info
    call vga_puts_col
    jmp .ret

.do_divine:
    rdtsc
    and eax, 0x07
    lea rbx, [divine_ptrs]
    mov rsi, [rbx + rax * 8]
    mov ah, 0x0E
    call vga_puts_col
    jmp .ret

.ret:
    pop rdi
    pop rsi
    pop rax
    ret

str_cmp:
    push rsi
    push rdi
.cloop:
    mov al, [rsi]
    mov ah, [rdi]
    cmp al, ah
    jne .cneq
    test al, al
    jz .ceq
    inc rsi
    inc rdi
    jmp .cloop
.ceq:
    pop rdi
    pop rsi
    xor eax, eax
    ret
.cneq:
    pop rdi
    pop rsi
    mov eax, 1
    ret

cmd_buf: times 256 db 0

str_god:   db "GOD", 0
str_arrow: db "> ", 0

cmd_help:   db "help", 0
cmd_clear:  db "clear", 0
cmd_info:   db "info", 0
cmd_divine: db "divine", 0

str_b1: db " _____ _____ __  __ ____  _     _____", 10, 0
str_b2: db "|_   _| ____|  \/  |  _ \| |   | ____|", 10, 0
str_b3: db "  | | |  _| | |\/| | |_) | |   |  _|", 10, 0
str_b4: db "  | | | |___| |  | |  __/| |___| |___", 10, 0
str_b5: db "  |_| |_____|_|  |_|_|   |_____|_____|", 10, 10, 0

str_sub:  db "  God's OS v0.1", 10, 10, 0
str_hint: db "Type 'help' for commands.", 10, 10, 0

str_helptext:
    db "help   - this message", 10
    db "clear  - clear screen", 10
    db "info   - system info", 10
    db "divine - ask God", 10, 0

str_info:
    db "=== TEMPLE OS CLONE ===", 10
    db "x86_64 Long Mode", 10
    db "Ring 0", 10
    db "VGA Text 80x25", 10
    db "No networking", 10, 0

str_unk: db "Unknown: ", 0

div0: db "God says: keep coding.", 10, 0
div1: db "The temple needs more walls.", 10, 0
div2: db "640x480 is divine.", 10, 0
div3: db "Ring 0 is where angels live.", 10, 0
div4: db "Simplicity is godliness.", 10, 0
div5: db "CIA glows in the dark.", 10, 0
div6: db "Praise the 64-bit word.", 10, 0
div7: db "No networking. God wills it.", 10, 0

divine_ptrs:
    dq div0, div1, div2, div3
    dq div4, div5, div6, div7

align 16
idt_table: times 256 dq 0, 0