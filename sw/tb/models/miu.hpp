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

    enum { Idle, RamAccess, Reading, Writing } fsm = Idle;

    bool aborted = false;

    miu_rsp_t rsp = {};


public:
    bool w_pending = false;
    u64  w_buff[8];

    MIU(u64* ram) : ram(ram) { }

    miu_rsp_t& eval(miu_req_t req) {
        if (req.abort) {
            aborted = true;
            w_pending = false;
        }


        switch (fsm) {
            case Idle:
                aborted = false;
                rsp = {};

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

                    if (aborted) {
                        rsp.busy = false;

                        fsm = Idle;
                        break;
                    }

                    fsm = req_l.r_en ? Reading : Writing;
                    beat = 0;

                    rsp.burst_mask = 1;
                    u32 ram_addr = ((req_l.addr & 0x3FFFFF) / 8) + beat;

                    if (fsm == Reading)
                        rsp.r_data = ram[ram_addr];
                    else {
                        w_buff[0] = req.w_data;
                        w_pending = true;
                    }

                    beat++;
                }
                break;

            case Reading:                
                if (!aborted) {
                    rsp.burst_mask = 1 << beat;
                    rsp.r_data = ram[((req_l.addr & 0x3FFFFF) / 8) + beat];
                }

                if (++beat == 8) {
                    rsp.burst_done = true;

                    rsp.busy  = false;
                    rsp.ready = false;

                    fsm = Idle;
                    break;
                }
                break;

            case Writing:
                if (!aborted) {
                    rsp.burst_mask = 1 << beat;
                    w_buff[beat] = req.w_data;
                }

                if (++beat == 8) {
                    if (aborted) w_pending = false;

                    rsp.burst_done = true;

                    rsp.busy  = false;
                    rsp.ready = false;

                    fsm = Idle;
                    break;
                }
                break;
        }

        return rsp;
    }
};


/*
| RamAccess | RW | Idle |

*----busy---------------*
            *---ready---*
                 * burst_done (beat 8)
*/