#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <memory>
#include <vector>

#include "verilated.h"
#include "Vsoc.h"
#include "Vsoc___024root.h"
#include "raylib.h"

static constexpr uint64_t RAM_BASE = 0x80000000ULL;
static constexpr int W = 320;
static constexpr int H = 240;

static void load_bin(Vsoc *top, const char *path)
{
    std::ifstream f(path, std::ios::binary | std::ios::ate);

    if (!f) {
        std::perror(path);
        std::exit(1);
    }

    const size_t size = static_cast<size_t>(f.tellg());
    f.seekg(0);

    std::vector<uint8_t> data(size);

    if (!f.read(reinterpret_cast<char *>(data.data()), size)) {
        std::fprintf(stderr, "Failed to read %s\n", path);
        std::exit(1);
    }

    auto &mem = top->rootp->soc__DOT__u_ram__DOT__mem;

    for (size_t i = 0; i < data.size(); i += 8) {
        uint64_t word = 0;

        for (size_t b = 0; b < 8 && i + b < data.size(); b++)
            word |= static_cast<uint64_t>(data[i + b]) << (8 * b);

        const size_t word_addr = i >> 3;
        const size_t line = word_addr >> 3;
        const size_t slot = word_addr & 7;

        mem[line][slot] = word;
    }

    std::printf(
        "Loaded %zu bytes from %s at RAM base 0x%016llx\n",
        size,
        path,
        static_cast<unsigned long long>(RAM_BASE)
    );
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);

    auto top = std::make_unique<Vsoc>();

    load_bin(top.get(), "sw/main.bin");

    InitWindow(640, 480, "RV64 PPU");
    SetTargetFPS(60);

    Image image = GenImageColor(W, H, BLACK);
    Texture2D texture = LoadTextureFromImage(image);
    UnloadImage(image);

    uint64_t cycle = 0;

    while (!WindowShouldClose() && !Verilated::gotFinish()) {
        uint64_t keys = 0;

        if (IsKeyDown(KEY_LEFT))
            keys |= 1;
        if (IsKeyDown(KEY_RIGHT))
            keys |= 2;
        if (IsKeyDown(KEY_UP))
            keys |= 4;
        if (IsKeyDown(KEY_DOWN))
            keys |= 8;

        top->keyinp = keys;

        for (int i = 0; i < 5000; i++) {
            top->clk = 0;
            top->eval();

            top->clk = 1;
            top->eval();

            cycle++;
        }

        auto &fb = top->rootp->soc__DOT__u_ppu__DOT__frm_buff;

        Image frame = GenImageColor(W, H, BLACK);
        auto *pixels = static_cast<Color *>(frame.data);

        for (int y = 0; y < H; y++) {
            for (int x = 0; x < W; x++) {
                const uint16_t p = fb[y * W + x];

                pixels[y * W + x] = {
                    static_cast<unsigned char>(((p >> 10) & 0x1f) << 3),
                    static_cast<unsigned char>(((p >> 5) & 0x1f) << 3),
                    static_cast<unsigned char>((p & 0x1f) << 3),
                    255
                };
            }
        }

        UpdateTexture(texture, frame.data);
        UnloadImage(frame);

        BeginDrawing();
        ClearBackground(BLACK);
        DrawTextureEx(texture, {0, 0}, 0.0f, 2.0f, WHITE);
        EndDrawing();
    }

    UnloadTexture(texture);
    CloseWindow();

    top->final();
    return 0;
}