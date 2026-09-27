#include "../include/types.hpp"
#include <cstdlib>


typedef struct {
    bool r_en = false;
    bool w_en = false;
    bool abort = false;
    u32  addr;
    u64  w_data;
} miu_req_t;

typedef struct {
    bool busy = false;
    bool ready = false;
    bool access_fault = false;
    bool burst_done = false;
    
    u8   burst_mask;
    u64  r_data;
} miu_rsp_t;


class MIU {
    static const int RAM_SIZE = 256 KB; 
    u64* ram;

    miu_req_t req_l = {};
    int  delay = -1;
    int  beat = 0;

    enum { Idle, RamAccess, Reading, Writing, Draining } fsm = Idle;

public:
    MIU()  { ram = new u64[RAM_SIZE / 8]; }
    ~MIU() { delete[] ram; }

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
                    else
                        ram[ram_addr] = req.w_data;

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
                ram[req_l.addr/8 + beat] = req.w_data;
                
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
};