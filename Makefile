.PHONY: cache ptw clean

cache:
	@echo "=> 1. Verilating Cache RTL"
	verilator -cc -sv --coverage \
		-f dv/tb/cache/cache_tb.f \
		--exe dv/tb/cache/cache_tb.cpp \
		--top-module tb_cache_top \
		--Wno-fatal \
		-LDFLAGS "-lfmt"

	@echo "=> 2. Compiling C++ Testbench"
	make -j -C obj_dir -f Vtb_cache_top.mk CXXFLAGS="-O3"

	@echo "=> 3. Running Simulation"
	./obj_dir/Vtb_cache_top

	@echo "=> 4. Processing Coverage"
	verilator_coverage --annotate logs/annotated logs/cache_coverage.dat

clean:
	@echo "=> Cleaning Build Artifacts"
	rm -rf obj_dir logs