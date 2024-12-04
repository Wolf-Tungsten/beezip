
INC_DIR_PATH   := ${BEEZIP_SRC_DIR}/main
ZSTD_EXT_SEQ_PROD_PATH	   := ${ZSTD_1_5_5_DIR}/contrib/externalSequenceProducer


# Verification
BEEZIP_TB_DIR := ${BEEZIP_SRC_DIR}/test/beezip_tb
BEEZIP_TB_CSRC := $(wildcard ${BEEZIP_TB_DIR}/*.cpp)
BEEZIP_TB_INC := ${BEEZIP_TB_DIR}
build_beezip_tb:
	mkdir -p ${BEEZIP_SIM_DIR}/beezip_tb
	verilator --cc --exe --build -j 8 --trace-fst \
	-f ${BEEZIP_TB_DIR}/beezip_tb.f -I${INC_DIR_PATH} \
	${BEEZIP_TB_CSRC} -CFLAGS "-I${BEEZIP_TB_INC} -std=c++17" \
	--top-module beezip \
	-Mdir ${BEEZIP_SIM_DIR}/beezip_tb

SEQ_SERIALIZER_TB_DIR := ${BEEZIP_SRC_DIR}/test/seq_serializer_tb
SEQ_SERIALIZER_TB_CSRC := $(wildcard ${SEQ_SERIALIZER_TB_DIR}/*.cpp)
SEQ_SERIALIZER_TB_INC := ${SEQ_SERIALIZER_TB_DIR}
build_seq_serializer_tb:
	mkdir -p ${BEEZIP_SIM_DIR}/seq_serializer_tb
	verilator --cc --exe --build -j 8 --trace-fst \
	-f ${SEQ_SERIALIZER_TB_DIR}/seq_serializer_tb.f -I${INC_DIR_PATH} \
	${SEQ_SERIALIZER_TB_CSRC} -CFLAGS "-I${SEQ_SERIALIZER_TB_INC} -std=c++17 -g -O0" \
	--top-module seq_serializer \
	-Mdir ${BEEZIP_SIM_DIR}/seq_serializer_tb

build_entropy_encoder:
	mkdir -p ${BEEZIP_SIM_DIR}
	make -C ${ZSTD_EXT_SEQ_PROD_PATH} externalSequenceProducer -j32
	mv ${ZSTD_EXT_SEQ_PROD_PATH}/externalSequenceProducer ${BEEZIP_SIM_DIR}/externalSequenceProducer


BASIC_TEST_SIM_OUT_DIR := ${BEEZIP_RUN_DIR}/sim_out/basic_test
FAST_SIM_OUT_DIR := ${BEEZIP_RUN_DIR}/sim_out/fast
BALANCED_SIM_OUT_DIR := ${BEEZIP_RUN_DIR}/sim_out/balanced
BETTER_SIM_OUT_DIR := ${BEEZIP_RUN_DIR}/sim_out/better

run_basic_test: build_beezip_tb build_seq_serializer_tb build_entropy_encoder
	mkdir -p ${BASIC_TEST_SIM_OUT_DIR}
	cp ${CORPUS_DIR}/alice29.txt ${BASIC_TEST_SIM_OUT_DIR}/
	${BEEZIP_SIM_DIR}/beezip_tb/Vbeezip +inputFilePath+${BASIC_TEST_SIM_OUT_DIR}/alice29.txt +hqt+1 +enableHashCheck+1
	${BEEZIP_SIM_DIR}/seq_serializer_tb/Vseq_serializer +seqFilePath+${BASIC_TEST_SIM_OUT_DIR}/alice29.txt.beezip_seq +rawFilePath+${BASIC_TEST_SIM_OUT_DIR}/alice29.txt
	${BEEZIP_SIM_DIR}/externalSequenceProducer ${BASIC_TEST_SIM_OUT_DIR}/alice29.txt ${BASIC_TEST_SIM_OUT_DIR}/alice29.txt.beezip_seq_serialized 

run_fast_test: build_beezip_tb build_seq_serializer_tb build_entropy_encoder
	python3 ${BEEZIP_UTILS_DIR}/run_batch_sim.py \
	--sim_path ${BEEZIP_SIM_DIR}/beezip_tb/Vbeezip \
	--serializer_path ${BEEZIP_SIM_DIR}/seq_serializer_tb/Vseq_serializer \
	--entropy_encoder_path ${BEEZIP_SIM_DIR}/externalSequenceProducer \
	--input_file_dir ${CORPUS_DIR}/silesia \
	--output_file_dir ${FAST_SIM_OUT_DIR} \
	--beezip_mode fast
	# python3 ${BEEZIP_UTILS_DIR}/run_batch_sim.py --sim_path ${HW_SIM_BIN} \
	# --entropy_encoder_path ${SW_SIM_BIN} \
	# --input_file_dir ${CORPUS_DIR}/silesia \
	# --output_file_dir ${BALANCED_SIM_OUT_DIR} \
	# --beezip_mode balanced
	# python3 ${BEEZIP_UTILS_DIR}/run_batch_sim.py --sim_path ${HW_SIM_BIN} \
	# --entropy_encoder_path ${SW_SIM_BIN} \
	# --input_file_dir ${CORPUS_DIR}/silesia \
	# --output_file_dir ${BETTER_SIM_OUT_DIR} \
	# --beezip_mode better
	# @echo
	# @echo "=============== BeeZip Fast Result ==============="
	# @echo
	# @python3 ${BEEZIP_UTILS_DIR}/merge_sim_result.py --output_file_dir ${FAST_SIM_OUT_DIR}
	# @echo
	# @echo "=================================================="
	# @echo
	# @echo
	# @echo "============= BeeZip Balanced Result ============="
	# @echo
	# @python3 ${BEEZIP_UTILS_DIR}/merge_sim_result.py --output_file_dir ${BALANCED_SIM_OUT_DIR}
	# @echo
	# @echo "=================================================="
	# @echo
	# @echo
	# @echo "============== BeeZip Better Result =============="
	# @echo
	# @python3 ${BEEZIP_UTILS_DIR}/merge_sim_result.py --output_file_dir ${BETTER_SIM_OUT_DIR}
	# @echo
	# @echo "=================================================="
	# @echo

run_balanced_test: build_beezip_tb build_seq_serializer_tb build_entropy_encoder
	python3 ${BEEZIP_UTILS_DIR}/run_batch_sim.py \
	--sim_path ${BEEZIP_SIM_DIR}/beezip_tb/Vbeezip \
	--serializer_path ${BEEZIP_SIM_DIR}/seq_serializer_tb/Vseq_serializer \
	--entropy_encoder_path ${BEEZIP_SIM_DIR}/externalSequenceProducer \
	--input_file_dir ${CORPUS_DIR}/silesia \
	--output_file_dir ${BALANCED_SIM_OUT_DIR} \
	--beezip_mode balanced

run_better_test: build_beezip_tb build_seq_serializer_tb build_entropy_encoder
	python3 ${BEEZIP_UTILS_DIR}/run_batch_sim.py \
	--sim_path ${BEEZIP_SIM_DIR}/beezip_tb/Vbeezip \
	--serializer_path ${BEEZIP_SIM_DIR}/seq_serializer_tb/Vseq_serializer \
	--entropy_encoder_path ${BEEZIP_SIM_DIR}/externalSequenceProducer \
	--input_file_dir ${CORPUS_DIR}/silesia \
	--output_file_dir ${BETTER_SIM_OUT_DIR} \
	--beezip_mode better

clean:
	make -C ${ZSTD_EXT_SEQ_PROD_PATH} clean
	rm -rf ${BEEZIP_RUN_DIR}
	rm -rf ${BEEZIP_SIM_DIR}
	mkdir -p ${FAST_SIM_OUT_DIR}
	mkdir -p ${BALANCED_SIM_OUT_DIR}
	mkdir -p ${BETTER_SIM_OUT_DIR}
	clear