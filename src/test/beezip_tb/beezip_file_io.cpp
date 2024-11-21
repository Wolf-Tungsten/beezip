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
  buffer.resize(inputFile.tellg());
  inputFile.seekg(0, std::ios::beg);
  inputFile.read(buffer.data(), buffer.size());
  inputFile.close();
  if (buffer.size() % jobLen != 0) {
    throw std::runtime_error("Input file size is not multiple of job length");
  }
  headAddr = 0;
  outputFile.open(outputFilePath);
  if (!outputFile.is_open()) {
    throw std::runtime_error("Failed to open output file");
  }
}

BeeZipFileIO::~BeeZipFileIO() { outputFile.close(); }

std::pair<int, std::vector<char>> BeeZipFileIO::readData() {
  std::vector<char> dataSlice(buffer.begin() + headAddr,
                              buffer.begin() + headAddr + hashIssueWidth);
  return std::make_pair(headAddr += hashIssueWidth, dataSlice);
}

char BeeZipFileIO::probeData(int addr) { return buffer[addr]; }
void BeeZipFileIO::writeSeq(int ll, int ml, int offset, bool eoj, bool delim,
                            int overlapLen) {
  outputFile << ll << "," << ml << "," << offset << "," << eoj << "," << delim
             << "," << overlapLen << std::endl;
}

int BeeZipFileIO::getFileSize() { return buffer.size(); }
}  // namespace beezip_tb
