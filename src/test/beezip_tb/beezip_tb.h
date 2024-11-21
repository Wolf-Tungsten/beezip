#include <deque>
#include <memory>
#include <random>
#include <vector>

#include "Vbeezip.h"
#include "beezip_file_io.h"
#include "verilated_vcd_c.h"

namespace beezip_tb {
const int HASH_ISSUE_WIDTH = 32;
const int JOB_LEN = 64;
const int BLOCK_LEN = 128 * 1024;

class BeeZipTestbench {
 public:
  BeeZipTestbench(std::unique_ptr<VerilatedContext>& contextp,
                  std::unique_ptr<Vbeezip>& dut,
                  const std::string& inputFilePath, int hqt);
  ~BeeZipTestbench();
  void run();

 private:
  std::unique_ptr<VerilatedVcdC> tfp;
  std::unique_ptr<VerilatedContext> contextp;
  std::unique_ptr<Vbeezip> dut;

  std::unique_ptr<BeeZipFileIO> fileIOptr;
  int hqt;

  bool inputEof;
  bool outputEof;
  int nextVerifyAddr;
  std::vector<char> checkBuffer;
  void serveInput();
  void serveOutput();
};
}  // namespace beezip_tb