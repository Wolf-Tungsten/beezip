#include "beezip_tb.h"

namespace beezip_tb {

std::atomic<bool> BeeZipTestbench::interruptSimulation;

template <unsigned long words>
uint32_t portSeg32(VlWide<words> &port, int w, int i) {
  int start = i * w;
  int end = (i + 1) * w - 1;  // 包含 end
  // port 数据以多个 32 位的数据组成，这里取出其中的一段
  // 每个数字可能跨越两个 32 位的数据，或者是一个 32 位数据中的一段
  // 先判断是跨越还是在一个 32 位数据中
  int startWord = start / 32;
  int endWord = end / 32;
  int startBit = start % 32;
  int endBit = end % 32;
  if (startWord != endWord) {
    // 跨越两个 32 位数据
    return ((uint32_t)(port[startWord]) >> startBit) |
           ((port[endWord] & ((1 << (endBit + 1)) - 1))
            << (32 - startBit));  // 取两段拼接
  } else {
    // 在一个 32 位数据中
    return ((uint32_t)(port[startWord]) >> startBit) &
           ((1 << (endBit - startBit + 1)) - 1);  // 取出一段
  }
}

uint32_t portSeg32(QData &port, int w, int i) {
  int start = i * w;
  int end = (i + 1) * w - 1;
  return (port >> start) & ((1 << (end - start + 1)) - 1);
}

template <unsigned long words>
bool portBit(VlWide<words> &port, int i) {
  int word = i / 32;
  int bit = i % 32;
  return (port[word] >> bit) & 1;
}

template <typename T>
bool portBit(T &port, int i) {
  return (port >> i) & 1;
}

BeeZipTestbench::BeeZipTestbench(std::unique_ptr<VerilatedContext> &contextp,
                                 std::unique_ptr<Vbeezip> &dut,
                                 const std::string &inputFilePath, int hqt,
                                 bool enableHashCheck) {
  this->contextp = std::move(contextp);
  this->dut = std::move(dut);
  this->contextp->traceEverOn(true);
  this->tfp = std::make_unique<VerilatedFstC>();
  this->dut->trace(this->tfp.get(), 99);
  std::string tracePath = inputFilePath + ".fst";
  this->tfp->open(tracePath.c_str());
  this->fileIOptr =
      std::make_unique<BeeZipFileIO>(inputFilePath, JOB_LEN, HASH_ISSUE_WIDTH);
  this->hqt = hqt;
  this->enableHashCheck = enableHashCheck;
  interruptSimulation = false;
  std::signal(SIGSEGV, beezip_tb::BeeZipTestbench::signalHandler);
  std::signal(SIGINT, beezip_tb::BeeZipTestbench::signalHandler);
}

BeeZipTestbench::~BeeZipTestbench() { dut->final(); }

void BeeZipTestbench::signalHandler(int signal) {
  if (signal == SIGSEGV) {
    std::cerr << "Segmentation fault detected" << std::endl;
    std::exit(signal);  // 退出程序
  } else if (signal == SIGINT) {
    std::cerr << "Interrupt signal detected" << std::endl;
    interruptSimulation = true;
  }
}

void BeeZipTestbench::run() {
  dut->clk = 0;
  dut->rst_n = !1;
  inputEof = false;
  outputEof = false;
  nextHashHeadAddr = 0;
  nextVerifyAddr = 0;
  jobHeadAddr = 0;
  dut->i_valid = 0;
  dut->o_seq_packet_ready = 0;
  dut->cfg_max_queued_req_num = hqt;
  bool success = true;
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
    while (!interruptSimulation && !outputEof) {
      dut->clk = !dut->clk;
      dut->eval();
      tfp->dump(contextp->time());
      contextp->timeInc(1);
      if (dut->clk) {
        // 读取输出，更新 testbench 内部状态
        if (dut->i_ready && dut->i_valid) {
          std::cout << "[testbench @ " << contextp->time() << "] input data"
            << ", headAddr=" << fileIOptr->getHeadAddr() << ", delim=" << (dut->i_delim ? "1" : "0") << std::endl;
          fileIOptr->moveInputPtr();
        }
        serveOutput();
        // 根据 testbench 内部装更新 dut 输入
        if (fileIOptr->getHeadAddr() >= fileIOptr->getFileSize()) {
          dut->i_valid = 0;
        } else {
          serveInput();
        }
      }
    }
  } catch (const std::exception &e) {
    std::cerr << e.what() << std::endl;
    fileIOptr->writeError(e.what());
    success = false;
  }
  if(!success) {
    std::cout << "Simulation failed with error." << std::endl;
  } else if (interruptSimulation) {
    std::cout << "Simulation interrupted." << std::endl;
  } else {
    fileIOptr->writeThroughput(fileIOptr->getFileSize() + fileIOptr->getTailLL(), contextp->time() / 2);
    std::cout << "Simulation finished successfully!" << std::endl;
  }
  tfp->close();
}

void BeeZipTestbench::serveInput() {
  dut->i_valid = 1;
  auto readPair = fileIOptr->readData();
  int nextAddr = readPair.first;
  std::vector<unsigned char> data = readPair.second;
  dut->dbg_i_head_addr = nextAddr;
  for (int i = 0; i < HASH_ISSUE_WIDTH / 4; i++) {
    dut->i_data[i] = ((uint32_t)data[i * 4]) |
                     (((uint32_t)data[i * 4 + 1]) << 8) |
                     (((uint32_t)data[i * 4 + 2]) << 16) |
                     (((uint32_t)data[i * 4 + 3]) << 24);
  }
  if (((nextAddr + HASH_ISSUE_WIDTH) % BLOCK_LEN == 0) || (nextAddr + HASH_ISSUE_WIDTH >= fileIOptr->getFileSize())) {
    dut->i_delim = 1;
  } else {
    dut->i_delim = 0;
  }

}

