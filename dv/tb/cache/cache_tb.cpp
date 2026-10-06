#include <cstdlib>
#include <fmt/core.h>
#include <fmt/color.h>

#include "../../include/types.hpp"
#include "../../models/cache.hpp"
#include "../../models/miu.hpp"

#include "Vtb_cache_top.h"
#include "verilated.h"
#include "verilated_cov.h"
#include "Vtb_cache_top___024root.h"
#include "Vtb_cache_top_tb_cache_top.h"
#include "Vtb_cache_top_set_cache__Bz2.h"


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
        fmt::print(stderr, "\n{:=^60}\n", " TRANSACTION HISTORY (LAST 64 CYCLES) ");

        int start = wrapped ? head : 0;
        int count = wrapped ? DEPTH : head;

        for (int i = 0; i < count; i++) {
            int idx = (start + i) % DEPTH;
            const auto& entry = history[idx];

            std::string op = entry.req.w_en ? "WRITE" : (entry.req.r_en ? "READ " : "IDLE ");
            
            fmt::print(stderr, 
                "[Cycle {:>4}] {} | Set: {:>2} | Tag: {:#013x} | Mask: {:#04x} | Hit: {}\n",
                entry.cycle, op, entry.req.set, entry.req.tag, entry.req.w_mask, entry.sim_rsp.hit
            );
        }
        fmt::print(stderr, "{:=^60}\n\n", "");
    }

    void throw_err(const char* name, int cycle, u64 rtl_val, u64 sim_val, int set, Vtb_cache_top* top, Cache& sim) {
        fmt::print(stderr, fg(fmt::color::red) | fmt::emphasis::bold, "\n[FATAL] {} Mismatch @ Cycle: {}\n", name, cycle);
        fmt::print(stderr, fg(fmt::color::yellow), "        RTL: {:#018x}\n", rtl_val);
        fmt::print(stderr, fg(fmt::color::green),  "        SIM: {:#018x}\n", sim_val);
        
        fmt::print(stderr, "\n{:-^60}\n", fmt::format(" SET {} META DUMP ", set));

        uint16_t set_meta = top->rootp->tb_cache_top->u_set_cache->meta[set]; 

        for (int w = 0; w < WAYS; w++) {
            bool rtl_d = (set_meta >> (w * 2)) & 1;
            bool rtl_v = (set_meta >> (w * 2 + 1)) & 1;

            bool sim_v = sim.meta[set][w].v;
            bool sim_d = sim.meta[set][w].d;
            
            fmt::print(stderr, "Way {}: RTL[V:{}, D:{}] | SIM[V:{}, D:{}]\n", w, rtl_v, rtl_d, sim_v, sim_d);
        }
        fmt::print(stderr, "{:-^60}\n", "");
        
        disp_logs();
        exit(EXIT_FAILURE);
    }


