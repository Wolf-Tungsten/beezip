#include "job_pe_tb.h"
#include <random>
#include <string>
#include <iostream>
namespace job_pe_tb
{
    JobPETestbench::JobPETestbench(std::unique_ptr<VerilatedContext>& contextp, std::unique_ptr<Vjob_pe>& dut)
    {
        this->contextp = std::move(contextp);
        this->dut = std::move(dut);
        // 参数格式为 +verilator+seed+<value> 从中提取value
        // 按 + 分割，取最后一个进行提取
        std::string seedArg = this->contextp->commandArgsPlusMatch("verilator+seed");
        if (seedArg.size() > 0)
        {
            std::string seedStr = seedArg.substr(seedArg.find_last_of("+") + 1);
            this->seed = std::stoi(seedStr);
        }
        else
        {
            this->seed = std::random_device()();
        }
        std::cout << "Random Seed: " << this->seed << std::endl;
        gen = std::mt19937(this->seed);
        this->contextp->traceEverOn(true);
        this->tfp = std::make_unique<VerilatedVcdC>();
        this->dut->trace(this->tfp.get(), 99);
        this->tfp->open("job_pe_tb.vcd");
    }

    JobPETestbench::~JobPETestbench()
    {
        tfp->close();
        dut->final();
    }

    void JobPETestbench::run()
    {
        // 生成测试序列
        generateJobs();
        finishedJobCount = 0;
        inputJobIdx = 0;
        outputJobIdx = 0;
        hashBatchIdx = 0;
        seqVerifiedIdx = 0;
        dut->clk = 0;
        dut->rst_n = !1;
        dut->hash_batch_valid = 0;
        dut->seq_ready = 0;
        dut->match_resp_valid = 0;
        dut->match_req_ready = 0;
        try
        {
            while (finishedJobCount < TEST_JOB_COUNT)
            {
                contextp->timeInc(1);
                dut->clk = !dut->clk;
                if (!dut->clk)
                {
                    if (contextp->time() > 10)
                    {
                        dut->rst_n = !0;
                        serveHashBatch();
                        serveMatchReq();
                        serveMatchResp();
                        serveSeq();
                    }
                }
                dut->eval();
                tfp->dump(contextp->time());
            }
        }
        catch (const std::exception &e)
        {
            std::cerr << e.what() << std::endl;
            return;
        }
    }

    void JobPETestbench::generateJobs()
    {
        std::uniform_int_distribution<int> headAddrDist(0, 0x7fffff);
        std::bernoulli_distribution boolDist(0.5);
        for (int i = 0; i < TEST_JOB_COUNT; i++)
        {
            Job job;
            job.headAddr = i;
            job.delim = boolDist(gen);
            for (int j = 0; j < JOB_LEN; j++)
            {
                int headAddr = job.headAddr + j;
                int max_offset = headAddr < WINDOW_SIZE ? headAddr : WINDOW_SIZE;
                int offset = std::uniform_int_distribution<>(0, max_offset)(gen);
                HashResultItem item;
                item.matchLen = std::uniform_int_distribution<int>(0, MAX_MATCH_LEN)(gen);
                item.historyValid = item.matchLen >= MIN_MATCH_LEN;
                item.historyAddr = headAddr - offset;
                item.metaMatchCanExt = item.matchLen >= META_HISTORY_LEN;
                item.metaMatchLen = item.metaMatchCanExt ? META_HISTORY_LEN : item.matchLen;
                job.hashResults.push_back(item);
            }
            jobs.push_back(job);
        }
    }

