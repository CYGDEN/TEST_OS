#include "vga.h"
#include "keyboard.h"
#include "memory.h"
#include "shell.h"

static inline void outb(uint16_t p, uint8_t v) {
    __asm__ volatile("outb %0, %1"::"a"(v),"Nd"(p));
}

struct idt_entry {
    uint16_t off_lo;
    uint16_t sel;
    uint8_t ist;
    uint8_t flags;
    uint16_t off_mid;
    uint32_t off_hi;
    uint32_t zero;
} __attribute__((packed));

struct idt_ptr {
    uint16_t limit;
    uint64_t base;
} __attribute__((packed));

static struct idt_entry idt[256];
static struct idt_ptr idtp;

extern void isr_keyboard(void);

static void idt_set(int n, uint64_t h) {
    idt[n].off_lo = h & 0xFFFF;
    idt[n].sel = 0x08;
    idt[n].ist = 0;
    idt[n].flags = 0x8E;
    idt[n].off_mid = (h >> 16) & 0xFFFF;
    idt[n].off_hi = (h >> 32) & 0xFFFFFFFF;
    idt[n].zero = 0;
}

static void pic_init(void) {
    outb(0x20, 0x11);
    outb(0xA0, 0x11);
    outb(0x21, 0x20);
    outb(0xA1, 0x28);
    outb(0x21, 0x04);
    outb(0xA1, 0x02);
    outb(0x21, 0x01);
    outb(0xA1, 0x01);
    outb(0x21, 0xFD);
    outb(0xA1, 0xFF);
}

void kernel_main(void) {
    vga_init();
    mem_init();

    for (int i = 0; i < 256; i++)
        memset(&idt[i], 0, sizeof(struct idt_entry));

    pic_init();
    idt_set(0x21, (uint64_t)isr_keyboard);

    idtp.limit = sizeof(idt) - 1;
    idtp.base = (uint64_t)&idt;
    __asm__ volatile("lidt %0"::"m"(idtp));
    __asm__ volatile("sti");

    shell_init();
    shell_run();
}