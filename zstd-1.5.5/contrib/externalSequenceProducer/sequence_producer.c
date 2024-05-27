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

#define JOB_LEN 64
typedef struct {
    uint8_t endOfJob;
    uint8_t hasOverlap;
    uint8_t overlapLen;
    uint16_t litLen;
    uint32_t offset;
    uint8_t matchLen;
} SimulatorSeq;

typedef struct {
    uint8_t flags;
    uint8_t overlapLen;
    uint16_t litLen;
    uint32_t matchLenAndOffset;
} SimRawSeq;


SimRawSeq srawSeq;
SimRawSeq* srawSeqPtr;
inline void getNextSeq(SimpleSimulatorSequenceProducerState* state, SimulatorSeq* sseq) {
   //fread(&rawSeq, sizeof(uint64_t), 1, state->seqFd);

   srawSeqPtr = (SimRawSeq*)(state->seqs);
   srawSeq = srawSeqPtr[state->seqIdx++];
   sseq->endOfJob = srawSeq.flags & 0x04;
   sseq->hasOverlap = srawSeq.flags & 0x08;
   sseq->overlapLen = srawSeq.overlapLen;
   sseq->litLen = srawSeq.litLen;
   sseq->offset = srawSeq.matchLenAndOffset & 0x0FFFFFF;
   sseq->matchLen = srawSeq.matchLenAndOffset >> 24;
}

size_t simpleSimulatorSequenceProducer(
  void* sequenceProducerState,
  ZSTD_Sequence* outSeqs, size_t outSeqsCapacity,
  const void* src, size_t srcSize,
  const void* dict, size_t dictSize,
  int compressionLevel,
  size_t windowSize
) {
    //printf("src=%ld\n", src);
    SimpleSimulatorSequenceProducerState* state = (SimpleSimulatorSequenceProducerState*)sequenceProducerState;
    (void)dict;
    (void)dictSize;
    (void)outSeqsCapacity;
    (void)compressionLevel;

    int blockSeqCount = state -> index[state->blockIdx++];
    int encodeLength = 0;
    int seqCount = 0;
    int gap = 0;
    int overlap = 0;
    ZSTD_Sequence seq;
    SimulatorSeq sseq;

    // normal loop
    for(int i = 0; i < blockSeqCount - 1; i++) {
        
        getNextSeq(state, &sseq);

        if(sseq.endOfJob) {
            if(gap > 0){
                if(sseq.hasOverlap) {
                    // gap + overlap
                    seq.litLength = gap + sseq.litLen;
                    seq.matchLength = sseq.matchLen;
                    seq.offset = sseq.offset;
                    gap = 0;
                    overlap = sseq.overlapLen;
                    encodeLength += seq.litLength + seq.matchLength;
                    outSeqs[seqCount++] = seq;
                } else {
                    // gap + gap
                    gap += sseq.litLen;
                }
            } else if (overlap > 0){
                if(sseq.hasOverlap){
                    // overlap + overlap, make later overlap into gap
                    if(overlap <= sseq.litLen){
                        seq.litLength = sseq.litLen - overlap;
                        seq.matchLength = sseq.matchLen;
                        seq.offset = sseq.offset;
                        overlap = sseq.overlapLen;
                        encodeLength += seq.litLength + seq.matchLength;
                        outSeqs[seqCount++] = seq;
                    } else if (overlap <= sseq.litLen + sseq.matchLen - 4){
                        seq.litLength = 0;
                        seq.matchLength = sseq.matchLen - (overlap - sseq.litLen);
                        seq.offset = sseq.offset;
                        overlap = sseq.overlapLen;
                        encodeLength += seq.matchLength;
                        outSeqs[seqCount++] = seq;
                    } else if (overlap <= sseq.litLen + sseq.matchLen){
                        gap = sseq.litLen + sseq.matchLen - overlap - sseq.overlapLen;
                        overlap = 0;
                    } else {
                        printf("error: overlap > sseq.litLen + sseq.matchLen\n");
                        exit(1);
                    }
                } else {
                    // overlap + gap, just trim overlap
                    gap = sseq.litLen - overlap;
                    overlap = 0;
                }
            } else {
                // normal end of job
                if(sseq.hasOverlap) {
                    // normal overlap
                    seq.litLength = sseq.litLen;
                    seq.matchLength = sseq.matchLen;
                    seq.offset = sseq.offset;
                    overlap = sseq.overlapLen;
                    encodeLength += seq.litLength + seq.matchLength;
                    outSeqs[seqCount++] = seq;
                } else {
                    // normal gap
                    gap = sseq.litLen;
                }
            }
            
            // debugJobCount += 1;
            // if(overlap > 0){
            //     if((encodeLength - overlap) != debugJobCount * JOB_LEN){
            //         printf("encodeLength error overlap %d!\n", debugJobCount);
            //         exit(1);
            //     }
            // } else if (gap > 0){
            //     if((encodeLength + gap) != debugJobCount * JOB_LEN){
            //         printf("encodeLength error gap %d\n", debugJobCount);
            //         exit(2);
            //     }
            // } else {
            //     if(encodeLength != debugJobCount * JOB_LEN){
            //         printf("encodeLength error %d\n", debugJobCount);
            //         exit(3);
            //     }
            // }
        } else {
            if(gap > 0){
                seq.litLength = gap + sseq.litLen;
                seq.matchLength = sseq.matchLen;
                seq.offset = sseq.offset;
                gap = 0;
                overlap = 0;
                encodeLength += seq.litLength + seq.matchLength;
                outSeqs[seqCount++] = seq;
            } else if (overlap > 0) {
                if(overlap <= sseq.litLen){
                    seq.litLength = sseq.litLen - overlap;
                    seq.matchLength = sseq.matchLen;
                    seq.offset = sseq.offset;
                    overlap = 0;
                    encodeLength += seq.litLength + seq.matchLength;
                    outSeqs[seqCount++] = seq;
                } else if (overlap <= sseq.litLen + sseq.matchLen - 6) {
                    seq.litLength = 0;
                    seq.matchLength = sseq.matchLen - (overlap - sseq.litLen);
                    seq.offset = sseq.offset;
                    overlap = 0;
                    encodeLength += seq.matchLength;
                    outSeqs[seqCount++] = seq;
                } else if (overlap <= sseq.litLen + sseq.matchLen) {
                    gap = sseq.litLen + sseq.matchLen - overlap;
                    overlap = 0;
                } else {
                    overlap -= sseq.litLen + sseq.matchLen;
                }
            } else {
                seq.litLength = sseq.litLen;
                seq.matchLength = sseq.matchLen;
                seq.offset = sseq.offset;
                encodeLength += seq.litLength + seq.matchLength;
                outSeqs[seqCount++] = seq;
            }
        }
        // if(encodeLength > srcSize){
        //     printf("overflow encodeLength=%d, srcSize=%ld\n", encodeLength, srcSize);
        //     exit(1);
        // }
    }


    // tail process
    seq.litLength = srcSize - encodeLength;
    seq.matchLength = 0;
    seq.offset = 0;
    outSeqs[seqCount++] = seq;
    encodeLength += seq.litLength;
    getNextSeq(state, &sseq); // drop tail seq

    if(encodeLength != srcSize) {
        printf("encodeLength=%d, srcSize=%ld\n", encodeLength, srcSize);
        exit(2);
    }

    return seqCount;
}