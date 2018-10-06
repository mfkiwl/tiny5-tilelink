#include "Tiny5Tb.hpp"

Tiny5Tb::Tiny5Tb(VTOP_MODULE *top) :
	top(top), timeStamp(0), fst(nullptr)
{
}

Tiny5Tb::~Tiny5Tb()
{
	if (fst) {
		fst->dump(timeStamp);
		fst->close();
		delete fst;
	}
}

void Tiny5Tb::resetTick(void)
{
	top->clk_i = 1;
	top->reset_i = 1;
	top->eval();

	advanceTimeStamp();

	top->clk_i = 0;
	top->eval();

	advanceTimeStamp();

	top->reset_i = 0;
}

void Tiny5Tb::tick(void)
{
	top->clk_i = 1;
	top->eval();

	advanceTimeStamp();

	top->clk_i = 0;
	top->eval();

	advanceTimeStamp();
}

void Tiny5Tb::enableTracing(const std::string &name, int levels, int options)
{
	if (fst)
		return;

	Verilated::traceEverOn(true);

	fst = new VerilatedFstC;
	if (!fst)
		return;

	top->trace(fst, levels, options);
	fst->open(name.c_str());
}

uint64_t Tiny5Tb::getTimeStamp(void)
{
	return timeStamp;
}

void Tiny5Tb::advanceTimeStamp(void)
{
	if (fst)
		fst->dump(timeStamp);

	timeStamp++;
}

uint8_t Tiny5Tb::memRead8(uint32_t address)
{
	return mem[address];
}

void Tiny5Tb::memWrite8(uint32_t address, uint8_t data)
{
	mem[address] = data;
}

uint16_t Tiny5Tb::memRead16(uint32_t address)
{
	return (mem[address + 1] << 8) | mem[address];
}

void Tiny5Tb::memWrite16(uint32_t address, uint16_t data)
{
	mem[address] = data & 0xFF;
	mem[address + 1] = (data >> 8) & 0xFF;
}

uint32_t Tiny5Tb::memRead32(uint32_t address)
{
	return (mem[address + 3] << 24) | (mem[address + 2] << 16) |
		(mem[address + 1] << 8) | mem[address];
}

void Tiny5Tb::memWrite32(uint32_t address, uint32_t data)
{
	mem[address] = data & 0xFF;
	mem[address + 1] = (data >> 8) & 0xFF;
	mem[address + 2] = (data >> 16) & 0xFF;
	mem[address + 3] = (data >> 24) & 0xFF;
}
