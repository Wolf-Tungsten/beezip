#include <iostream>
#include <fstream>
#include <string>
#include <vector>

namespace beezip_tb {
    class BeeZipFileIO {
    public:
        BeeZipFileIO(std::string inputFilePath, const int jobLen = 64, const int hashIssueWidth = 32);
        ~BeeZipFileIO();
        std::pair<int, std::vector<unsigned char>> readData();
        void moveInputPtr();
        int getHeadAddr();
        unsigned char probeData(int addr);
        void writeSeq(int ll, int ml, int offset, bool eoj, bool delim,
                            int overlap);
        int getFileSize();
        void writeThroughput(long length, long cycle);

    private:
        std::vector<char> buffer;
        int jobLen;
        int hashIssueWidth;
        int headAddr;
        std::string inputFilePath;
        std::string outputFilePath;
        std::string throughputFilePath;
        std::ofstream outputFile;
    };
} // namespace beezip_tb