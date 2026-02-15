#ifndef _MEMORY_H_
#define _MEMORY_H_

#include "vga.h"

void mem_init(void);
void *malloc(size_t sz);
void free(void *p);
void *memset(void *s, int c, size_t n);
void *memcpy(void *d, const void *s, size_t n);
int memcmp(const void *a, const void *b, size_t n);
size_t strlen(const char *s);
int strcmp(const char *a, const char *b);

#endif