void BeeZipTestbench::serveOutput() {
  if (dut->dbg_hash_engine_o_valid && dut->dbg_hash_engine_o_ready &&
      enableHashCheck) {
    checkHashResult();
  }
  if (dut->o_seq_packet_valid) {
    checkAndWriteSeq();
  }
}

void BeeZipTestbench::checkHashResult() {
  int headAddr = dut->dbg_hash_engine_o_head_addr;
  if (headAddr != nextHashHeadAddr) {
    throw std::runtime_error("hash result not continuous");
  }
  nextHashHeadAddr += HASH_ISSUE_WIDTH;
  bool delim = dut->dbg_hash_engine_o_delim;
  if (delim) {
    if (((headAddr + HASH_ISSUE_WIDTH) % BLOCK_LEN != 0) &&
        (headAddr + HASH_ISSUE_WIDTH < fileIOptr->getFileSize())) {
      std::cout << "headAddr: " << headAddr << std::endl;
      throw std::runtime_error("Delim not match");
    }
  }
  for (int i = 0; i < HASH_ISSUE_WIDTH; i++) {
    bool history_valid = portBit(dut->dbg_hash_engine_o_history_valid, i);
    uint32_t history_addr =
        portSeg32(dut->dbg_hash_engine_o_history_addr, ADDR_WIDTH, i);
    uint32_t meta_match_len = portSeg32(dut->dbg_hash_engine_o_meta_match_len,
                                        META_MATCH_LEN_WIDTH, i);
    bool meta_match_can_ext =
        portBit(dut->dbg_hash_engine_o_meta_match_can_ext, i);
    uint32_t data = portSeg32(dut->dbg_hash_engine_o_data, 8, i);
    if (fileIOptr->probeData(headAddr + i) != data) {
      std::cout << "headAddr: " << headAddr + i << std::endl;
      throw std::runtime_error("hash data not match");
    }
    if (history_valid) {
      assert(meta_match_len >= MIN_MATCH_LEN &&
             meta_match_len <= META_HISTORY_LEN);
      std::cout << "history_addr: " << history_addr << std::endl;
      std::cout << "headAddr: " << headAddr + i << std::endl;
      std::cout << "meta_match_len: " << meta_match_len << std::endl;
      for (int j = 0; j < meta_match_len; j++) {
        if (fileIOptr->probeData(history_addr + j) !=
            fileIOptr->probeData(headAddr + i + j)) {
          throw std::runtime_error("meta match error");
        }
      }
      if (meta_match_len < META_HISTORY_LEN) {
        assert(!meta_match_can_ext);
      } else {
        assert(meta_match_can_ext);
      }
    }
  }
}

void BeeZipTestbench::checkAndWriteSeq() {
  for (int i = 0; i < SEQ_PACKET_SIZE; i++) {
    if (portBit(dut->o_seq_packet_strb, i)) {
      int ll = portSeg32(dut->o_seq_packet_ll, SEQ_LL_BITS, i);
      int ml = portSeg32(dut->o_seq_packet_ml, SEQ_ML_BITS, i);
      int offset = portSeg32(dut->o_seq_packet_offset, SEQ_OFFSET_BITS, i);
      bool eoj = portBit(dut->o_seq_packet_eoj, i);
      bool delim = portBit(dut->o_seq_packet_delim, i);
      int overlap = portSeg32(dut->o_seq_packet_overlap, SEQ_ML_BITS, i);
      std::cout << "[testbench @ " << contextp->time() << "] get output seq: "
                << "job_head_addr=" << jobHeadAddr
                << ", nextVerifyAddr=" << nextVerifyAddr
                << ", head_addr=" << nextVerifyAddr + ll << ", ll=" << ll
                << ", ml=" << ml << ", offset=" << offset << ", eoj=" << eoj
                << ", delim=" << delim << ", overlap=" << overlap << std::endl;

      // 处理 ll
      // 1.从 fileIOptr 中 probe ll 字节数据加入 checkBuffer 尾部
      // 2.推进 nextVerifyAddr
      for (int j = 0; j < ll; j++) {
        checkBuffer.push_back(fileIOptr->probeData(nextVerifyAddr + j));
      }
      nextVerifyAddr += ll;
      // 处理 ml
      // 1.根据 offset 和 ml 从 checkBuffer 中取出数据加入 checkBuffer 尾部
      // 2.检查 checkBuffer 从 nextVerifyAddr 开始的 ml 字节数据和 fileIOptr
      // 中的数据是否一致 3.推进 nextVerifyAddr
      for (int j = 0; j < ml; j++) {
        checkBuffer.push_back(checkBuffer[nextVerifyAddr - offset + j]);
        if (checkBuffer[nextVerifyAddr + j] !=
            fileIOptr->probeData(nextVerifyAddr + j)) {
          throw std::runtime_error("ml not match");
        }
      }
      nextVerifyAddr += ml;
      // 处理 overlap
      // 1.删除 checkBuffer 尾部的 overlap 字节数据
      // 2.回退 nextVerifyAddr
      if (eoj && !delim) {
        checkBuffer.resize(checkBuffer.size() - overlap);
        nextVerifyAddr -= overlap;
      }
      // 写出 seq
      if (eoj) {
        jobHeadAddr = nextVerifyAddr;
      }
      // 判断是否到达文件末尾
      if (nextVerifyAddr >= fileIOptr->getFileSize()) {
        ll += fileIOptr->getTailLL();
        ll += ml;
        ml = 0;
        offset = 0;
        overlap = 0;
        outputEof = true;
      } 
      fileIOptr->writeSeq(ll, ml, offset, eoj, delim, overlap);
    }
  }
}
}  // namespace beezip_tb