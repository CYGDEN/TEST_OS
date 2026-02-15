#ifndef _KEYBOARD_H_
#define _KEYBOARD_H_

#include "vga.h"

void kb_init(void);
void keyboard_handler_c(void);
char kb_get(void);
int kb_ready(void);

#endif