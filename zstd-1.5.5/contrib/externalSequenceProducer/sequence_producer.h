/*
 * Copyright (c) Yann Collet, Meta Platforms, Inc.
 * All rights reserved.
 *
 * This source code is licensed under both the BSD-style license (found in the
 * LICENSE file in the root directory of this source tree) and the GPLv2 (found
 * in the COPYING file in the root directory of this source tree).
 * You may select, at your option, one of the above-listed licenses.
 */

#ifndef MATCHFINDER_H
#define MATCHFINDER_H

#define ZSTD_STATIC_LINKING_ONLY
#include "zstd.h"
#include "stdint.h"
#include "stdio.h"

#define SIMULATOR_SLICE_LOG 15
#define SIMULATOR_SLICE_SIZE (1 << SIMULATOR_SLICE_LOG)

typedef struct  {
  // FILE* seqFd;
  // FILE* indexFd;
  uint32_t* index;
  uint64_t* seqs;
  size_t seqIdx;
  size_t blockIdx;
} SimpleSimulatorSequenceProducerState;

size_t simpleSimulatorSequenceProducer(
  void* sequenceProducerState,
  ZSTD_Sequence* outSeqs, size_t outSeqsCapacity,
  const void* src, size_t srcSize,
  const void* dict, size_t dictSize,
  int compressionLevel,
  size_t windowSize
);

#endif
