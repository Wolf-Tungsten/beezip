/*
 * Copyright (c) Yann Collet, Meta Platforms, Inc.
 * All rights reserved.
 *
 * This source code is licensed under both the BSD-style license (found in the
 * LICENSE file in the root directory of this source tree) and the GPLv2 (found
 * in the COPYING file in the root directory of this source tree).
 * You may select, at your option, one of the above-listed licenses.
 */

#include "zstd_compress_internal.h"
#include "sequence_producer.h"
#include "stdio.h"

char line[1024];

void getNextSeq(SimpleSimulatorSequenceProducerState* state, ZSTD_Sequence* seq) {
   // outputFile << ll << "," << ml << "," << offset << "," << (delim ? "1":"0") << std::endl;
   // 从输入文件中读取一行，然后解析出ll, ml, offset, delim 放入 seq 中
   // delim 不参与压缩，所以不需要设置
    if (fgets(line, sizeof(line), state->fd) != NULL) {
        unsigned int ll, ml, offset, delim;
        if (sscanf(line, "%u,%u,%u,%u", &ll, &ml, &offset, &delim) == 4) {
            seq->litLength = ll;
            seq->matchLength = ml;
            seq->offset = offset;
            seq->rep = 0; // rep 置 0, zstd 自行处理
        } else {
            printf("Error parsing line: %s\n", line);
        }
    } else {
        if (feof(state->fd)) {
            perror("End of file reached\n");
        } else {
            perror("Error reading from file");
        }
    }
}

size_t simpleSimulatorSequenceProducer(
  void* sequenceProducerState,
  ZSTD_Sequence* outSeqs, size_t outSeqsCapacity,
  const void* src, size_t srcSize,
  const void* dict, size_t dictSize,
  int compressionLevel,
  size_t windowSize
) {
    printf("src=%ld\n", src);
    SimpleSimulatorSequenceProducerState* state = (SimpleSimulatorSequenceProducerState*)sequenceProducerState;
    (void)dict;
    (void)dictSize;
    (void)outSeqsCapacity;
    (void)compressionLevel;


    int encodeLength = 0;
    int seqCount = 0;
    while(1) {
        ZSTD_Sequence seq;
        getNextSeq(state, &seq);
        seq.litLength += state->headLitLen;
        state->headLitLen = 0;
        if(seq.litLength == 0 && seq.matchLength == 0) {
            printf("Warning: seq.litLength == 0 && seq.matchLength == 0\n");
            seq.litLength = srcSize - encodeLength;
            seq.matchLength = 0;
            seq.offset = 0;
            outSeqs[seqCount++] = seq;
            encodeLength += seq.litLength;
            break;
        }
        if(encodeLength + seq.litLength + seq.matchLength > srcSize){
            printf("Warning: encodeLength + seq.litLength + seq.matchLength > srcSize\n");
            state->headLitLen = (encodeLength + seq.litLength + seq.matchLength) - srcSize;
            int remainLen = srcSize - encodeLength;
            seq.litLength = remainLen;
            seq.matchLength = 0;
            seq.offset = 0;
            encodeLength += (seq.litLength + seq.matchLength);
            outSeqs[seqCount++] = seq;
            break;
        } else if(encodeLength + seq.litLength + seq.matchLength == srcSize) {
            printf("Got the last sequence successfully\n");
            state->headLitLen = 0;
            seq.litLength += seq.matchLength;
            seq.matchLength = 0;
            seq.offset = 0;
            outSeqs[seqCount++] = seq;
            encodeLength += (seq.litLength + seq.matchLength);
            break;
        }
        encodeLength += (seq.litLength + seq.matchLength);
        outSeqs[seqCount++] = seq;
    }

    if(encodeLength != srcSize) {
        printf("encodeLength=%d, srcSize=%ld\n", encodeLength, srcSize);
    }
    return seqCount;
}