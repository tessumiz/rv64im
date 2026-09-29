#include "../include/types.hpp"
#include <cstdlib>


struct miu_req_t {
    bool r_en = false;
    bool w_en = false;
    bool abort = false;
    u32  addr;
    u64  w_data;
};

struct miu_rsp_t {
    bool busy = false;
    bool ready = false;
    bool access_fault = false;
    bool burst_done = false;
    
    u8   burst_mask;
    u64  r_data;
};


class MIU {
    u64* ram;

    miu_req_t req_l = {};
    int  delay = -1;
    int  beat = 0;

    u64  w_buff[8];

    enum { Idle, RamAccess, Reading, Writing, Draining } fsm = Idle;


public:
    bool w_pending = false;

    MIU(u64* ram) : ram(ram) { }

    miu_rsp_t eval(miu_req_t req) {
        miu_rsp_t rsp = {};

        if (req.abort) {
            if (fsm == RamAccess)
                fsm = Idle;

            else if (fsm == Reading || fsm == Writing)
                fsm = Draining;
        }

        switch (fsm) {
            case Idle:
                if (!req.abort && (req.r_en || req.w_en)) {
                    req_l = req;
                    delay = (rand() % 10) + 1;
                    fsm = RamAccess;
                    rsp.busy = true;
                }
                break;

            case RamAccess:
                rsp.busy = true;

                if (--delay == 0) {
                    rsp.ready = true;
                    fsm = req_l.r_en ? Reading : Writing;
                    beat = 0;

                    rsp.burst_mask = 0;
                    u32 ram_addr = req_l.addr/8 + beat;
                    
                    if (fsm == Reading)
                        rsp.r_data = ram[ram_addr];
                    else {
                        ram[ram_addr] = req.w_data;

                        w_buff[0] = req.w_data;
                        w_pending = true;
                    }

                    beat++;
                }
                break;

            case Reading:
                rsp.busy = true;
                rsp.burst_mask = 1 << beat;
                rsp.r_data = ram[req_l.addr/8 + beat];
                
                if (++beat == 8) {
                    rsp.burst_done = true;
                    fsm = Idle;
                }
                break;

            case Writing:
                rsp.busy = true;
                rsp.burst_mask = 1 << beat;

                w_buff[beat] = req.w_data;
                
                if (++beat == 8) {
                    rsp.burst_done = true;
                    fsm = Idle;
                }
                break;

            case Draining:
                rsp.busy = true;
                rsp.burst_mask = 1 << beat;

                if (++beat == 8) {
                    rsp.burst_done = true;
                    fsm = Idle;
                }
                break;
        }

        return rsp;
    }

    u64* commit_write() {
        for (int i = 0; i < 8; i++)
            ram[req_l.addr/8 + i] = w_buff[i];

        w_pending = false;
        return w_buff;
    }
};