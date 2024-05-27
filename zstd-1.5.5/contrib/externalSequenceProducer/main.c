/*
 * Copyright (c) Yann Collet, Meta Platforms, Inc.
 * All rights reserved.
 *
 * This source code is licensed under both the BSD-style license (found in the
 * LICENSE file in the root directory of this source tree) and the GPLv2 (found
 * in the COPYING file in the root directory of this source tree).
 * You may select, at your option, one of the above-listed licenses.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <sys/time.h>

#define ZSTD_STATIC_LINKING_ONLY
#include "zstd.h"
#include "zstd_errors.h"
#include "sequence_producer.h" // simpleSequenceProducer

#define CHECK(res)                                      \
do {                                                    \
    if (ZSTD_isError(res)) {                            \
        printf("ERROR: %s\n", ZSTD_getErrorName(res));  \
        return 1;                                       \
    }                                                   \
} while (0)                                             \


int main(int argc, char *argv[]) {
    if (argc != 4) {
        printf("Usage: externalSequenceProducer <originalFile> <seqFile> <indexFile>\n");
        return 1;
    }

    ZSTD_CCtx* const zc = ZSTD_createCCtx();

    //int simpleSequenceProducerState = 0xdeadbeef;
    static SimpleSimulatorSequenceProducerState simpleSequenceProducerState;
    simpleSequenceProducerState.seqIdx = 0;
    simpleSequenceProducerState.blockIdx = 0;
    char filepath[1024];
    // load index file
    sprintf(filepath, "%s", argv[3]);
    FILE* indexFd = fopen(filepath, "rb");
    if (indexFd == NULL) {
        printf("Error: cannot open index file %s\n", filepath);
        exit(1);
    }
    fseek(indexFd, 0, SEEK_END);
    size_t indexAmount = ftell(indexFd) / sizeof(uint32_t);
    fseek(indexFd, 0, SEEK_SET);
    simpleSequenceProducerState.index = (uint32_t*)malloc(sizeof(uint32_t) * indexAmount);
    fread(simpleSequenceProducerState.index, sizeof(uint32_t), indexAmount, indexFd);
    uint64_t seqAmount = 0;
    for (size_t i = 0; i < indexAmount; i++) {
        seqAmount += simpleSequenceProducerState.index[i];
    }
    // load seq file
    sprintf(filepath, "%s", argv[2]);
    FILE* seqFd = fopen(filepath, "rb");
    if (seqFd == NULL) {
        printf("Error: cannot open seq file %s\n", filepath);
        exit(1);
    }
    simpleSequenceProducerState.seqs = (uint64_t*)malloc(sizeof(uint64_t) * seqAmount);
    fread(simpleSequenceProducerState.seqs, sizeof(uint64_t), seqAmount, seqFd);

    // Here is the crucial bit of code!
    ZSTD_registerSequenceProducer(
        zc,
        &simpleSequenceProducerState,
        simpleSimulatorSequenceProducer
    );
    //
    {
        size_t const res = ZSTD_CCtx_setParameter(zc, ZSTD_c_enableSeqProducerFallback, 1);
        CHECK(res);
    }
    {
        size_t const res = ZSTD_CCtx_setParameter(zc, ZSTD_c_compressionLevel, 6);
        CHECK(res);
    }
    {
        size_t const res = ZSTD_CCtx_setParameter(zc, ZSTD_c_windowLog, 20);
        CHECK(res);
    }

    {
        size_t const res = ZSTD_CCtx_setParameter(zc, ZSTD_c_searchForExternalRepcodes, ZSTD_ps_enable);
        CHECK(res);
    }

    FILE *f = fopen(argv[1], "rb");
    assert(f);
    {
        int const ret = fseek(f, 0, SEEK_END);
        assert(ret == 0);
    }
    size_t const srcSize = ftell(f);
    {
        int const ret = fseek(f, 0, SEEK_SET);
        assert(ret == 0);
    }

    char* const src = malloc(srcSize + 1);
    assert(src);
    {
        size_t const ret = fread(src, srcSize, 1, f);
        assert(ret == 1);
        int const ret2 = fclose(f);
        assert(ret2 == 0);
    }

    size_t const dstSize = ZSTD_compressBound(srcSize);
    char* const dst = malloc(dstSize);
    assert(dst);

    size_t const cSize = ZSTD_compress2(zc, dst, dstSize, src, srcSize);
    CHECK(cSize);

    char* const val = malloc(srcSize * 3);
    assert(val);

    {
        size_t const res = ZSTD_decompress(val, srcSize * 3, dst, cSize);
        CHECK(res);
    }

    if (memcmp(src, val, srcSize) == 0) {
        sprintf(filepath, "%s.comp_ratio", argv[1]);
        FILE *crFd = fopen(filepath, "wb");
        printf("Compression and decompression were successful!\n");
        printf("Original size: %lu\n", srcSize);
        printf("Compressed size: %lu\n", cSize);
        printf("Compression_Ratio: %.3f\n", (double)srcSize / cSize);
        fprintf(crFd, "%.3f\n", (double)srcSize / cSize);
        fclose(crFd);
    } else {
        printf("ERROR: input and validation buffers don't match!\n");
        for (size_t i = 0; i < srcSize; i++) {
            if (src[i] != val[i]) {
                printf("First bad index: %zu\n", i);
                break;
            }
        }
        return 1;
    }

    ZSTD_freeCCtx(zc);
    free(src);
    free(dst);
    free(val);
    free(simpleSequenceProducerState.seqs);
    fclose(seqFd);
    fclose(indexFd);
    return 0;
}
