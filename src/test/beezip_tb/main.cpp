#include "beezip_tb.h"
#include <string>
#include <iostream>

int main(int argc, char **argv)
{  
    auto contextp = std::make_unique<VerilatedContext>();
    contextp->commandArgs(argc, argv);
    std::string inputFilePath = contextp->commandArgsPlusMatch("inputFilePath");
    inputFilePath = inputFilePath.substr(inputFilePath.find_last_of("+") + 1);
    std::string hqtArg = contextp->commandArgsPlusMatch("hqt");
    int hqt = std::stoi(hqtArg.substr(hqtArg.find_last_of("+") + 1));
    std::string wlogArg = contextp->commandArgsPlusMatch("wlog");
    int wlog = std::stoi(wlogArg.substr(wlogArg.find_last_of("+") + 1));
    int ws = 1 << wlog;
    std::string enableHashCheckArg = contextp->commandArgsPlusMatch("enableHashCheck");
    bool enableHashCheck = std::stoi(enableHashCheckArg.substr(enableHashCheckArg.find_last_of("+") + 1));
    std::cout << "inputFilePath: " << inputFilePath << std::endl;
    std::cout << "hqt: " << hqt << std::endl;
    std::cout << "ws: " << ws << std::endl;
    std::cout << "enableHashCheck: " << enableHashCheck << std::endl;
    auto dut = std::make_unique<Vbeezip>();
    auto tb = std::make_unique<beezip_tb::BeeZipTestbench>(contextp, dut, inputFilePath, hqt, ws, enableHashCheck);
    tb->run();
    return 0;
}