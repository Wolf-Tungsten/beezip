#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

namespace seq_serializer_tb {
    struct BeeZipSeq {
        int ll;
        int ml; 
        int offset;
        bool eoj;
        bool delim;
        int overlap;
    };
    struct BeeZipSerializedSeq {
        int ll;
        int ml;
        int offset;
        bool delim;
    };
    class SeqSerializerFileIO {
    public:
        SeqSerializerFileIO(std::string seqFilePath, std::string rawFilePath);
        ~SeqSerializerFileIO();
        BeeZipSeq readInputSeq();
        void moveHeadIdx();
        int getHeadIdx();
        int getSeqBufferSize();
        int getRawBufferSize();
        unsigned char probeData(int addr);
        void writeSerializedSeq(int ll, int ml, int offset, bool delim);
    private:
        int headIdx;
        std::vector<BeeZipSeq> seqBuffer;
        std::vector<char> rawBuffer;
        std::ofstream outputFile;
    };
} // namespace beezip_tb