    void JobPETestbench::serveHashBatch()
    {
        if (dut->hash_batch_valid && prevHashBatchReady)
        {
            hashBatchIdx++;
            if (hashBatchIdx >= JOB_LEN / HASH_ISSUE_WIDTH)
            {
                hashBatchIdx = 0;
                inputJobIdx++;
            }
        }
        prevHashBatchReady = dut->hash_batch_ready;
        if (inputJobIdx >= TEST_JOB_COUNT)
        {
            dut->hash_batch_valid = 0;
            return;
        }
        bool valid = std::bernoulli_distribution(0.5)(gen);
        dut->hash_batch_valid = valid;
        if (!valid)
        {
            return;
        }
        auto &job = jobs[inputJobIdx];
        dut->hash_batch_delim = job.delim && (hashBatchIdx == JOB_LEN / HASH_ISSUE_WIDTH - 1);
        dut->hash_batch_head_addr = job.headAddr + hashBatchIdx * HASH_ISSUE_WIDTH;
        // 设置 history_valid 和 meta_match_can_ext
        dut->hash_batch_history_valid = 0;
        dut->hash_batch_meta_match_can_ext = 0;
        for (int i = HASH_ISSUE_WIDTH - 1; i >= 0; i--)
        {
            auto &item = job.hashResults[hashBatchIdx * HASH_ISSUE_WIDTH + i];
            dut->hash_batch_history_valid |= item.historyValid;
            dut->hash_batch_history_valid <<= 1;
            dut->hash_batch_meta_match_can_ext |= item.metaMatchCanExt;
            dut->hash_batch_meta_match_can_ext <<= 1;
        }

        // 设置 historyAddr 和 metaMatchLen
        uint64_t historyAddrBuf = 0, metaMatchLenBuf = 0;
        int historyAddrRb = 0, metaMatchLenRb = 0;
        int historyAddrI = 0, metaMatchLenI = 0;
        for (int i = 0; i < HASH_ISSUE_WIDTH; i++)
        {
            auto &item = job.hashResults[hashBatchIdx * HASH_ISSUE_WIDTH + i];
            historyAddrBuf |= item.historyAddr << historyAddrRb;
            historyAddrRb += ADDR_WIDTH;
            while (historyAddrRb >= 32)
            {
                dut->hash_batch_history_addr[historyAddrI++] = historyAddrBuf & 0xffffffff;
                historyAddrBuf >>= 32;
                historyAddrRb -= 32;
            }
            metaMatchLenBuf |= item.metaMatchLen << metaMatchLenRb;
            metaMatchLenRb += META_MATCH_LEN_WIDTH;
            while (metaMatchLenRb >= 32)
            {
                dut->hash_batch_meta_match_len[metaMatchLenI++] = metaMatchLenBuf & 0xffffffff;
                metaMatchLenBuf >>= 32;
                metaMatchLenRb -= 32;
            }
        }
        if (historyAddrRb > 0)
        {
            dut->hash_batch_history_addr[historyAddrI] = historyAddrBuf;
        }
        if (metaMatchLenRb > 0)
        {
            dut->hash_batch_meta_match_len[metaMatchLenI] = metaMatchLenBuf;
        }
    }

    void JobPETestbench::serveMatchReq()
    {
        if (dut->match_req_valid && dut->match_req_ready)
        {
            // 检查 req 的正确性
            int matchReqHeadAddr = dut->match_req_head_addr;
            int matchReqHistoryAddr = dut->match_req_history_addr;
            int matchReqTag = dut->match_req_tag;
            auto &currentJob = jobs[outputJobIdx];
            int itemIdx = matchReqHeadAddr - META_MATCH_LEN_WIDTH - currentJob.headAddr;
            if (itemIdx < 0 || itemIdx >= JOB_LEN)
            {
                throw std::runtime_error("Invalid match req head addr");
            }
            if (currentJob.hashResults[itemIdx].historyAddr != matchReqHistoryAddr - META_MATCH_LEN_WIDTH)
            {
                tfp->dump(contextp->time());
                throw std::runtime_error("Invalid match req history addr");
            }
            // 检查都正确，将 req 转换成 resp 放入队列
            MatchResp resp;
            resp.tag = matchReqTag;
            resp.matchLen = currentJob.hashResults[itemIdx].matchLen;
            matchRespQueue.push_back(resp);
        }
        // 更新 match_req_ready
        dut->match_req_ready = std::bernoulli_distribution(0.5)(gen);
    }

    void JobPETestbench::serveMatchResp()
    {
        if (dut->match_resp_valid && prevMatchRespReady)
        {
            matchRespQueue.pop_front();
        }
        prevMatchRespReady = dut->match_resp_ready;
        if (matchRespQueue.empty())
        {
            dut->match_resp_valid = 0;
            return;
        }
        bool valid = std::bernoulli_distribution(0.5)(gen);
        dut->match_resp_valid = valid;
        if (valid)
        {
            auto &resp = matchRespQueue.front();
            dut->match_resp_tag = resp.tag;
            dut->match_resp_len = resp.matchLen;
        }
    }

    void JobPETestbench::serveSeq()
    {
        if (dut->seq_valid && dut->seq_ready)
        {
            seqVerifiedIdx += dut->seq_ll;
            auto &item = jobs[outputJobIdx].hashResults[seqVerifiedIdx];
            if (dut->seq_ml > 0)
            {
                if (dut->seq_ml != item.matchLen)
                {
                    throw std::runtime_error("Invalid seq match len");
                }
                if (dut->seq_offset != (jobs[outputJobIdx].headAddr + seqVerifiedIdx) - item.historyAddr)
                {
                    throw std::runtime_error("Invalid seq offset");
                }
            }
            else
            {
                if (!dut->seq_eoj)
                {
                    throw std::runtime_error("Expect seq eoj");
                }
            }
            seqVerifiedIdx += dut->seq_ml;
            if (dut->seq_eoj)
            {
                if (dut->seq_delim != jobs[outputJobIdx].delim)
                {
                    throw std::runtime_error("Invalid seq delim");
                }
                if (dut->seq_delim)
                {
                    if (dut->seq_ml > 0 || dut->seq_overlap_len > 0)
                    {
                        throw std::runtime_error("Wrong delim with overlap");
                    }
                }
                else
                {
                    if (seqVerifiedIdx - JOB_LEN != dut->seq_overlap_len)
                    {
                        throw std::runtime_error("Invalid seq overlap len");
                    }
                }
                outputJobIdx++;
                finishedJobCount++;
                seqVerifiedIdx = 0;
            }
        }
        dut->seq_ready = std::bernoulli_distribution(0.5)(gen);
    }
}