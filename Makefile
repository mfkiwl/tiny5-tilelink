VERILATOR ?= verilator

TOP_MODULE = top
TRACE_FILE = trace.fst

VERILOG_SOURCES = cache_interface_types.sv definitions.sv alu.sv muldiv.sv compare_unit.sv \
	control.sv datapath.sv decode.sv forwarding.sv regfile.sv csr.sv immediate.sv \
	cache_interface.sv memory_interface.sv memory_arbiter.sv cache.sv memory.sv \
	cache_sign_extend.sv store_buffer.sv top.sv utils.svh

VERILATOR_TB_SOURCES = tb/main.cpp tb/Tiny5Tb.cpp
TEST_SOURCES = test/test.s

VERILATOR_VTOP = V$(TOP_MODULE)
CFLAGS = -std=c++11 -DVTOP_MODULE=$(VERILATOR_VTOP) -DTRACE_FILE="\\\"$(TRACE_FILE)\\\""
VERILATOR_FLAGS = -Wall -Wno-fatal --unroll-count 2048 --x-initial-edge --top-module $(TOP_MODULE)
TEST_CFLAGS = -march=rv32im -mabi=ilp32 -nostartfiles -nostdlib
HEXDUMP_FLAGS = -ve '1/1 "%02X "'

all: lint

#### Verilator ####
obj_dir/$(VERILATOR_VTOP): $(VERILOG_SOURCES) $(VERILATOR_TB_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) -CFLAGS "$(CFLAGS)" --trace-fst --cc --exe $^
	make -j4 -k -C obj_dir -f $(VERILATOR_VTOP).mk $(VERILATOR_VTOP)

verilate: obj_dir/$(VERILATOR_VTOP)

lint:
	@$(VERILATOR) $(VERILATOR_FLAGS) --lint-only $(VERILOG_SOURCES)

run: test.bin obj_dir/$(VERILATOR_VTOP)
	@hexdump $(HEXDUMP_FLAGS) $< > memory.hex.txt
	@obj_dir/$(VERILATOR_VTOP) $(ARGS)

$(TRACE_FILE): run

gtkwave: $(TRACE_FILE)
	@gtkwave $(TRACE_FILE) trace.sav

#### Modelsim ####
modelsim: test.bin $(VERILOG_SOURCES)
	@hexdump $(HEXDUMP_FLAGS) $< > memory.hex.txt
	vlib work
	vlog -ccflags "-std=c++11" $(VERILOG_SOURCES)
	vsim -do tb/modelsim.do $(TOP_MODULE)

#### Official RISC-V tests ####
RISCV_TESTS_DIR = ../riscv-tests
RISCV_TESTS_INC = -I$(RISCV_TESTS_DIR)/isa/macros/scalar -I$(RISCV_TESTS_DIR)/env/p
include $(RISCV_TESTS_DIR)/isa/rv32ui/Makefrag
include $(RISCV_TESTS_DIR)/isa/rv32um/Makefrag
RISCV_TESTS_LST = $(rv32ui_sc_tests) $(rv32um_sc_tests)

riscv-tests: $(addsuffix .test.out, $(RISCV_TESTS_LST))

riscv-tests-clean:
	@rm -rf $(addsuffix .elf, $(RISCV_TESTS_LST)) \
		$(addsuffix .bin, $(RISCV_TESTS_LST)) \
		$(addsuffix .test.out, $(RISCV_TESTS_LST)) \

%.test.out: %.bin obj_dir/$(VERILATOR_VTOP)
	@hexdump $(HEXDUMP_FLAGS) $< > memory.hex.txt
	obj_dir/$(VERILATOR_VTOP) > $@
	@cat $@

%.elf: $(RISCV_TESTS_DIR)/isa/rv32*/%.S
	@riscv64-unknown-elf-gcc -I./ $(RISCV_TESTS_INC) -T test/linker.ld $(TEST_CFLAGS) $^ -o $@

#### Own tests ####

modelsim-buffer_sum: buffer_sum.bin $(VERILOG_SOURCES)
	@hexdump $(HEXDUMP_FLAGS) $< > memory.hex.txt
	vlib work
	vlog -ccflags "-std=c++11" $(VERILOG_SOURCES)
	vsim -do tb/modelsim.do $(TOP_MODULE)

run-buffer_sum: buffer_sum.bin obj_dir/$(VERILATOR_VTOP)
	@hexdump $(HEXDUMP_FLAGS) $< > memory.hex.txt
	@obj_dir/$(VERILATOR_VTOP) -m 20000 $(ARGS)

buffer_sum.elf: test/start.s test/buffer_sum.c
	riscv64-unknown-elf-gcc -T test/linker.ld $(TEST_CFLAGS) $^ -o $@

run-memcpy: memcpy.bin obj_dir/$(VERILATOR_VTOP)
	@hexdump $(HEXDUMP_FLAGS) $< > memory.hex.txt
	@obj_dir/$(VERILATOR_VTOP) -m 20000 $(ARGS)

memcpy.elf: test/start.s test/memcpy.c
	riscv64-unknown-elf-gcc -T test/linker.ld $(TEST_CFLAGS) $^ -o $@

run-matrix_multiply: matrix_multiply.bin obj_dir/$(VERILATOR_VTOP)
	@hexdump $(HEXDUMP_FLAGS) $< > memory.hex.txt
	@obj_dir/$(VERILATOR_VTOP) -m 100000 $(ARGS)

matrix_multiply.elf: test/start.s test/matrix_multiply.c
	riscv64-unknown-elf-gcc -T test/linker.ld $(TEST_CFLAGS) $^ -o $@

# Test code
test.elf: $(TEST_SOURCES)
	riscv64-unknown-elf-gcc -T test/linker.ld $(TEST_CFLAGS) $^ -o $@

disasm_test: test.elf
	@riscv64-unknown-elf-objdump -M numeric,no-aliases -D $^

#### Common rules ####
%.bin: %.elf
	@riscv64-unknown-elf-objcopy -S -O binary $^ $@

%.hex.txt: %.bin
	@hexdump $(HEXDUMP_FLAGS) $< > $@

clean: riscv-tests-clean
	@rm -rf obj_dir work $(TRACE_FILE) $(TRACE_FILE).hier *.elf *.bin *.hex.txt \
		vsim.wlf transcript

.PHONY:
	verilate run trace gtkwave riscv-tests clean riscv-tests-clean
