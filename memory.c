#include "memory.h"

#define HEAP_START 0x200000ULL
#define HEAP_SIZE  0x100000ULL

struct blk {
    size_t size;
    int free;
    struct blk *next;
};

#define BLK sizeof(struct blk)

static struct blk *heap = 0;

void mem_init(void) {
    heap = (struct blk*)HEAP_START;
    heap->size = HEAP_SIZE - BLK;
    heap->free = 1;
    heap->next = 0;
}

void *malloc(size_t sz) {
    sz = (sz + 15) & ~15;
    struct blk *c = heap;
    while (c) {
        if (c->free && c->size >= sz) {
            if (c->size > sz + BLK + 16) {
                struct blk *n = (struct blk*)((uint8_t*)c + BLK + sz);
                n->size = c->size - sz - BLK;
                n->free = 1;
                n->next = c->next;
                c->next = n;
                c->size = sz;
            }
            c->free = 0;
            return (void*)((uint8_t*)c + BLK);
        }
        c = c->next;
    }
    return 0;
}

void free(void *p) {
    if (!p) return;
    struct blk *h = (struct blk*)((uint8_t*)p - BLK);
    h->free = 1;
    struct blk *c = heap;
    while (c) {
        if (c->free && c->next && c->next->free) {
            c->size += BLK + c->next->size;
            c->next = c->next->next;
            continue;
        }
        c = c->next;
    }
}

void *memset(void *s, int c, size_t n) {
    uint8_t *p = s;
    while (n--) *p++ = c;
    return s;
}

void *memcpy(void *d, const void *s, size_t n) {
    uint8_t *dd = d; const uint8_t *ss = s;
    while (n--) *dd++ = *ss++;
    return d;
}

int memcmp(const void *a, const void *b, size_t n) {
    const uint8_t *x = a, *y = b;
    while (n--) { if (*x != *y) return *x - *y; x++; y++; }
    return 0;
}

size_t strlen(const char *s) {
    size_t l = 0;
    while (*s++) l++;
    return l;
}

int strcmp(const char *a, const char *b) {
    while (*a && *a == *b) { a++; b++; }
    return *(uint8_t*)a - *(uint8_t*)b;
}