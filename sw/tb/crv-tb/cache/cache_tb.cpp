#include <iostream>
#include <cstdlib>
#include <iomanip>

#include "../../include/types.hpp"
#include "../../models/cache.hpp"
#include "../../models/miu.hpp"

#include "../../Vtb_cache_top.h"
#include "../../verilated.h"


class CacheFnCov {
    enum cov_op_t   { R, W_FULL, W_SUB, _OP_COUNT };
    enum cov_cmp_t  { HIT, MISS_CLEAN, MISS_DIRTY, _CMP_COUNT };
    enum cov_misc_t { NORM, ABORT, _MISC_COUNT };

    /*
    I don't think such a 3D array is too sparse to be used here...
    we'll see when more sparse cases arise, what exactly to do;
    maybe split the arr into different segs mimicing composition...
    Sort of like archetypal ecs
    */

    u8 fn_cov[_OP_COUNT][_CMP_COUNT][_MISC_COUNT];
    u8 flushes;

    // for now, let's say this is the same for all; specialize later
    static constexpr int TARGET = 20;


public:
    CacheFnCov() {
        for (int i = 0; i < sizeof(fn_cov) / 1; i++)
            *((u8*)fn_cov + i) = 0;
    }


    void update_coverage(sim_req_t& req, sim_rsp_t& rsp, bool abort_sig, bool flush) {
        cov_op_t op = req.r_en ? R : (req.w_mask == 0xFF ? W_FULL : W_SUB);

        cov_cmp_t cmp;

        if (rsp.hit) cmp = HIT;
        else cmp = rsp.evict ? MISS_DIRTY : MISS_CLEAN;

        cov_misc_t misc = abort_sig ? ABORT : NORM;

        if (fn_cov[op][cmp][misc] < TARGET)
            fn_cov[op][cmp][misc]++;

        if (flushes < 255) flushes++;
    }

    void print_coverage(int cycle) {
        // std::cout << "\033[2J\033[3J\033[H" << std::flush;

        std::cout << "=== FUNCTIONAL COVERAGE (Cycle "
                << cycle << ") ===\n\n";

        const char* op_names[]  = {"READ    ", "FULL_WR ", "SUB_WR  "};
        const char* cmp_names[] = {"HIT", "MISS_CLN", "MISS_DRTY"};

        for (int m = 0; m < _MISC_COUNT; m++) {
            std::cout << "-- [ "
                    << (m == NORM ? "NORMAL EXECUTION" : "ABORTED EXECUTION")
                    << " ] --\n";

            std::cout << "         | HIT      | MISS_CLN | MISS_DRTY\n";
            std::cout << "------------------------------------------\n";

            for (int op = 0; op < _OP_COUNT; op++) {
                std::cout << op_names[op] << " | ";

                for (int cmp = 0; cmp < _CMP_COUNT; cmp++) {
                    u8 val = fn_cov[op][cmp][m];

                    if (val >= TARGET)
                        std::cout << "\033[32m";
                    else if (val > 0)
                        std::cout << "\033[33m";
                    else
                        std::cout << "\033[31m";

                    std::cout << std::setw(3) << (int)val
                            << "/" << std::setw(3) << TARGET
                            << "   ";

                    std::cout << "\033[0m";
                }

                std::cout << '\n';
            }

            std::cout << '\n';
        }

        std::cout << std::flush;
    }
};


class DiffChecker {
    struct log_entry_t {
        int cycle;
        sim_req_t req;
        sim_rsp_t sim_rsp;
        bool rtl_hit;
        u64 rtl_r_data;
    };

    static constexpr int DEPTH = 64;
    log_entry_t history[DEPTH];

    int head = 0;
    bool wrapped = false;

    void disp_logs() {
        std::cerr << "\n=== TRANSACTION HISTORY (LAST " << DEPTH << " CYCLES) ===\n";

        // more performant than module, albeit doesn't matter anyways here...
        int start = wrapped ? head : 0;
        int count = wrapped ? DEPTH : head;

        for (int i = 0; i < count; i++) {
            int idx = (start + i) % DEPTH;
            const auto& entry = history[idx];

            std::cerr << "[Cycle " << std::dec << entry.cycle << "] "
                      << (entry.req.w_en ? "WRITE " : (entry.req.r_en ? "READ  " : "IDLE  "))
                      << "| Set: " << (int)entry.req.set
                      << " | Tag: 0x" << std::hex << entry.req.tag
                      << " | Mask: 0x" << (int)entry.req.w_mask
                      << " || SIM Hit: " << entry.sim_rsp.hit
                      << " | RTL Hit: " << entry.rtl_hit << "\n";
        }
        std::cerr << "=================================================\n\n";
    }

