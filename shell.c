#include "shell.h"
#include "vga.h"
#include "keyboard.h"
#include "memory.h"

static uint64_t rng = 7777;
static uint64_t rand_next(void) {
    rng ^= rng << 13;
    rng ^= rng >> 7;
    rng ^= rng << 17;
    return rng;
}

static void prompt(void) {
    vga_set_col(10, 0);
    vga_puts("GOD");
    vga_set_col(15, 0);
    vga_puts("> ");
}

static void cmd_help(void) {
    vga_puts("help   - this\n");
    vga_puts("clear  - clear screen\n");
    vga_puts("info   - system info\n");
    vga_puts("divine - ask God\n");
    vga_puts("echo X - print X\n");
    vga_puts("mem    - heap info\n");
}

static void cmd_info(void) {
    vga_puts_col("=== TEMPLE OS CLONE ===\n", 0x0B);
    vga_puts("x86_64 Long Mode\n");
    vga_puts("Ring 0 only\n");
    vga_puts("VGA Text 80x25\n");
    vga_puts("No networking\n");
}

static void cmd_divine(void) {
    const char *w[] = {
        "God says: keep coding.\n",
        "The temple needs more walls.\n",
        "640x480 is divine resolution.\n",
        "Ring 0 is where angels live.\n",
        "Simplicity is next to godliness.\n",
        "CIA glows in the dark.\n",
        "Praise the 64-bit word.\n",
        "No networking. God wills it.\n",
    };
    vga_puts_col(w[rand_next() % 8], 0x0E);
}

static void execute(char *cmd) {
    if (strcmp(cmd, "help") == 0) cmd_help();
    else if (strcmp(cmd, "clear") == 0) vga_clear();
    else if (strcmp(cmd, "info") == 0) cmd_info();
    else if (strcmp(cmd, "divine") == 0) cmd_divine();
    else if (strcmp(cmd, "mem") == 0) {
        vga_puts("Heap: 0x200000, Size: 1MB\n");
    }
    else if (memcmp(cmd, "echo ", 5) == 0) {
        vga_puts(cmd + 5);
        vga_putc('\n');
    }
    else if (strlen(cmd) > 0) {
        vga_set_col(12, 0);
        vga_puts("Unknown: ");
        vga_puts(cmd);
        vga_putc('\n');
        vga_set_col(15, 0);
    }
}

void shell_init(void) {
    vga_set_col(11, 0);
    vga_puts(" _____ _____ __  __ ____  _     _____\n");
    vga_puts("|_   _| ____|  \\/  |  _ \\| |   | ____|\n");
    vga_puts("  | | |  _| | |\\/| | |_) | |   |  _|\n");
    vga_puts("  | | | |___| |  | |  __/| |___| |___\n");
    vga_puts("  |_| |_____|_|  |_|_|   |_____|_____|\n\n");
    vga_puts_col("  God's OS v0.1\n\n", 0x0E);
    vga_set_col(15, 0);
    vga_puts("Type 'help'\n\n");
}

void shell_run(void) {
    char cmd[256];
    int pos;
    while (1) {
        prompt();
        pos = 0;
        memset(cmd, 0, 256);
        while (1) {
            char c = kb_get();
            if (c == '\n') { vga_putc('\n'); break; }
            if (c == '\b') {
                if (pos > 0) {
                    pos--;
                    cmd[pos] = 0;
                    vga_putc('\b');
                }
            } else if (pos < 254) {
                cmd[pos++] = c;
                vga_putc(c);
            }
        }
        cmd[pos] = 0;
        execute(cmd);
    }
}