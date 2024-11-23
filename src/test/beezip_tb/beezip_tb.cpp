#include "beezip_tb.h"

namespace beezip_tb {

template <unsigned long words>
uint32_t portSeg32(VlWide<words> &port, int w, int i) {
  int start = i * w;
  int end = (i + 1) * w - 1; // 包含 end
  // port 数据以多个 32 位的数据组成，这里取出其中的一段
  // 每个数字可能跨越两个 32 位的数据，或者是一个 32 位数据中的一段
  // 先判断是跨越还是在一个 32 位数据中
  int startWord = start / 32;
  int endWord = end / 32;
  int startBit = start % 32;
  int endBit = end % 32;
  if(startWord != endWord) {
    // 跨越两个 32 位数据
    return ((uint32_t)(port[startWord]) >> startBit) | ((port[endWord] & ((1 << (endBit + 1)) - 1)) << (32 - startBit)); // 取两段拼接
  } else {
    // 在一个 32 位数据中
    return ((uint32_t)(port[startWord]) >> startBit) & ((1 << (endBit - startBit + 1)) - 1);  // 取出一段
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
bool portBit(T &port, int i) { return (port >> i) & 1; }

BeeZipTestbench::BeeZipTestbench(std::unique_ptr<VerilatedContext> &contextp,
                                 std::unique_ptr<Vbeezip> &dut,
                                 const std::string &inputFilePath, int hqt,
                                 bool enableHashCheck) {
  this->contextp = std::move(contextp);
  this->dut = std::move(dut);
  this->contextp->traceEverOn(true);
  this->tfp = std::make_unique<VerilatedVcdC>();
  this->dut->trace(this->tfp.get(), 99);
  this->tfp->open("beezip_tb.vcd");
  this->fileIOptr =
      std::make_unique<BeeZipFileIO>(inputFilePath, JOB_LEN, HASH_ISSUE_WIDTH);
  this->hqt = hqt;
  this->enableHashCheck = enableHashCheck;
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
  fileIOptr->writeThroughput(fileIOptr->getFileSize(), contextp->time()/2);
}

void BeeZipTestbench::serveInput() {
  if (dut->i_ready) {
    dut->i_valid = 1;
    auto [nextAddr, data] = fileIOptr->readData();
    for (int i = 0; i < HASH_ISSUE_WIDTH / 4; i++) {
      dut->i_data[i] = ((uint32_t)data[i * 4]) | (((uint32_t)data[i * 4 + 1]) << 8) |
                       (((uint32_t)data[i * 4 + 2]) << 16) |
                       (((uint32_t)data[i * 4 + 3]) << 24);
    }
    if ((nextAddr + HASH_ISSUE_WIDTH) % BLOCK_LEN == 0) {
      dut->i_delim = 1;
    } else {
      dut->i_delim = 0;
    }
    if (nextAddr + HASH_ISSUE_WIDTH >= fileIOptr->getFileSize()) {
      inputEof = true;
    }
  } else {
    dut->i_valid = 0;
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
  bool delim = dut->dbg_hash_engine_o_delim; 
  if (delim) {
    if ((headAddr + HASH_ISSUE_WIDTH) % BLOCK_LEN != 0) {
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
    if(fileIOptr->probeData(headAddr + i) != data) {
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
      fileIOptr->writeSeq(ll, ml, offset, eoj, delim, overlap);
    }
  }
}
}  // namespace beezip_tb