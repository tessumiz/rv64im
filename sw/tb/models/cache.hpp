// around 1/3rd the size of the rtl, at 1/10th of its complexity! I love C++


#include "../include/types.hpp"


#define SETS 64
#define WAYS 8
#define WAY_LOG 3


struct req_t {
    bool r_en;
    bool w_en;

    u64  tag;
    u8   set;
    u8   off;

    u64  w_data;
    u8   w_mask;
};

struct rsp_t {
    bool hit;
    u64  r_data;
    bool evict;
    u64  evict_tag;
};

struct Meta {
    bool v;
    bool d;
};

struct Line {
    u64 w[8];
};

class Cache {
    Meta meta[SETS][WAYS] = {};
    u64  tag[SETS][WAYS] = {};
    Line data[SETS][WAYS] = {};
    u8   plru[SETS] = {};

    // it's pointless to connect this with the miu after all...
    u64* ram;


    u8 get_victim(u8 set) {
        for (u8 i = 0; i < WAYS; i++)
            if (!meta[set][i].v) return i;

        u8 p = plru[set];
        u8 victim = 0;

        for (int i = 0; i < WAY_LOG; i++) {
            int w_idx = (WAY_LOG - 1) - i;
            int p_idx = (1 << i) - 1;
            int off = victim >> (w_idx + 1);

            u8 dir = (p >> (p_idx + off)) & 1;
            victim |= (dir << w_idx);
        }

        return victim;
    }

    void update_plru(u8 set, u8 acc) {
        u8 p = plru[set];

        for (int i = 0; i < WAY_LOG; i++) {
            int w_idx = (WAY_LOG - 1) - i;
            int p_idx = (1 << i) - 1;
            int off = acc >> (w_idx + 1);
            
            u8 acc_bit = (acc >> w_idx) & 1;
            u8 m = 1 << (p_idx + off);

            p = acc_bit ? (p & ~m) : (p | m);
        }

        plru[set] = p;
    }

    void apply_mask(u64& tgt, u64 val, u8 mask) {
        for (int i = 0; i < 8; i++) {
            if ((mask >> i) & 1) {
                u64 m = 0xFFULL << (i * 8);
                tgt = (tgt & ~m) | (val & m);
            }
        }
    }


public:
    Cache(u64* ram) : ram(ram) { }

    Line read_mem(u64 addr) {
        Line line;

        for (int i = 0; i < 8; i++)
            line.w[i] = ram[addr/8 + i];

        return line;
    }

    void write_mem(u64 addr, Line d) {
        for (int i = 0; i < 8; i++)
            ram[addr/8 + i] = d.w[i];
    }

    rsp_t eval(req_t req) {
        rsp_t rsp = {};
        int hit_w = -1;

        for (int w = 0; w < WAYS; w++) {
            if (meta[req.set][w].v && tag[req.set][w] == req.tag) {
                rsp.hit = true;
                hit_w = w;
                break;
            }
        }

        u8 tgt = rsp.hit ? hit_w : get_victim(req.set);

        if (!rsp.hit && (req.r_en || req.w_en)) {
            if (meta[req.set][tgt].v && meta[req.set][tgt].d) {
                rsp.evict = true;
                rsp.evict_tag = tag[req.set][tgt];
                u64 evict_addr = (rsp.evict_tag << 12) | (req.set << 6);

                write_mem(evict_addr, data[req.set][tgt]);
            }
            
            u64 fill_addr = (req.tag << 12) | (req.set << 6);
            data[req.set][tgt] = read_mem(fill_addr);
            
            tag[req.set][tgt] = req.tag;
            meta[req.set][tgt].v = true;
            meta[req.set][tgt].d = false;
        }

        if (req.r_en)
            rsp.r_data = data[req.set][tgt].w[req.off];

        else if (req.w_en)
            apply_mask(data[req.set][tgt].w[req.off], req.w_data, req.w_mask);
            meta[req.set][tgt].d = true;

        if (req.r_en || req.w_en)
            update_plru(req.set, tgt);

        return rsp;
    }

    void flush() {
        for (int s = 0; s < SETS; s++) {
            for (int w = 0; w < WAYS; w++) {
                if (meta[s][w].v && meta[s][w].d) {
                    u64 fill_addr = (tag[s][w] << 12) | (s << 6);
                    write_mem(fill_addr, data[s][w]);
                    meta[s][w].d = false;
                }
            }
        }
    }
};