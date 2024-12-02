#include <deque>
#include <memory>
#include <random>
#include <vector>
#include <csignal>
#include <atomic>

#include "Vbeezip.h"
#include "beezip_file_io.h"
#include "verilated_fst_c.h"

namespace beezip_tb {
const int HASH_ISSUE_WIDTH = 16;
const int JOB_LEN = 64;
const int BLOCK_LEN = 128*1024;
const int ADDR_WIDTH = 23;
const int META_MATCH_LEN_WIDTH = 5;
const int META_HISTORY_LEN = 15;
const int MIN_MATCH_LEN = 4;
const int SEQ_PACKET_SIZE = 4;
const int SEQ_LL_BITS = 17;
const int SEQ_ML_BITS = 11;
const int SEQ_OFFSET_BITS = 20;

class BeeZipTestbench {
 public:
  BeeZipTestbench(std::unique_ptr<VerilatedContext>& contextp,
                  std::unique_ptr<Vbeezip>& dut,
                  const std::string& inputFilePath, int hqt, bool enableHashCheck);
  ~BeeZipTestbench();
  void run();
  static std::atomic<bool> interruptSimulation;
  static void signalHandler(int signal);

 private:
  std::unique_ptr<VerilatedFstC> tfp;
  std::unique_ptr<VerilatedContext> contextp;
  std::unique_ptr<Vbeezip> dut;

  std::unique_ptr<BeeZipFileIO> fileIOptr;
  int hqt;
  bool enableHashCheck;

  bool inputEof;
  bool outputEof;
  int nextHashHeadAddr;
  int nextVerifyAddr;
  int jobHeadAddr;
  std::vector<unsigned char> checkBuffer;
  void serveInput();
  void serveOutput();
  void checkHashResult();
  void checkAndWriteSeq();
  
};
}  // namespace beezip_tb