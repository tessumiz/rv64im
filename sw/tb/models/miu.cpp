#include "../include/types.hpp"
#include <cstdlib>


typedef struct {
    bool r_en;
    bool w_en;
    bool abort;

    u32 addr;
    u64 w_data;
} miu_req_t;

typedef struct packed {
    bool busy;
    bool ready;
    bool access_fault;

    u8   burst_mask;
    bool burst_done;

    u64 r_data;
} miu_rsp_t;


// arbitration deferred for now
class MIU {
    const int RAM_SIZE   = 256 KB;
    u64* ram = new u64[RAM_SIZE / 8];

    miu_req_t req;  // latched

    int  ram_rsp_ticks = -1;  // arbitrary latency sim

    bool bursting;
    int  beat;
    bool abort_pending;


public:
    miu_rsp_t eval(miu_req_t request) {
        miu_rsp_t rsp;

        if (request.abort)
            abort_pending = true;

        if (!bursting && (req.r_en || req.w_en)) {
            req = request;
            rsp.busy = 1;

            if (ram_rsp_ticks == 0)
                ram_rsp_ticks = rand() % 10 + 1;
            
            else if (--ram_rsp_ticks == 0) {
                rsp.ready = true;

                if (!abort_pending)
                    bursting = true;
            }
        }
        else if (bursting) {
            rsp.ready = false;  // just a pulse

            int base = req.addr / 8;
            int ram_addr = base + beat;

            if (req.r_en) {
                rsp.r_data = ram[ram_addr];
                rsp.burst_mask = 1 << beat;
            } else
                ram[ram_addr] = request.w_data;  // latched w_data isn't what gets used here!
            
            if (++beat == 8) {
                rsp.burst_done = true;
                rsp.busy = false;
                beat = 0;
            }
        }

        return rsp;
    }
};