#ifndef _VGA_H_
#define _VGA_H_

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;
typedef uint64_t size_t;

#define VGA_WIDTH 80
#define VGA_HEIGHT 25
#define VGA_MEM ((uint16_t*)0xB8000)

void vga_init(void);
void vga_clear(void);
void vga_putc(char c);
void vga_puts(const char *s);
void vga_puts_col(const char *s, uint8_t col);
void vga_set_col(uint8_t fg, uint8_t bg);
void vga_hex(uint64_t v);
void vga_dec(int v);

#endif