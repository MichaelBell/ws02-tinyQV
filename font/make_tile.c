
#include "font.h"
#include <stdio.h>

#define FONT (&intel_one_mono)

uint32_t render_char_line(int c, int y) {
    if (c < 0x20 || c > 0x7e) return 0;
    const lv_font_fmt_txt_glyph_dsc_t* g = &FONT->dsc->glyph_dsc[c - 0x20 + 1];
    const uint8_t *b = FONT->dsc->glyph_bitmap + g->bitmap_index;
    const int ey = y - FONT_HEIGHT + FONT->base_line + g->ofs_y + g->box_h;
    if (ey < 0 || ey >= g->box_h || g->box_w == 0) {
        return 0;
    }
    else {
        int bi = (g->box_w * ey);

        uint32_t bits = (b[bi >> 2] << 24) | (b[(bi >> 2) + 1] << 16) | (b[(bi >> 2) + 2] << 8) | b[(bi >> 2) + 3];
        bits >>= 6 - ((bi & 3) << 1);
        bits &= 0x3ffffff & (0x3ffffff << ((13 - g->box_w) << 1));
        bits >>= g->ofs_x << 1;

        return bits >> 10;
    }
}

#if 0
const char* bit_to_char = " .-#";

int main(void) {
    const char* test_chars = "Hello! #$%&@ fgy|";
    for (int y = 0; y < 16; ++y) {
        const char* p = test_chars;
        while (*p) {
            int c = *p;
            uint32_t glyph = render_char_line(c, y);
            for (int b = 7; b >= 0; --b) {
                putc(bit_to_char[(glyph >> (b * 2)) & 3], stdout);
            }
            ++p;
        }
        putc('\n', stdout);
    }
    return 0;
}
#else
int main(void) {
    for (int c = 0x20; c < 0x7f; ++c) {
        for (int y = 0; y < 16; ++y) {
            uint32_t glyph = render_char_line(c, y);
            uint16_t glyph_swap = 
                ((glyph << 14) & 0xc000) |
                ((glyph << 10) & 0x3000) |
                ((glyph << 6) & 0x0c00) |
                ((glyph << 2) & 0x0300) |
                ((glyph >> 2) & 0x00c0) |
                ((glyph >> 6) & 0x0030) |
                ((glyph >> 10) & 0x000c) |
                ((glyph >> 14) & 0x0003);                
            printf("12'h%03x: line_data = 8'h%02x;\n", (c << 5) | (y << 1), glyph_swap & 0xff);
            printf("12'h%03x: line_data = 8'h%02x;\n", (c << 5) | (y << 1) | 1, (glyph_swap >> 8) & 0xff);
        }
    }
}
#endif
