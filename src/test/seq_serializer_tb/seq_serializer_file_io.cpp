#include "seq_serializer_file_io.h"

namespace seq_serializer_tb {
SeqSerializerFileIO::SeqSerializerFileIO(std::string seqFilePath, std::string rawFilePath) {
  // open seq file and load into buffer by line
  // format of seq file: ll,ml,offset,eoj,delim,overlap
  std::ifstream seqFile(seqFilePath);
  if (!seqFile.is_open()) {
    throw std::runtime_error("Failed to open seq file");
  }
  std::string line;
  while (std::getline(seqFile, line)) {
    std::istringstream iss(line);
    BeeZipSeq seq;
    std::string token;
    std::getline(iss, token, ',');
    seq.ll = std::stoi(token);
    std::getline(iss, token, ',');
    seq.ml = std::stoi(token);
    std::getline(iss, token, ',');
    seq.offset = std::stoi(token);
    std::getline(iss, token, ',');
    seq.eoj = std::stoi(token);
    std::getline(iss, token, ',');
    seq.delim = std::stoi(token);
    std::getline(iss, token, ',');
    seq.overlap = std::stoi(token);
    seqBuffer.push_back(seq);
  }
  seqFile.close();
  std::cout << "Read " << seqBuffer.size() << " seqs from " << seqFilePath << std::endl;
  // open raw file and load into buffer by byte
  std::ifstream rawFile(rawFilePath, std::ios::binary);
  if (!rawFile.is_open()) {
    throw std::runtime_error("Failed to open raw file");
  }
  rawFile.seekg(0, std::ios::end);
  int fileSize = rawFile.tellg();
  rawBuffer.resize(fileSize);
  rawFile.seekg(0, std::ios::beg);
  rawFile.read(rawBuffer.data(), rawBuffer.size());
  rawFile.close();
  std::cout << "Read " << rawBuffer.size() << " bytes from " << rawFilePath << std::endl;
  // open outputFile for output
  std::string outputFilePath = seqFilePath + "_serialized";
  outputFile.open(outputFilePath);
  if (!outputFile.is_open()) {
    throw std::runtime_error("Failed to open output file");
  }
  // init state
  headIdx = 0;
}

SeqSerializerFileIO::~SeqSerializerFileIO() { outputFile.close(); }

BeeZipSeq SeqSerializerFileIO::readInputSeq() {
  return seqBuffer[headIdx];
}

void SeqSerializerFileIO::moveHeadIdx() { headIdx++; }

int SeqSerializerFileIO::getHeadIdx() { return headIdx; }

int SeqSerializerFileIO::getSeqBufferSize() { return seqBuffer.size(); }

int SeqSerializerFileIO::getRawBufferSize() { return rawBuffer.size(); }

void SeqSerializerFileIO::writeSerializedSeq(int ll, int ml, int offset, bool delim) {
  outputFile << ll << "," << ml << "," << offset << "," << (delim ? "1":"0") << std::endl;
}

unsigned char SeqSerializerFileIO::probeData(int addr) { return rawBuffer[addr]; }
}  // namespace seq_serializer_tb
