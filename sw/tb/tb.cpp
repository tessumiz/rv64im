#include "Vtb_cache_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "include/types.hpp"
#include "models/miu.hpp"
#include "models/cache.hpp"

#include <iostream>


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Vtb_cache_top* top = new Vtb_cache_top;


    // either tfp, or my own trace logs, or smth less granular at the start...
}