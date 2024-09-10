#include "Vjob_pe.h"
#include <memory>
#include <vector>

namespace JobPETestBench {
    const int HASH_ISSUE_WIDTH = 16;
    const int JOB_LEN = HASH_ISSUE_WIDTH * 4;
    struct HashResultItem {
        bool historyValid;
        bool historyAddr;
        int metaMatchLen;
        bool metaMatchCanExt;
    };
    struct Job {
        int headAddr;
        std::vector<HashResultItem> hashResults;
        bool delim;
    }
    class JobPETestbench {
        public:
        JobPETestbench(std::unique_ptr<VerilatedContext> contextp, std::unique_ptr<Vjob_pe> dut);
        ~JobPETestbench();
        
        private:
        std::unique_ptr<VerilatedContext> contextp;
        std::unique_ptr<Vjob_pe> dut;
        Job job;

        void generateRandomJob();
    };
}