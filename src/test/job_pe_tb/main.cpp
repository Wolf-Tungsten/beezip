#include "job_pe_tb.h"

int main(int argc, char **argv)
{
    auto contextp = std::make_unique<VerilatedContext>();
    contextp->commandArgs(argc, argv);
    auto dut = std::make_unique<Vjob_pe>();
    auto tb = std::make_unique<job_pe_tb::JobPETestbench>(contextp, dut);
    tb->run();
    return 0;
}