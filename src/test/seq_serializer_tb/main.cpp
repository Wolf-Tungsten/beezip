#include "seq_serializer_tb.h"
#include <string>
#include <iostream>

int main(int argc, char **argv)
{  
    auto contextp = std::make_unique<VerilatedContext>();
    contextp->commandArgs(argc, argv);
    std::string seqFilePath = contextp->commandArgsPlusMatch("seqFilePath");
    seqFilePath = seqFilePath.substr(seqFilePath.find_last_of("+") + 1);
    std::string rawFilePath = contextp->commandArgsPlusMatch("rawFilePath");
    rawFilePath = rawFilePath.substr(rawFilePath.find_last_of("+") + 1);
    std::cout << "seqFilePath: " << seqFilePath << std::endl;
    std::cout << "rawFilePath: " << rawFilePath << std::endl; 
    auto dut = std::make_unique<Vseq_serializer>();
    auto tb = std::make_unique<seq_serializer_tb::SeqSerializerTestbench>(contextp, dut, seqFilePath, rawFilePath);
    tb->run();
    return 0;
}