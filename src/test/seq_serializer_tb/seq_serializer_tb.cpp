#include "seq_serializer_tb.h"

namespace seq_serializer_tb {

SeqSerializerTestbench::SeqSerializerTestbench(
    std::unique_ptr<VerilatedContext>& contextp,
    std::unique_ptr<Vseq_serializer>& dut, std::string seqFilePath,
    std::string rawFilePath) {
  this->contextp = std::move(contextp);
  this->dut = std::move(dut);
  this->contextp->traceEverOn(true);
  this->tfp = std::make_unique<VerilatedFstC>();
  this->dut->trace(this->tfp.get(), 99);
  std::string traceFilePath = rawFilePath + ".fst";
  this->tfp->open(traceFilePath.c_str());
  this->fileIOptr =
      std::make_unique<SeqSerializerFileIO>(seqFilePath, rawFilePath);
}

SeqSerializerTestbench::~SeqSerializerTestbench() { dut->final(); }

void SeqSerializerTestbench::run() {
  dut->clk = 0;
  dut->rst_n = !1;
  nextVerifyAddr = 0;
  dut->i_valid = 0;
  dut->o_ready = 0;
  outputEof = false;
  bool success = true;
  try {
    // reset
    while (contextp->time() < 10) {
      dut->clk = !dut->clk;
      dut->eval();
      tfp->dump(contextp->time());
      contextp->timeInc(1);
    }
    dut->o_ready = 1;
    dut->rst_n = !0;
    // main loop
    while (!outputEof) {
      dut->clk = !dut->clk;
      if (dut->clk) {
        // 输入握手成功，更新 testbench 内部状态
        if (dut->i_ready && dut->i_valid) {
          std::cout << "[testbench @ " << contextp->time() << "] feed seq"
                    << ", headIdx=" << fileIOptr->getHeadIdx() << 
                    ", ll=" << dut->i_ll << ", ml=" << dut->i_ml <<
                    ", offset=" << dut->i_offset << ", eoj=" << (dut->i_eoj ? "1" : "0") <<
                    ", delim=" << (dut->i_delim ? "1" : "0") << ", overlap=" << dut->i_overlap_len << std::endl;
          fileIOptr->moveHeadIdx();
        }
        serveOutput();
      }
      dut->eval();
      tfp->dump(contextp->time());
      contextp->timeInc(1);
      if(dut->clk) {
        serveInput();
      }
    }
  } catch (const std::exception &e) {
    std::cerr << e.what() << std::endl;
    success = false;
    tfp->dump(contextp->time());
    contextp->timeInc(10);
    tfp->dump(contextp->time());
  }
  if(!success) {
    std::cout << "Simulation failed with error." << std::endl;
  } else {
    std::cout << "Simulation finished successfully!" << std::endl;
  }
  tfp->close();
}

void SeqSerializerTestbench::serveInput() {
  if (fileIOptr->getHeadIdx() < fileIOptr->getSeqBufferSize()) {
    dut->i_valid = 1;
    auto seq = fileIOptr->readInputSeq();
    dut->i_ll = seq.ll;
    dut->i_ml = seq.ml;
    dut->i_offset = seq.offset;
    dut->i_eoj = seq.eoj;
    dut->i_delim = seq.delim;
    dut->i_overlap_len = seq.overlap;
  } else {
    dut->i_valid = 0;
  }
}

void SeqSerializerTestbench::serveOutput() {
  if (dut->o_valid) {
    checkAndWriteSeq();
  }
}

void SeqSerializerTestbench::checkAndWriteSeq() {
    BeeZipSerializedSeq seq;
    seq.ll = dut->o_ll;
    seq.ml = dut->o_ml;
    seq.offset = dut->o_offset;
    seq.delim = dut->o_delim;
    std::cout << "[testbench @ " << contextp->time() << "] get output seq: "
              << "nextVerifyAddr=" << nextVerifyAddr
              << ", ll=" << seq.ll << ", ml=" << seq.ml << ", offset=" << seq.offset << std::endl;
    // 检查 seq 的正确性
    // 处理 ll
    // 1.从 fileIOptr 中 probe ll 字节数据加入 checkBuffer 尾部
    // 2.推进 nextVerifyAddr
    for (int j = 0; j < seq.ll; j++) {
      checkBuffer.push_back(fileIOptr->probeData(nextVerifyAddr + j));
    }
    nextVerifyAddr += seq.ll;
    // 处理 ml
    // 1.根据 offset 和 ml 从 checkBuffer 中取出数据加入 checkBuffer 尾部
    // 2.检查 checkBuffer 从 nextVerifyAddr 开始的 ml 字节数据和 fileIOptr
    // 中的数据是否一致 3.推进 nextVerifyAddr
    for (int j = 0; j < seq.ml; j++) {
      checkBuffer.push_back(checkBuffer[nextVerifyAddr - seq.offset + j]);
      if (checkBuffer[nextVerifyAddr + j] !=
          fileIOptr->probeData(nextVerifyAddr + j)) {
        std::cout << "nextVerifyAddr: " << nextVerifyAddr << std::endl;
        throw std::runtime_error("ml not match");
      }
    }
    nextVerifyAddr += seq.ml;
    // 输出 seq
    fileIOptr->writeSerializedSeq(seq.ll, seq.ml, seq.offset, seq.delim);
    // 判断是否到达文件末尾
    if (nextVerifyAddr == fileIOptr->getRawBufferSize()) {
      outputEof = true;
    }
}
};  // namespace seq_serializer_tb
