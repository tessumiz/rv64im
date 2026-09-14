rtl/common/defs_pkg.sv
rtl/mem/mem_pkg.sv
rtl/peripherals/mmio_pkg.sv
rtl/ppu/ppu_pkg.sv
rtl/zicsr/zicsr_pkg.sv

rtl/common/wb_if.sv
rtl/mem/mem_if.sv
rtl/muldiv/muldiv_bus.sv
rtl/zicsr/csr_if.sv
rtl/peripherals/mmio_if.sv

rtl/soc.sv

+incdir+rtl
+incdir+rtl/common
+incdir+rtl/core
+incdir+rtl/mem
+incdir+rtl/muldiv
+incdir+rtl/peripherals
+incdir+rtl/ppu
+incdir+rtl/units
+incdir+rtl/zicsr

+libext+.sv
-y rtl/common
-y rtl/core
-y rtl/mem
-y rtl/muldiv
-y rtl/peripherals
-y rtl/ppu
-y rtl/units
-y rtl/zicsr
-y rtl