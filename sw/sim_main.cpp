#include "Vsoc.h"
#include "Vsoc___024root.h"
#include "verilated.h"

#include "raylib.h"

#include <cstdint>
#include <chrono>
#include <vector>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <vector>

static constexpr uint64_t RAM_BASE = 0x80000000ULL;
static constexpr size_t LINE_SIZE = 64;
static constexpr size_t WORDS_PER_LINE = LINE_SIZE / 4;

static void load_bin(Vsoc *top, const char *filename)
{
    std::ifstream f(filename, std::ios::binary);
    if (!f) {
        std::perror(filename);
        std::exit(EXIT_FAILURE);
    }

    std::vector<uint8_t> data(
        (std::istreambuf_iterator<char>(f)),
        std::istreambuf_iterator<char>());

    auto &mem = top->rootp->soc__DOT__u_ram__DOT__mem;

    for (size_t off = 0; off < data.size(); off += LINE_SIZE) {
        const size_t line = off / LINE_SIZE;

        for (size_t w = 0; w < WORDS_PER_LINE; ++w) {
            uint32_t word = 0;

            for (size_t b = 0; b < 4; ++b) {
                const size_t i = off + w * 4 + b;
                if (i < data.size())
                    word |= static_cast<uint32_t>(data[i]) << (8 * b);
            }

            mem[line][w] = word;
        }
    }

    std::printf("load %zuB @ %08llx\n",
        data.size(),
        static_cast<unsigned long long>(RAM_BASE));
}

static unsigned pc_off(uint64_t pc)
{
    return static_cast<unsigned>(
        (pc >= RAM_BASE) ? (pc - RAM_BASE) : pc);
}

static const char *xname(unsigned r)
{
    static const char *n[32] = {
        "zero","ra","sp","gp","tp","t0","t1","t2",
        "s0","s1","a0","a1","a2","a3","a4","a5",
        "a6","a7","s2","s3","s4","s5","s6","s7",
        "s8","s9","s10","s11","t3","t4","t5","t6"
    };
    return n[r & 31];
}

static const char *ins_name(uint32_t ins)
{
    switch (ins & 0x7f) {
    case 0x03:
        switch ((ins >> 12) & 7) {
        case 0: return "LB";
        case 1: return "LH";
        case 2: return "LW";
        case 3: return "LD";
        case 4: return "LBU";
        case 5: return "LHU";
        case 6: return "LWU";
        default: return "LOAD";
        }
    case 0x13:
        switch ((ins >> 12) & 7) {
        case 0: return "ADDI";
        case 1: return "SLLI";
        case 4: return "XORI";
        case 5: return ((ins >> 30) & 1) ? "SRAI" : "SRLI";
        case 6: return "ORI";
        case 7: return "ANDI";
        default: return "OP-IMM";
        }
    case 0x17: return "AUIPC";
    case 0x23:
        switch ((ins >> 12) & 7) {
        case 0: return "SB";
        case 1: return "SH";
        case 2: return "SW";
        case 3: return "SD";
        default: return "STORE";
        }
    case 0x33:
        switch ((ins >> 12) & 7) {
        case 0: return ((ins >> 30) & 1) ? "SUB" : "ADD";
        case 1: return "SLL";
        case 4: return "XOR";
        case 5: return ((ins >> 30) & 1) ? "SRA" : "SRL";
        case 6: return "OR";
        case 7: return "AND";
        default: return "OP";
        }
    case 0x37: return "LUI";
    case 0x63:
        switch ((ins >> 12) & 7) {
        case 0: return "BEQ";
        case 1: return "BNE";
        case 4: return "BLT";
        case 5: return "BGE";
        case 6: return "BLTU";
        case 7: return "BGEU";
        default: return "BR";
        }
    case 0x67: return "JALR";
    case 0x6f: return "JAL";
    case 0x73: return "SYSTEM";
    default: return "----";
    }
}