public:
    void check_and_log(int cycle, const sim_req_t& req, const sim_rsp_t& sim_rsp,
                       bool rtl_hit, u64 rtl_r_data, bool rtl_w_pending,
                       u64* rtl_w_buff, u64* sim_w_buff, Vtb_cache_top* top, Cache& sim) {

        history[head] = {cycle, req, sim_rsp, rtl_hit, rtl_r_data};
        head = (head + 1) % DEPTH;
        if (head == 0) wrapped = true;

        if (rtl_hit != sim_rsp.hit)
            throw_err("Cache Hit", cycle, rtl_hit, sim_rsp.hit, req.set, top, sim);

        if (req.r_en && rtl_r_data != sim_rsp.r_data)
            throw_err("Read Data Payload", cycle, rtl_r_data, sim_rsp.r_data, req.set, top, sim);

        if (rtl_w_pending != sim_rsp.evict)
            throw_err("MIU Write-Pending Flag", cycle, rtl_w_pending, sim_rsp.evict, req.set, top, sim);

        if (sim_rsp.evict) {
            for (int i = 0; i < 8; i++) {
                if (rtl_w_buff[i] != sim_w_buff[i]) {
                    std::string msg = fmt::format("Eviction Payload [Beat {}]", i);
                    throw_err(msg.c_str(), cycle, rtl_w_buff[i], sim_w_buff[i], req.set, top, sim);
                }
            }
        }
    }
};


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::mkdir("logs");
    Vtb_cache_top* top = new Vtb_cache_top;

    const int RAM_SIZE = 4 * 1024 * 1024;
    u64* ram = new u64[RAM_SIZE / 8]();

    MIU miu(ram);
    Cache cache_sim(ram);

    srand(100);
    auto prob = [](int perc) -> bool { return (rand() % 100) < perc; };

    u64 tag_pool[20];
    for (int i = 0; i < 20; i++)
        tag_pool[i] = (((u64)rand() << 32) | rand()) & 0xFFFFFFFFFFF;

    top->clk = 0; top->rst = 1; top->flush = 0; top->abort_sig = 0;

    for (int i = 0; i < 10; i++) {
        top->clk = !top->clk;
        top->eval();
    }
    top->rst = 0;

    bool req_pending = false;
    sim_req_t req = {};
    DiffChecker diff_chk;

    bool abort_sig = false;
    bool flush = false;
    bool abort_in_flight = false;
    bool evict_done = false;

    const int LIMIT = 10 * 1000 * 1000;

    for (int cycle = 0; (cycle < LIMIT || req_pending); cycle++) {
        
        if (!req_pending && !top->cpu_busy) {
            if (prob(1)) {
                flush = true;
                top->flush = true;
                cache_sim.flush();
            } else {
                req.r_en = rand() % 2;
                req.w_en = !req.r_en;
                req.set  = rand() % 8;
                req.tag  = tag_pool[rand() % 20];
                req.off  = rand() % 8;
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
        else if (req_pending && top->cpu_busy && !abort_in_flight && prob(2)) {
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

        // 1. Advance C++ MIU state
        miu_rsp_t m_rsp = miu.eval(m_req);

        if (top->miu_req_w_en && m_rsp.burst_done)
            evict_done = true;

        // 2. Drive new masks to RTL
        top->miu_rsp_busy         = m_rsp.busy;
        top->miu_rsp_ready        = m_rsp.ready;
        top->miu_rsp_access_fault = m_rsp.access_fault;
        top->miu_rsp_burst_mask   = m_rsp.burst_mask;
        top->miu_rsp_burst_done   = m_rsp.burst_done;
        top->miu_rsp_r_data       = m_rsp.r_data;

        // 3. Force combinatorial routing in RTL to generate the correct eviction data
        top->eval();

        // 4. THE MISSING LATCH PATCH: 
        // We MUST manually overwrite the C++ MIU's w_buff with the newly stabilized RTL data. 
        if (m_rsp.burst_mask != 0 && top->miu_req_w_en) {
            for (int i = 0; i < 8; i++) {
                if (m_rsp.burst_mask & (1 << i)) {
                    miu.w_buff[i] = top->miu_req_w_data; 
                }
            }
        }

        if (req_pending && top->cpu_ready) {
            sim_rsp_t sim_rsp = cache_sim.eval(req);
            u64* rtl_w_buff = sim_rsp.evict ? miu.w_buff : nullptr;
            u64* sim_w_buff = sim_rsp.evict ? cache_sim.w_buff : nullptr;

            diff_chk.check_and_log(
                cycle, req, sim_rsp,
                top->cpu_hit, top->cpu_r_data,
                miu.w_pending, rtl_w_buff, sim_w_buff, top,
                cache_sim
            );

            if (sim_rsp.evict) {
                u32 ram_base = ((sim_rsp.evict_tag << 12) | (req.set << 6)) & 0x3FFFFF;
                for (int i = 0; i < 8; i++)
                    ram[(ram_base / 8) + i] = sim_w_buff[i];
                miu.w_pending = false;
            }

            req_pending     = false;
            abort_in_flight = false;
            abort_sig       = false;
            evict_done      = false;

            top->abort_sig  = 0;
        }
        else if (abort_in_flight && !top->cpu_busy) {
            if (evict_done)
                cache_sim.force_evict(req);

            abort_sig       = false;
            abort_in_flight = false;
            req_pending     = false;
            evict_done      = false;

            top->abort_sig  = 0;
        }
        else if (flush && !top->cpu_busy) {
            flush          = false;
            miu.w_pending  = false;

            top->flush     = 0;
        }
    }


    top->final();
    VerilatedCov::write("logs/cache_coverage.dat");
    return 0;
}