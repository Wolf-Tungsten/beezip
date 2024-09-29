#include "Vjob_pe.h"
#include "verilated_vcd_c.h"
#include <memory>
#include <vector>
#include <deque>
#include <random>

namespace job_pe_tb {
    const int HASH_ISSUE_WIDTH = 32;
    const int WINDOW_SIZE = 1024 * 1024;
    const int JOB_LEN = 64;
    const int TEST_JOB_COUNT = 1000;
    const int MIN_MATCH_LEN = 4;
    const int MAX_MATCH_LEN = 256;
    const int META_HISTORY_LEN = 15;
    const int META_MATCH_LEN_WIDTH = 5;
    const int ADDR_WIDTH = 23;
    struct HashResultItem {
        bool historyValid;
        uint64_t historyAddr;
        int matchLen;
        uint64_t metaMatchLen;
        bool metaMatchCanExt;
    };
    struct Job {
        int headAddr;
        std::vector<HashResultItem> hashResults;
        bool delim;
    };
    struct MatchResp {
        int tag;
        int matchLen;
    };
    class JobPETestbench {
        public:
        JobPETestbench(std::unique_ptr<VerilatedContext>& contextp, std::unique_ptr<Vjob_pe>& dut);
        ~JobPETestbench();
        void run();
        
        private:
        unsigned int seed;
        std::mt19937 gen;
        std::unique_ptr<VerilatedVcdC> tfp;
        std::unique_ptr<VerilatedContext> contextp;
        std::unique_ptr<Vjob_pe> dut;
        std::vector<Job> jobs;
        int finishedJobCount;
        int inputJobIdx;
        int hashBatchIdx;
        int outputJobIdx;
        bool prevHashBatchReady;
        bool prevMatchRespReady;
        std::deque<MatchResp> matchRespQueue;
        int seqVerifiedIdx;

        void generateJobs();
        void readHashBatch();
        void writeHashBatch();
        void readMatchReq();
        void writeMatchReq();
        void readMatchResp();
        void writeMatchResp();
        void readSeq();
        void writeSeq();
        void printJob(int jobId);

    };
}