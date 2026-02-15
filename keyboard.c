#include "keyboard.h"

static inline void outb(uint16_t p, uint8_t v) {
    __asm__ volatile("outb %0, %1"::"a"(v),"Nd"(p));
}
static inline uint8_t inb(uint16_t p) {
    uint8_t r;
    __asm__ volatile("inb %1, %0":"=a"(r):"Nd"(p));
    return r;
}

static const char sc_ascii[128] = {
    0,27,'1','2','3','4','5','6','7','8','9','0','-','=','\b',
    '\t','q','w','e','r','t','y','u','i','o','p','[',']','\n',
    0,'a','s','d','f','g','h','j','k','l',';','\'','`',
    0,'\\','z','x','c','v','b','n','m',',','.','/',0,
    '*',0,' '
};

#define KBUF 256
static char kbuf[KBUF];
static volatile int kh = 0, kt = 0;

void keyboard_handler_c(void) {
    uint8_t sc = inb(0x60);
    if (!(sc & 0x80)) {
        char c = (sc < 58) ? sc_ascii[sc] : 0;
        if (c) {
            int n = (kh + 1) % KBUF;
            if (n != kt) {
                kbuf[kh] = c;
                kh = n;
            }
        }
    }
    outb(0x20, 0x20);
}

int kb_ready(void) { return kh != kt; }

char kb_get(void) {
    while (!kb_ready()) __asm__ volatile("hlt");
    char c = kbuf[kt];
    kt = (kt + 1) % KBUF;
    return c;
}