static const char *ex_name(
    uint8_t f3, uint8_t f7,
    uint8_t br, uint8_t jmp, uint8_t lui,
    uint8_t pc1, uint8_t imm2)
{
    if (br) {
        switch (f3 & 7) {
        case 0: return "BEQ";
        case 1: return "BNE";
        case 4: return "BLT";
        case 5: return "BGE";
        case 6: return "BLTU";
        case 7: return "BGEU";
        default: return "BR";
        }
    }

    if (jmp) return "JMP";
    if (lui) return "LUI";
    if (pc1) return "AUIPC";

    if (imm2) {
        switch (f3 & 7) {
        case 0: return "ADDI";
        case 1: return "SLLI";
        case 4: return "XORI";
        case 5: return (f7 & 0x20) ? "SRAI" : "SRLI";
        case 6: return "ORI";
        case 7: return "ANDI";
        default: return "OP-IMM";
        }
    }

    switch (f3 & 7) {
    case 0: return (f7 & 0x20) ? "SUB" : "ADD";
    case 1: return "SLL";
    case 4: return "XOR";
    case 5: return (f7 & 0x20) ? "SRA" : "SRL";
    case 6: return "OR";
    case 7: return "AND";
    default: return "OP";
    }
}

static const char *mem_name(uint8_t f3, uint8_t r, uint8_t w)
{
    if (r) {
        switch (f3 & 7) {
        case 0: return "LB";
        case 1: return "LH";
        case 2: return "LW";
        case 3: return "LD";
        case 4: return "LBU";
        case 5: return "LHU";
        case 6: return "LWU";
        default: return "LOAD";
        }
    }

    if (w) {
        switch (f3 & 7) {
        case 0: return "SB";
        case 1: return "SH";
        case 2: return "SW";
        case 3: return "SD";
        default: return "STORE";
        }
    }

    return "MEM";
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);

    Vsoc *top = new Vsoc;
    load_bin(top, "sw/main.bin");

    top->clk = 0;
    top->rst = 1;
    top->eval();

    uint64_t cycle = 0;
    bool prev_vblank = false;

    uint64_t keyinp = 0;
    uint64_t prev_keyinp = ~0ULL;
    uint16_t prev_scroll_x = 0;
    uint16_t prev_scroll_y = 0;
    using clock = std::chrono::steady_clock;
    auto next_input_poll = clock::now();

    constexpr int FB_WIDTH = 320;
    constexpr int FB_HEIGHT = 240;
    constexpr size_t FB_PIXELS =
        static_cast<size_t>(FB_WIDTH) * FB_HEIGHT;

    InitWindow(FB_WIDTH, FB_HEIGHT, "RV64");
    SetTargetFPS(0);

    PollInputEvents();

    std::vector<Color> pixels(FB_PIXELS);

    Image image{
        pixels.data(),
        FB_WIDTH,
        FB_HEIGHT,
        1,
        PIXELFORMAT_UNCOMPRESSED_R8G8B8A8
    };

    Texture2D texture = LoadTextureFromImage(image);

    while (!WindowShouldClose() && !Verilated::gotFinish()) {
        /*
         * Raylib input is host-side state, while keyinp is a SoC input.
         * Poll it independently of VBlank so a key press/release cannot
         * be missed just because the simulator is between frames.
         */
        const auto host_now = clock::now();
        if (host_now >= next_input_poll) {
            PollInputEvents();

            keyinp = 0;

            if (IsKeyDown(KEY_UP) || IsKeyDown(KEY_W))
                keyinp |= 1ULL << 0;

            if (IsKeyDown(KEY_DOWN) || IsKeyDown(KEY_S))
                keyinp |= 1ULL << 1;

            if (IsKeyDown(KEY_LEFT) || IsKeyDown(KEY_A))
                keyinp |= 1ULL << 2;

            if (IsKeyDown(KEY_RIGHT) || IsKeyDown(KEY_D))
                keyinp |= 1ULL << 3;

            /*
             * Poll frequently enough for human input without calling
             * Raylib's event pump on every simulated clock.
             */
            next_input_poll =
                host_now + std::chrono::milliseconds(2);

            top->keyinp = keyinp;

            if (keyinp != prev_keyinp) {
                std::printf(
                    "HOST KEYS: raw=%016llx "
                    "U=%d D=%d L=%d R=%d -> keyinp=%016llx\n",
                    static_cast<unsigned long long>(keyinp),
                    IsKeyDown(KEY_UP) || IsKeyDown(KEY_W),
                    IsKeyDown(KEY_DOWN) || IsKeyDown(KEY_S),
                    IsKeyDown(KEY_LEFT) || IsKeyDown(KEY_A),
                    IsKeyDown(KEY_RIGHT) || IsKeyDown(KEY_D),
                    static_cast<unsigned long long>(keyinp));

                prev_keyinp = keyinp;
            }
        }

        top->clk = 0;
        top->eval();

        top->clk = 1;
        top->eval();

        ++cycle;

        if (cycle == 5)
            top->rst = 0;

        auto *r = top->rootp;

        /*
         * From ppu_pkg.sv:
         *
         *   ppu_ctrl_t {
         *       vblank   : bit 32
         *       scroll_y : bits 31:16
         *       scroll_x : bits 15:0
         *   }
         */
        const uint64_t ctrl =
            static_cast<uint64_t>(r->soc__DOT__u_ppu__DOT__ctrl);

        const bool vblank = ((ctrl >> 32) & 1ULL) != 0;
        const uint16_t scroll_x =
            static_cast<uint16_t>(ctrl & 0xffff);
        const uint16_t scroll_y =
            static_cast<uint16_t>((ctrl >> 16) & 0xffff);

        if (scroll_x != prev_scroll_x || scroll_y != prev_scroll_y) {
            std::printf(
                "PPU CTRL: cycle=%llu vblank=%d "
                "scroll_x=%u scroll_y=%u ctrl=%016llx\n",
                static_cast<unsigned long long>(cycle),
                vblank,
                static_cast<unsigned>(scroll_x),
                static_cast<unsigned>(scroll_y),
                static_cast<unsigned long long>(ctrl));

            prev_scroll_x = scroll_x;
            prev_scroll_y = scroll_y;
        }

        /*
         * The PPU produces a 320x240 framebuffer of 16-bit pixels.
         * ppu.sv writes:
         *
         *   {1'b1, palette[color_idx][14:0]}
         *
         * so bit 15 is treated as alpha and bits 14:10 / 9:5 / 4:0
         * are RGB555.
         */
        if (vblank && !prev_vblank) {
            std::printf(
                "VBLANK: cycle=%llu keyinp=%016llx "
                "scroll_x=%u scroll_y=%u\n",
                static_cast<unsigned long long>(cycle),
                static_cast<unsigned long long>(keyinp),
                static_cast<unsigned>(scroll_x),
                static_cast<unsigned>(scroll_y));

            for (size_t i = 0; i < FB_PIXELS; ++i) {
                const uint16_t p =
                    static_cast<uint16_t>(
                        r->soc__DOT__u_ppu__DOT__frm_buff[i]);

                const bool alpha = (p & 0x8000) != 0;
                const unsigned red5   = (p >> 10) & 0x1f;
                const unsigned green5 = (p >> 5)  & 0x1f;
                const unsigned blue5  = p & 0x1f;

                pixels[i] = Color{
                    static_cast<unsigned char>((red5   << 3) | (red5   >> 2)),
                    static_cast<unsigned char>((green5 << 3) | (green5 >> 2)),
                    static_cast<unsigned char>((blue5  << 3) | (blue5  >> 2)),
                    static_cast<unsigned char>(alpha ? 255 : 0)
                };
            }

            UpdateTexture(texture, pixels.data());

            BeginDrawing();
            ClearBackground(BLACK);

            DrawTexturePro(
                texture,
                Rectangle{
                    0.0f,
                    0.0f,
                    static_cast<float>(FB_WIDTH),
                    static_cast<float>(FB_HEIGHT)
                },
                Rectangle{
                    0.0f,
                    0.0f,
                    static_cast<float>(GetScreenWidth()),
                    static_cast<float>(GetScreenHeight())
                },
                Vector2{0.0f, 0.0f},
                0.0f,
                WHITE
            );

            EndDrawing();
        }

        prev_vblank = vblank;
    }

    UnloadTexture(texture);
    top->final();
    delete top;
    CloseWindow();

    return 0;
}
