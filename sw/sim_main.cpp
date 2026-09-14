#include "Vsoc.h"
#include "Vsoc___024root.h"
#include "verilated.h"
#include "raylib.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <vector>

static constexpr uint64_t RAM_BASE = 0x80000000ULL;
static constexpr int W = 320;
static constexpr int H = 240;

static void load_bin(Vsoc *top, const char *name)
{
    std::ifstream f(name, std::ios::binary);
    if (!f) {
        std::perror(name);
        std::exit(1);
    }

    std::vector<uint8_t> data(
        (std::istreambuf_iterator<char>(f)),
        std::istreambuf_iterator<char>());

    auto &mem = top->rootp->soc__DOT__u_ram__DOT__mem;

    for (size_t i = 0; i < data.size(); i += 64) {
        size_t line = i / 64;

        for (size_t w = 0; w < 16; ++w) {
            uint32_t v = 0;

            for (size_t b = 0; b < 4; ++b) {
                size_t p = i + w * 4 + b;
                if (p < data.size())
                    v |= uint32_t(data[p]) << (b * 8);
            }

            mem[line][w] = v;
        }
    }
}

static void draw_fb(Vsoc *top, Texture2D tex, std::vector<Color> &px)
{
    auto *r = top->rootp;

    for (int i = 0; i < W * H; ++i) {
        uint16_t p = uint16_t(r->soc__DOT__u_ppu__DOT__frm_buff[i]);

        uint8_t r8 = uint8_t((((p >> 10) & 31) << 3) |
                              ((p >> 10) & 3));
        uint8_t g8 = uint8_t((((p >> 5) & 31) << 3) |
                              ((p >> 5) & 3));
        uint8_t b8 = uint8_t(((p & 31) << 3) | (p & 3));

        px[i] = {
            r8, g8, b8,
            uint8_t((p & 0x8000) ? 255 : 0)
        };
    }

    UpdateTexture(tex, px.data());

    BeginDrawing();
    ClearBackground(BLACK);

    DrawTexturePro(
        tex,
        {0, 0, float(W), float(H)},
        {0, 0, float(GetScreenWidth()), float(GetScreenHeight())},
        {0, 0},
        0,
        WHITE
    );

    EndDrawing();
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);

    auto *top = new Vsoc;
    load_bin(top, "sw/main.bin");

    top->clk = 0;
    top->rst = 1;
    top->keyinp = 0;
    top->eval();

    InitWindow(W, H, "RV64");

    std::vector<Color> pixels(W * H);

    Image image{
        pixels.data(),
        W, H, 1,
        PIXELFORMAT_UNCOMPRESSED_R8G8B8A8
    };

    Texture2D texture = LoadTextureFromImage(image);

    uint64_t cycle = 0;
    bool old_vblank = false;

    float red = 31;

    uint64_t sx = 0;
    uint64_t sy = 0;

    while (!WindowShouldClose() && !Verilated::gotFinish()) {

        /* Host input -> KEYINP */
        uint64_t keys = 0;

        if (IsKeyDown(KEY_UP) || IsKeyDown(KEY_W))
            keys |= 1ULL << 0;

        if (IsKeyDown(KEY_DOWN) || IsKeyDown(KEY_S))
            keys |= 1ULL << 1;

        if (IsKeyDown(KEY_LEFT) || IsKeyDown(KEY_A))
            keys |= 1ULL << 2;

        if (IsKeyDown(KEY_RIGHT) || IsKeyDown(KEY_D))
            keys |= 1ULL << 3;

        top->keyinp = keys;

        /* Clock */
        top->clk = 0;
        top->eval();

        top->clk = 1;
        top->eval();

        ++cycle;

        if (cycle == 5)
            top->rst = 0;

        auto *r = top->rootp;

        uint64_t ctrl =
            uint64_t(r->soc__DOT__u_ppu__DOT__ctrl);

        bool vblank = (ctrl >> 32) & 1;

        if (vblank && !old_vblank) {

            /*
             * KEYINP:
             * bit 0 = up
             * bit 1 = down
             * bit 2 = left
             * bit 3 = right
             *
             * 10 pixels per frame.
             */
            if (keys & (1ULL << 0))
                sy = (sy - 10) & 0x3ff;

            if (keys & (1ULL << 1))
                sy = (sy + 10) & 0x3ff;

            if (keys & (1ULL << 2))
                sx = (sx - 10) & 0x3ff;

            if (keys & (1ULL << 3))
                sx = (sx + 10) & 0x3ff;

            r->soc__DOT__u_ppu__DOT__ctrl =
                (1ULL << 32) | (sy << 16) | sx;

            /* Red dimming */
            if (red > 0)
                red -= 0.3f;

            uint16_t dim_red =
                uint16_t(int(red) << 10);

            r->soc__DOT__u_ppu__DOT__palette[1] = dim_red;

            draw_fb(top, texture, pixels);
        }

        old_vblank = vblank;
    }

    UnloadTexture(texture);

    top->final();
    delete top;

    CloseWindow();

    return 0;
}