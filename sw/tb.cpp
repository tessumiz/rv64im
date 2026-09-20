#include "Vdefs_pkg.h"
#include "Vdefs_pkg___024root.h"
#include "verilated.h"
#include <iostream>
#include <fstream>
#include <vector>


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vdefs_pkg* top = new Vdefs_pkg;


    std::ifstream bin_file("sw/test.bin", std::ios::binary);
    if (!bin_file) {
        std::cout << "Failed to open sw/test.bin" << std::endl;
        delete top;
        return 1;
    }

    std::vector<uint8_t> buf((std::istreambuf_iterator<char>(bin_file)), {});

    for (size_t i = 0; i < buf.size(); i += 4) {
        if (i/4 < 16384) { 
            uint32_t word = 0;

            if (i+0 < buf.size()) word |=  buf[i+0];
            if (i+1 < buf.size()) word |= (buf[i+1] << 8);
            if (i+2 < buf.size()) word |= (buf[i+2] << 16);
            if (i+3 < buf.size()) word |= (buf[i+3] << 24);

            top->rootp->soc__DOT__u_core__DOT__u_fetch__DOT__imem[i/4] = word;
        }
    }

    for (size_t i = 0; i < buf.size(); i += 8) {
        if (i/8 < 16384) { 
            uint64_t dword = 0;

            for (int j = 0; j < 8; j++) {
                if (i+j < buf.size()) dword |= ((uint64_t)buf[i+j] << (j*8));
            }

            top->rootp->soc__DOT__u_core__DOT__u_mem_stage__DOT__dmem[i / 8] = dword;
        }
    }

    top->clk = 0;
    top->rst = 1;

    for (int i = 0; i < 4; i++) {
        top->clk = !top->clk;
        top->eval();
    }

    top->rst = 0;
    top->rootp->soc__DOT__u_core__DOT__u_mem_stage__DOT__dmem[16383] = 0;

    for (int cycle = 0; cycle < 10000; cycle++) {
        top->clk = 1; top->eval();
        top->clk = 0; top->eval();

        if (top->rootp->soc__DOT__u_core__DOT__u_mem_stage__DOT__dmem[16383])
            break;
    }

    uint64_t status = top->rootp->soc__DOT__u_core__DOT__u_mem_stage__DOT__dmem[16383];

    if (status == 1) std::cout << "PASS" << std::endl;
    else std::cout << "FAIL at test #" << status << std::endl;

    delete top;
    return 0;
}