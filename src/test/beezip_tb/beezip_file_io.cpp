#include "beezip_file_io.h"

namespace beezip_tb {
BeeZipFileIO::BeeZipFileIO(std::string inputFilePath, const int jobLen,
                           const int hashIssueWidth)
    : inputFilePath(inputFilePath),
      jobLen(jobLen),
      hashIssueWidth(hashIssueWidth) {
  this->outputFilePath = inputFilePath + ".beezip_seq";
  // open input file and load into buffer by byte
  std::ifstream inputFile(inputFilePath, std::ios::binary);
  if (!inputFile.is_open()) {
    throw std::runtime_error("Failed to open input file");
  }
  inputFile.seekg(0, std::ios::end);
  int fileSize = inputFile.tellg();
  if(fileSize % jobLen != 0) {
    std::cout << "Warning: input file size is not multiple of jobLen, ignore the last " << fileSize % jobLen << " bytes" << std::endl;
    fileSize -= fileSize % jobLen;
  }
  buffer.resize(fileSize);
  inputFile.seekg(0, std::ios::beg);
  inputFile.read(buffer.data(), buffer.size());
  inputFile.close();
  headAddr = 0;
  outputFile.open(outputFilePath);
  if (!outputFile.is_open()) {
    throw std::runtime_error("Failed to open output file");
  }
}

BeeZipFileIO::~BeeZipFileIO() { outputFile.close(); }

std::pair<int, std::vector<unsigned char>> BeeZipFileIO::readData() {
  std::vector<unsigned char> dataSlice(buffer.begin() + headAddr,
                              buffer.begin() + headAddr + hashIssueWidth);
  return std::make_pair(headAddr += hashIssueWidth, dataSlice);
}

unsigned char BeeZipFileIO::probeData(int addr) { return buffer[addr]; }
void BeeZipFileIO::writeSeq(int ll, int ml, int offset, bool eoj, bool delim,
                            int overlap) {
  outputFile << ll << "," << ml << "," << offset << "," << eoj << "," << delim
             << "," << overlap << std::endl;
}

int BeeZipFileIO::getFileSize() { return buffer.size(); }

void BeeZipFileIO::writeThroughput(long length, long cycle) {
  throughputFilePath = inputFilePath + ".throughput";
  std::ofstream throughputFile(throughputFilePath);
  if (!throughputFile.is_open()) {
    throw std::runtime_error("Failed to open throughput file");
  }
  throughputFile << "length: " << length << std::endl;
  throughputFile << "cycle: " << cycle << std::endl;
  throughputFile << "throughput: " << (double)length / cycle << "bytes/cycle" << std::endl;
  throughputFile.close();
}
}  // namespace beezip_tb
