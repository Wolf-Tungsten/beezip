#include "beezip_tb.h"

namespace beezip_tb {
BeeZipTestbench::BeeZipTestbench(std::unique_ptr<VerilatedContext> &contextp,
                                 std::unique_ptr<Vbeezip> &dut,
                                 const std::string &inputFilePath, int hqt) {
  this->contextp = std::move(contextp);
  this->dut = std::move(dut);
  this->contextp->traceEverOn(true);
  this->tfp = std::make_unique<VerilatedVcdC>();
  this->dut->trace(this->tfp.get(), 99);
  this->tfp->open("beezip_tb.vcd");
  this->fileIOptr =
      std::make_unique<BeeZipFileIO>(inputFilePath, JOB_LEN, HASH_ISSUE_WIDTH);
  this->hqt = hqt;
}

BeeZipTestbench::~BeeZipTestbench() { dut->final(); }

void BeeZipTestbench::run() {
  dut->clk = 0;
  dut->rst_n = !1;
  inputEof = false;
  outputEof = false;
  dut->i_valid = 0;
  dut->o_seq_packet_ready = 0;
  dut->cfg_max_queued_req_num = hqt;
  try {
    // reset
    while (contextp->time() < 10) {
      dut->clk = !dut->clk;
      dut->eval();
      tfp->dump(contextp->time());
      contextp->timeInc(1);
    }
    dut->o_seq_packet_ready = 1;
    dut->rst_n = !0;
    // main loop
    while (!outputEof) {
      dut->clk = !dut->clk;
      if (dut->clk) {
        if (!inputEof) {
          serveInput();
        }
      }
      dut->eval();
      tfp->dump(contextp->time());
      contextp->timeInc(1);
      if (dut->clk) {
        serveOutput();
      }
    }
  } catch (const std::exception &e) {
    std::cerr << e.what() << std::endl;
  }
  tfp->close();
}

void BeeZipTestbench::serveInput() {
  if (dut->i_ready) {
    dut->i_valid = 1;
    auto [nextAddr, data] = fileIOptr->readData();
    for (int i = 0; i < HASH_ISSUE_WIDTH / 4; i++) {
      dut->i_data[i] = ((int)data[i]) | (((int)data[i + 1]) << 8) |
                       (((int)data[i + 2]) << 16) | (((int)data[i + 3]) << 24);
    }
    if((nextAddr + HASH_ISSUE_WIDTH) % BLOCK_LEN == 0) {
      dut->i_delim = 1;
    } else {
      dut->i_delim = 0;
    }
    if(nextAddr + HASH_ISSUE_WIDTH >= fileIOptr->getFileSize()) {
      inputEof = true;
    }
  } else {
    dut->i_valid = 0;
  }
}  // namespace beezip_tb