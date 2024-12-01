#include "Vseq_serializer.h"
#include "seq_serializer_file_io.h"
#include "verilated_fst_c.h"

namespace seq_serializer_tb {

class SeqSerializerTestbench {
 public:
  SeqSerializerTestbench(std::unique_ptr<VerilatedContext>& contextp,
                  std::unique_ptr<Vseq_serializer>& dut,
                  std::string seqFilePath, std::string rawFilePath);
  ~SeqSerializerTestbench();
  void run();

 private:
  std::unique_ptr<VerilatedFstC> tfp;
  std::unique_ptr<VerilatedContext> contextp;
  std::unique_ptr<Vseq_serializer> dut;

  std::unique_ptr<SeqSerializerFileIO> fileIOptr;

  bool outputEof;
  int nextVerifyAddr;
  std::vector<unsigned char> checkBuffer;
  void serveInput();
  void serveOutput();
  void checkAndWriteSeq();
  
};
}  // namespace beezip_tb