    void throw_err(const char* name, int cycle, u64 rtl_val, u64 sim_val) {
        std::cerr << "\n[FATAL] " << name << " Mismatch @ Cycle: " << std::dec << cycle << "\n"
                  << "        RTL: 0x" << std::hex << rtl_val << "\n"
                  << "        SIM: 0x" << sim_val << std::dec << "\n";

        disp_logs();
        exit(EXIT_FAILURE);
    }


public:
    void check_and_log(int cycle, const sim_req_t& req, const sim_rsp_t& sim_rsp,
                       bool rtl_hit, u64 rtl_r_data, bool rtl_w_pending,
                       u64* rtl_w_buff, u64* sim_w_buff, Vtb_cache_top* top) {

        history[head] = {cycle, req, sim_rsp, rtl_hit, rtl_r_data};
        head = (head + 1) % DEPTH;
        if (head == 0) wrapped = true;

        if (rtl_hit != sim_rsp.hit)
            throw_err("Cache Hit", cycle, rtl_hit, sim_rsp.hit);

        if (req.r_en && rtl_r_data != sim_rsp.r_data)
            throw_err("Read Data Payload", cycle, rtl_r_data, sim_rsp.r_data);

        if (rtl_w_pending != sim_rsp.evict)
            throw_err("MIU Write-Pending Flag", cycle, rtl_w_pending, sim_rsp.evict);


        if (sim_rsp.evict) {
            for (int i = 0; i < 8; i++) {
                if (rtl_w_buff[i] != sim_w_buff[i]) {
                    char msg[64];

                    snprintf(msg, sizeof(msg), "Eviction Payload [Beat %d]", i);
                    throw_err(msg, cycle, rtl_w_buff[i], sim_w_buff[i]);
                }
            }
        }
    }
};


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtb_cache_top* top = new Vtb_cache_top;


    const int RAM_SIZE = 4 MB;  // same as what's in the .sv file
    u64* ram = new u64[RAM_SIZE / 8]();

    MIU miu(ram);
    Cache cache_sim(ram);

    srand(100);
    auto prob = [](int perc) -> bool { return (rand() % 100) < perc; };

    u64 tag_pool[20];
    for (int i = 0; i < 20; i++)
        tag_pool[i] = (((u64)rand() << 32) | rand()) & 0xFFFFFFFFFFF;


    top->clk = 0;
    top->rst = 1;
    top->flush = 0;
    top->abort_sig = 0;

    for (int i = 0; i < 10; i++) {
        top->clk = !top->clk;
        top->eval();
    }

    top->rst = 0;

    bool  req_pending = false;
    sim_req_t req = {};

    CacheFnCov  fn_cov;
    DiffChecker diff_chk;

    bool abort_sig = false;
    bool flush = false;

    bool abort_in_flight = false;

    const int LIMIT = 100 MB;

    for (int cycle = 0; (cycle < LIMIT || req_pending); cycle++) {
        if (!req_pending && !top->cpu_busy) {
            if (prob(0)) {
                flush = true;
                top->flush = true;
                cache_sim.flush();
            }
            else {
                req.r_en = rand() % 2;
                req.w_en = !req.r_en;

                req.set =  rand() % 8;
                req.tag =  tag_pool[rand() % 20];
                req.off =  rand() % 8;

                req.w_data = (((u64)rand() << 32) | rand());

                int mask_type = rand() % 4;
                req.w_mask =
                    (mask_type == 0) ? (0x01 << (rand() % 8)) :
                    (mask_type == 1) ? (0x03 << ((rand() % 4) * 2)) :
                    (mask_type == 2) ? (0x0F << ((rand() % 2) * 4)) :
                                        0xFF;

                top->cpu_set_idx    = req.set;
                top->cpu_blk_offset = req.off;
                top->cpu_tag_ppn    = req.tag;
                top->cpu_r_en       = req.r_en;
                top->cpu_w_en       = req.w_en;
                top->cpu_w_data     = req.w_data;
                top->cpu_w_mask     = req.w_mask;
                
                req_pending = true;
            }
        }
        else if (req_pending && top->cpu_busy && !abort_in_flight && prob(0)) {
            abort_sig = true;
            top->abort_sig = true;
            abort_in_flight = true; 
        }

        top->clk = 1; top->eval();
        top->clk = 0; top->eval();

        miu_req_t m_req;
        m_req.r_en   = top->miu_req_r_en;
        m_req.w_en   = top->miu_req_w_en;
        m_req.abort  = top->miu_req_abort;
        m_req.addr   = top->miu_req_addr;
        m_req.w_data = top->miu_req_w_data;

        miu_rsp_t m_rsp = miu.eval(m_req);

        top->miu_rsp_busy         = m_rsp.busy;
        top->miu_rsp_ready        = m_rsp.ready;
        top->miu_rsp_access_fault = m_rsp.access_fault;
        top->miu_rsp_burst_mask   = m_rsp.burst_mask;
        top->miu_rsp_burst_done   = m_rsp.burst_done;
        top->miu_rsp_r_data       = m_rsp.r_data;


        if (abort_in_flight && !top->cpu_busy) {
            sim_rsp_t dummy_rsp = {};
            fn_cov.update_coverage(req, dummy_rsp, true, false);

            abort_sig = false;
            abort_in_flight = false;
            req_pending = false;
            top->abort_sig = 0;
        }
        else if (flush && !top->cpu_busy) {
            sim_rsp_t dummy_rsp = {};
            fn_cov.update_coverage(req, dummy_rsp, false, true);

            flush = false;
            top->flush = 0;
            miu.w_pending = false;
        }
        else if (req_pending && top->cpu_ready) {
            sim_rsp_t sim_rsp = cache_sim.eval(req);

            u64* rtl_w_buff = nullptr;
            u64* sim_w_buff = nullptr;

            if (sim_rsp.evict) {
                rtl_w_buff = miu.w_buff;
                sim_w_buff = cache_sim.w_buff;
            }

            diff_chk.check_and_log(
                cycle, req, sim_rsp,
                top->cpu_hit, top->cpu_r_data,
                miu.w_pending, rtl_w_buff, sim_w_buff, top
            );

            if (sim_rsp.evict) {
                u32 ram_base = ((sim_rsp.evict_tag << 12) | (req.set << 6)) & 0x3FFFFF;
                for (int i = 0; i < 8; i++)
                    ram[(ram_base / 8) + i] = sim_w_buff[i];

                miu.w_pending = false;
            }

            fn_cov.update_coverage(req, sim_rsp, false, false);
            req_pending = false;
        }

        if ((cycle & (1 MB - 1)) == 0)
            fn_cov.print_coverage(cycle);
    }


    std::cout << "PASSED!!" << std::endl;
    top->final();
    return 0;
}