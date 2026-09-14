#include "Vsoc.h"
#include "Vsoc___024root.h"
#include "verilated.h"

#include "raylib.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

static constexpr uint64_t RAM_BASE = 0x80000000ULL;
static constexpr size_t RAM_SIZE = 1 * 1024 * 1024;
static constexpr size_t LINE_SIZE = 64;
static constexpr size_t WORDS_PER_LINE = LINE_SIZE / 4;

static void load_bin(Vsoc *top, const char *filename)
{
    std::ifstream f(filename, std::ios::binary);

    std::vector<uint8_t> data((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());

    auto &mem = top->rootp->soc__DOT__u_ram__DOT__mem;

    for (size_t off = 0; off < data.size(); off += LINE_SIZE) {
        const size_t line = off / LINE_SIZE;

        for (size_t w = 0; w < WORDS_PER_LINE; ++w) {
            uint32_t word = 0;

            for (size_t b = 0; b < 4; ++b) {
                const size_t i = off + w * 4 + b;

                if (i < data.size()) {
                    word |= static_cast<uint32_t>(data[i]) << (8 * b);
                }
            }

            mem[line][w] = word;
        }
    }

    std::printf("Load %zu B @ 0x%016llx\n", data.size(), static_cast<unsigned long long>(RAM_BASE));
}

static const char *ins_name(uint32_t ins)
{
    switch (ins & 0x7f) {
    case 0x03:
        return "LOAD";

    case 0x13:
        switch ((ins >> 12) & 0x7) {
        case 0x0: return "ADDI";
        case 0x4: return "XORI";
        case 0x6: return "ORI";
        case 0x7: return "ANDI";
        case 0x1: return "SLLI";
        case 0x5: return "SRLI/SRAI";
        default:  return "OP-IMM";
        }

    case 0x17:
        return "AUIPC";

    case 0x23:
        switch ((ins >> 12) & 0x7) {
        case 0x0: return "SB";
        case 0x1: return "SH";
        case 0x2: return "SW";
        case 0x3: return "SD";
        default:  return "STORE";
        }

    case 0x33:
        return "OP";

    case 0x37:
        return "LUI";

    case 0x63:
        switch ((ins >> 12) & 0x7) {
        case 0x0: return "BEQ";
        case 0x1: return "BNE";
        case 0x4: return "BLT";
        case 0x5: return "BGE";
        case 0x6: return "BLTU";
        case 0x7: return "BGEU";
        default:  return "BRANCH";
        }

    case 0x67:
        return "JALR";

    case 0x6f:
        return "JAL";

    case 0x73:
        return "SYSTEM";

    default:
        return "INVALID";
    }
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

    InitWindow(640, 480, " ");
    SetTargetFPS(60);

    while (!WindowShouldClose() && !Verilated::gotFinish()) {
        top->clk = 0;
        top->eval();

        top->clk = 1;
        top->eval();

        ++cycle;

        if (cycle == 5) {
            top->rst = 0;
        }

        auto *root = top->rootp;

        const uint64_t fetch_pc = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_pc;
        const uint32_t fetch_ins = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_ins;
        const uint64_t fetch_next_pc = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_nxt_pc;
        const uint8_t fetch_stall = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_stall;
        const uint8_t icache_stall = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_icache_stall;
        const uint8_t pc_en = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_pc_en;
        const uint8_t ic_req_en = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_ic_req_en;
        const uint8_t ic_rsp_ready = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_ic_rsp_ready;
        const uint8_t ic_rsp_busy = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_ic_rsp_busy;
        const uint8_t fill_req = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_fill_req;
        const uint8_t fill_en = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_fill_en;
        const uint8_t ram_r_en = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_ram_r_en;
        const uint8_t ram_ready = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_ram_ready;
        const uint64_t ram_addr = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_ram_addr;
        const uint8_t set_idx = root->soc__DOT__u_core__DOT__u_fetch__DOT__dbg_set_idx;

        const uint8_t take_br = root->soc__DOT__u_core__DOT__dbg_take_br;
        const uint64_t br_targ = root->soc__DOT__u_core__DOT__dbg_br_targ;
        const uint8_t id_ex_valid = root->soc__DOT__u_core__DOT__dbg_id_ex_valid;
        const uint8_t id_ex_jmp = root->soc__DOT__u_core__DOT__dbg_id_ex_jmp;
        const uint64_t id_ex_pc = root->soc__DOT__u_core__DOT__dbg_id_ex_pc;
        const uint64_t id_ex_imm = root->soc__DOT__u_core__DOT__dbg_id_ex_imm;

        const bool interesting = (cycle < 300) || (fetch_ins != 0) || take_br || id_ex_jmp;

        if (interesting) {
            std::printf("cycle=%4llu pc=%04llx %-10s br=%d ic=%d ready=%d busy=%d\n",
                static_cast<unsigned long long>(cycle),
                static_cast<unsigned long long>(fetch_pc - 0x80000000ULL),
                ins_name(fetch_ins),
                take_br,
                icache_stall,
                ic_rsp_ready,
                ic_rsp_busy
            );
        }

        BeginDrawing();
        ClearBackground(BLACK);
        EndDrawing();
    }

    top->final();

    delete top;

    CloseWindow();

    return 0;
}