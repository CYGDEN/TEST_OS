[BITS 16]
[ORG 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    mov [drive], dl
    mov ax, 0x0003
    int 0x10
    mov ah, 0x02
    mov al, 60
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [drive]
    mov bx, 0x7E00
    int 0x13
    jc .fail
    jmp 0x0000:stage2
.fail:
    jmp $
drive: db 0
times 510-($-$$) db 0
dw 0xAA55

stage2:
    cli
    lgdt [gdt32d]
    mov eax, cr0
    or al, 1
    mov cr0, eax
    jmp 0x08:pm

ALIGN 8
gdt32:
    dq 0
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt32d:
    dw 23
    dd gdt32

[BITS 32]
pm:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000
    mov edi, 0x70000
    xor eax, eax
    mov ecx, 4096
    rep stosd
    mov dword [0x70000], 0x71003
    mov dword [0x71000], 0x72003
    mov dword [0x72000], 0x73003
    mov edi, 0x73000
    mov ebx, 3
    mov ecx, 512
.pg:
    mov [edi], ebx
    mov dword [edi+4], 0
    add ebx, 0x1000
    add edi, 8
    loop .pg
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax
    mov eax, 0x70000
    mov cr3, eax
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax
    lgdt [gdt64d]
    jmp 0x08:lm

ALIGN 8
gdt64:
    dq 0
    dq 0x00AF9A000000FFFF
    dq 0x00AF92000000FFFF
gdt64d:
    dw 23
    dd gdt64

[BITS 64]
lm:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov rsp, 0x90000

    mov rdi, 0xB8000
    mov ax, 0x0F20
    mov rcx, 2000
    rep stosw
    mov word [vga_x], 0
    mov word [vga_y], 0

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
    mov al, 0xFC
    out 0x21, al
    mov al, 0xFF
    out 0xA1, al

    mov rdi, idt
    xor rax, rax
    mov rcx, 512
    rep stosq

    mov rax, tmr_isr
    mov rdi, idt + 32*16
    mov word [rdi], ax
    mov word [rdi+2], 0x08
    mov byte [rdi+4], 0
    mov byte [rdi+5], 0x8E
    shr rax, 16
    mov word [rdi+6], ax
    shr rax, 16
    mov dword [rdi+8], eax
    mov dword [rdi+12], 0

    mov rax, kb_isr
    mov rdi, idt + 33*16
    mov word [rdi], ax
    mov word [rdi+2], 0x08
    mov byte [rdi+4], 0
    mov byte [rdi+5], 0x8E
    shr rax, 16
    mov word [rdi+6], ax
    shr rax, 16
    mov dword [rdi+8], eax
    mov dword [rdi+12], 0

    mov rax, idt
    mov [idtd+2], rax
    lidt [idtd]
    sti

    call banner

shell:
    call prompt

    mov r12, cbuf
    xor r13d, r13d

    mov rdi, r12
    xor al, al
    mov rcx, 256
    rep stosb

.rd:
    call kget

    cmp al, 10
    je .run
    cmp al, 8
    je .bk
    cmp r13d, 250
    jge .rd

    mov [r12 + r13], al
    inc r13d
    call putchar
    jmp .rd

.bk:
    test r13d, r13d
    jz .rd
    dec r13d
    mov byte [r12 + r13], 0
    mov al, 8
    call putchar
    jmp .rd

.run:
    mov byte [r12 + r13], 0
    mov al, 10
    call putchar
    call docmd
    jmp shell

prompt:
    push rsi
    mov byte [vga_c], 0x0A
    mov rsi, sg
    call printstr
    mov byte [vga_c], 0x0F
    mov rsi, sa
    call printstr
    pop rsi
    ret

docmd:
    push rsi
    push rdi
    push rax
    push rbx

    cmp byte [cbuf], 0
    je .done

    mov rsi, cbuf
    mov rdi, cmd_help
    call scmp
    je .xhelp

    mov rsi, cbuf
    mov rdi, cmd_clear
    call scmp
    je .xclr

    mov rsi, cbuf
    mov rdi, cmd_info
    call scmp
    je .xinfo

    mov rsi, cbuf
    mov rdi, cmd_div
    call scmp
    je .xdiv

    mov byte [vga_c], 0x0C
    mov rsi, su
    call printstr
    mov rsi, cbuf
    call printstr
    mov al, 10
    call putchar
    mov byte [vga_c], 0x0F
    jmp .done

.xhelp:
    mov rsi, htxt
    call printstr
    jmp .done
.xclr:
    mov rdi, 0xB8000
    mov ax, 0x0F20
    mov rcx, 2000
    rep stosw
    mov word [vga_x], 0
    mov word [vga_y], 0
    jmp .done
.xinfo:
    mov byte [vga_c], 0x0B
    mov rsi, sinf
    call printstr
    mov byte [vga_c], 0x0F
    jmp .done
.xdiv:
    rdtsc
    and eax, 7
    mov rbx, dp
    mov rsi, [rbx+rax*8]
    mov byte [vga_c], 0x0E
    call printstr
    mov byte [vga_c], 0x0F
    jmp .done

.done:
    pop rbx
    pop rax
    pop rdi
    pop rsi
    ret

scmp:
    push rcx
    xor ecx, ecx
.cl:
    mov al, [rsi+rcx]
    mov ah, [rdi+rcx]
    cmp al, ah
    jne .ne
    test al, al
    jz .eq
    inc ecx
    jmp .cl
.eq:
    pop rcx
    xor eax, eax
    ret
.ne:
    pop rcx
    mov eax, 1
    cmp eax, 0
    ret

kget:
    xor eax, eax
.spin:
    mov al, [kh]
    cmp al, [kt]
    jne .got
    pause
    jmp .spin
.got:
    xor ebx, ebx
    mov bl, [kt]
    xor eax, eax
    mov al, [kbuf + rbx]
    inc bl
    mov [kt], bl
    ret

banner:
    push rsi
    mov byte [vga_c], 0x0B
    mov rsi, b1
    call printstr
    mov rsi, b2
    call printstr
    mov rsi, b3
    call printstr
    mov rsi, b4
    call printstr
    mov rsi, b5
    call printstr
    mov byte [vga_c], 0x0E
    mov rsi, bsub
    call printstr
    mov byte [vga_c], 0x0F
    mov rsi, bhint
    call printstr
    pop rsi
    ret

idtd:
    dw 4095
    dq 0

vga_x: dw 0
vga_y: dw 0
vga_c: db 0x0F

putchar:
    push rbx
    push rcx

    cmp al, 10
    je .nl
    cmp al, 8
    je .bs

    movzx rbx, word [vga_y]
    imul rbx, 80
    movzx rcx, word [vga_x]
    add rbx, rcx
    shl rbx, 1
    add rbx, 0xB8000
    mov ah, [vga_c]
    mov [rbx], ax
    inc word [vga_x]
    cmp word [vga_x], 80
    jl .done
    mov word [vga_x], 0
    inc word [vga_y]
    jmp .chk

.nl:
    mov word [vga_x], 0
    inc word [vga_y]
    jmp .chk

.bs:
    cmp word [vga_x], 0
    je .done
    dec word [vga_x]
    movzx rbx, word [vga_y]
    imul rbx, 80
    movzx rcx, word [vga_x]
    add rbx, rcx
    shl rbx, 1
    add rbx, 0xB8000
    mov word [rbx], 0x0F20
    jmp .done

.chk:
    cmp word [vga_y], 25
    jl .done
    call scroll
.done:
    pop rcx
    pop rbx
    ret

scroll:
    push rsi
    push rdi
    push rax
    push rcx
    mov rsi, 0xB8000 + 160
    mov rdi, 0xB8000
    mov rcx, 80*24
    rep movsw
    mov ax, 0x0F20
    mov rcx, 80
    rep stosw
    mov word [vga_y], 24
    pop rcx
    pop rax
    pop rdi
    pop rsi
    ret

printstr:
    push rax
    push rsi
.lp:
    lodsb
    test al, al
    jz .dn
    call putchar
    jmp .lp
.dn:
    pop rsi
    pop rax
    ret

tmr_isr:
    push rax
    mov al, 0x20
    out 0x20, al
    pop rax
    iretq

kb_isr:
    push rax
    push rbx
    xor eax, eax
    in al, 0x60
    test al, 0x80
    jnz .eoi
    cmp al, 58
    jge .eoi
    movzx ebx, al
    mov al, [sc_tab + rbx]
    test al, al
    jz .eoi
    xor ebx, ebx
    mov bl, [kh]
    mov [kbuf + rbx], al
    inc bl
    mov [kh], bl
.eoi:
    mov al, 0x20
    out 0x20, al
    pop rbx
    pop rax
    iretq

sc_tab:
    db 0,27,'1','2','3','4','5','6','7','8','9','0','-','=',8,9
    db 'q','w','e','r','t','y','u','i','o','p','[',']',10,0
    db 'a','s','d','f','g','h','j','k','l',';',39,'`',0,92
    db 'z','x','c','v','b','n','m',',','.','/',0,'*',0,' '

kbuf: times 256 db 0
kh: db 0
kt: db 0

cbuf: times 256 db 0
sg: db "GOD",0
sa: db "> ",0
cmd_help:  db "help",0
cmd_clear: db "clear",0
cmd_info:  db "info",0
cmd_div:   db "divine",0
su: db "Unknown: ",0

b1: db " _____ _____ __  __ ____  _     _____",10,0
b2: db "|_   _| ____|  \/  |  _ \| |   | ____|",10,0
b3: db "  | | |  _| | |\/| | |_) | |   |  _|",10,0
b4: db "  | | | |___| |  | |  __/| |___| |___",10,0
b5: db "  |_| |_____|_|  |_|_|   |_____|_____|",10,10,0
bsub: db "  God's OS v0.1",10,10,0
bhint: db "Type 'help' for commands.",10,10,0

htxt:
    db "help   - show this",10
    db "clear  - clear screen",10
    db "info   - system info",10
    db "divine - ask God",10,0

sinf: db "=== TEMPLE OS CLONE ===",10
      db "x86_64 Long Mode",10
      db "Ring 0 only",10
      db "VGA Text 80x25",10
      db "No networking",10,0

d0: db "God says: keep coding.",10,0
d1: db "The temple needs walls.",10,0
d2: db "640x480 is divine.",10,0
d3: db "Ring 0 is for angels.",10,0
d4: db "Simplicity is holy.",10,0
d5: db "CIA glows in the dark.",10,0
d6: db "Praise 64-bit.",10,0
d7: db "No networking ever.",10,0

dp: dq d0,d1,d2,d3,d4,d5,d6,d7

ALIGN 16
idt: times 4096 db 0