#include <iostream>
#include <cstdlib>
#include <system_error>

#include "include/types.hpp"
#include "models/cache.hpp" 
#include "models/miu.hpp"

#include "Vtb_cache_top.h"
#include "verilated.h"


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtb_cache_top* top = new Vtb_cache_top;


    const int RAM_SIZE = 4 MB;  // same as what's in the .sv file
    u64* shared_ram = new u64[RAM_SIZE / 8];

    MIU miu(shared_ram);
    Cache cache_sim(shared_ram);

    srand(12345);

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

    const int LIMIT = 10 * 1000 * 1000;
    // allow any pending final txn to complete...
    for (int cycle = 0; (cycle < LIMIT || req_pending); cycle++) {
        if (!(req_pending || top->cpu_busy)) {
            req.r_en = rand() % 2;
            req.w_en = !req.r_en;

            // trigger cap/conflict misses more often (unsure if really needed for 10M cycles but yeah)
            req.set =  rand() % 8;
            req.tag =  tag_pool[rand() % 20];

            req.off =  rand() % 8;
            req.w_data = (((u64)rand() << 32) | rand());
            
            // B, HW, W, DW
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

        // trying to cover more possibilities here
        // seems unnecessary though since latching is for sure done well...
        else if (req_pending && top->cpu_busy && (rand() % 2 == 0)) {
            top->cpu_r_en = 0;
            top->cpu_w_en = 0;
        }


        top->clk = 1; top->eval();
        top->clk = 0; top->eval();

        // sv miu intf <=> miu sim connection
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


        if (req_pending && top->cpu_ready) {
            sim_rsp_t sim_rsp = cache_sim.eval(req);

            if (top->cpu_hit != sim_rsp.hit) {
                std::cerr << "hit, cycle: " << cycle << ", CPU: " << top->cpu_hit
                          << ", SIM: " << sim_rsp.hit << std::endl;
                return 1;
            }

            if (req.r_en && top->cpu_r_data != sim_rsp.r_data) {
                std::cerr << "r_data, cycle: " << cycle << ", CPU: " << top->cpu_r_data
                          << ", SIM: " << sim_rsp.r_data << std::endl;
                return 1;
            }

            else if (sim_rsp.evict != miu.w_pending)
                std::cerr << "w-pending mismatch, cycle: " << cycle << std::endl;

            else if (sim_rsp.evict) {
                u64* rtl_w_buff = miu.commit_write();
                u64* sim_w_buff = cache_sim.commit_write();

                for (int i = 0; i < 8; i++)
                    if (rtl_w_buff[i] != sim_w_buff[i])
                        std::cerr << "w_data, cycle: "<< cycle << std::endl;  // add diafnostics later
            }

            req_pending = false;
        }
    }

    std::cout << "PASSED!!" << std::endl;
    
    // no point in explicitly freeing resources right before this process ends...
    return 0;
}