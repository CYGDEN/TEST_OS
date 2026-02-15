[BITS 16]
[ORG 0x7C00]

KERNEL_SEG equ 0x1000
KERNEL_OFF equ 0x0000
KERNEL_SECTORS equ 40

boot_start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl

    mov si, msg_s1
    call print16

    mov ax, KERNEL_SEG
    mov es, ax
    mov bx, KERNEL_OFF
    mov ah, 0x02
    mov al, KERNEL_SECTORS
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc .disk_fail

    mov si, msg_loaded
    call print16

    cli
    lgdt [gdt32_ptr]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x08:pm_entry

.disk_fail:
    mov si, msg_disk_err
    call print16
.halt16:
    cli
    hlt
    jmp .halt16

print16:
    lodsb
    test al, al
    jz .ret
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp print16
.ret:
    ret

boot_drive: db 0
msg_s1:       db "BOOT OK", 13, 10, 0
msg_loaded:   db "KERNEL LOADED", 13, 10, 0
msg_disk_err: db "DISK ERR", 13, 10, 0

ALIGN 8
gdt32:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt32_end:

gdt32_ptr:
    dw gdt32_end - gdt32 - 1
    dd gdt32

times 510-($-$$) db 0
dw 0xAA55

[BITS 32]
pm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    mov dword [0xB8000], 0x2F502F4D

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .no_long
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29
    jz .no_long
    jmp .has_long
.no_long:
    mov dword [0xB8000], 0x4F4E4F4F
    cli
    hlt
.has_long:

    mov dword [0xB8004], 0x2F4C2F4D

    mov edi, 0x70000
    xor eax, eax
    mov ecx, 0x4000
    rep stosd

    mov dword [0x70000], 0x71003
    mov dword [0x71000], 0x72003
    mov dword [0x72000], 0x73003

    mov edi, 0x73000
    mov ebx, 0x00000003
    mov ecx, 512
.map:
    mov dword [edi], ebx
    add ebx, 0x1000
    add edi, 8
    loop .map

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
    or eax, (1 << 31)
    mov cr0, eax

    lgdt [gdt64_ptr]
    jmp 0x08:long_entry

ALIGN 8
gdt64:
    dq 0x0000000000000000
    dq 0x00AF9A000000FFFF
    dq 0x00AF92000000FFFF
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dd gdt64

[BITS 64]
long_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x90000

    mov dword [0xB8008], 0x2F4D2F4C

    jmp 0x10000