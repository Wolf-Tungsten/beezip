#include <iostream>
#include <fstream>
#include <string>
#include <vector>

namespace beezip_tb {
    class BeeZipFileIO {
    public:
        BeeZipFileIO(std::string inputFilePath, const int jobLen = 64, const int hashIssueWidth = 32);
        ~BeeZipFileIO();
        std::pair<int, std::vector<char>> readData();
        char probeData(int addr);
        void writeSeq(int ll, int ml, int offset, bool eoj, bool delim,
                            int overlapLen);
        int getFileSize();

    private:
        std::vector<char> buffer;
        int jobLen;
        int hashIssueWidth;
        int headAddr;
        std::string inputFilePath;
        std::string outputFilePath;
        std::ofstream outputFile;
    };
} // namespace beezip_tb