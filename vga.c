#include "vga.h"

static uint16_t *vb = (uint16_t*)0xB8000;
static int cx = 0, cy = 0;
static uint8_t cc = 0x0F;

void vga_init(void) {
    vb = (uint16_t*)0xB8000;
    cc = 0x0F;
    vga_clear();
}

void vga_clear(void) {
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++)
        vb[i] = ' ' | (cc << 8);
    cx = 0;
    cy = 0;
}

static void scroll(void) {
    for (int i = 0; i < VGA_WIDTH * (VGA_HEIGHT - 1); i++)
        vb[i] = vb[i + VGA_WIDTH];
    for (int i = VGA_WIDTH * (VGA_HEIGHT - 1); i < VGA_WIDTH * VGA_HEIGHT; i++)
        vb[i] = ' ' | (cc << 8);
    cy = VGA_HEIGHT - 1;
}

void vga_putc(char c) {
    if (c == '\n') {
        cx = 0; cy++;
    } else if (c == '\b') {
        if (cx > 0) {
            cx--;
            vb[cy * VGA_WIDTH + cx] = ' ' | (cc << 8);
        }
    } else if (c == '\t') {
        cx = (cx + 8) & ~7;
    } else {
        vb[cy * VGA_WIDTH + cx] = c | (cc << 8);
        cx++;
    }
    if (cx >= VGA_WIDTH) { cx = 0; cy++; }
    if (cy >= VGA_HEIGHT) scroll();
}

void vga_puts(const char *s) {
    while (*s) vga_putc(*s++);
}

void vga_set_col(uint8_t fg, uint8_t bg) {
    cc = (bg << 4) | fg;
}

void vga_puts_col(const char *s, uint8_t col) {
    uint8_t old = cc;
    cc = col;
    vga_puts(s);
    cc = old;
}

void vga_hex(uint64_t v) {
    const char *h = "0123456789ABCDEF";
    vga_puts("0x");
    for (int i = 60; i >= 0; i -= 4)
        vga_putc(h[(v >> i) & 0xF]);
}

void vga_dec(int v) {
    if (v == 0) { vga_putc('0'); return; }
    if (v < 0) { vga_putc('-'); v = -v; }
    char b[12];
    int i = 0;
    while (v > 0) { b[i++] = '0' + v % 10; v /= 10; }
    while (--i >= 0) vga_putc(b[i]);
}