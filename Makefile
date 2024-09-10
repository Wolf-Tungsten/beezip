FILE_LIST_PATH := ${BEEZIP_SRC_DIR}/test/beezip_sim.f
INC_DIR_PATH   := ${BEEZIP_SRC_DIR}/main
ZSTD_EXT_SEQ_PROD_PATH	   := ${ZSTD_1_5_5_DIR}/contrib/externalSequenceProducer
TOP_NAME  := beezip_sim

HW_BUILD_DIR := ${BEEZIP_RUN_DIR}/build/hw
SW_BUILD_DIR := ${BEEZIP_RUN_DIR}/build/sw

HW_SIM_BIN := ${HW_BUILD_DIR}/V${TOP_NAME}
SW_SIM_BIN := ${SW_BUILD_DIR}/externalSequenceProducer

BASIC_TEST_SIM_OUT_DIR := ${BEEZIP_RUN_DIR}/sim_out/basic_test
FAST_SIM_OUT_DIR := ${BEEZIP_RUN_DIR}/sim_out/fast
BALANCED_SIM_OUT_DIR := ${BEEZIP_RUN_DIR}/sim_out/balanced
BETTER_SIM_OUT_DIR := ${BEEZIP_RUN_DIR}/sim_out/better

hw_comp:
	verilator -f ${FILE_LIST_PATH} -I${INC_DIR_PATH} --binary --timing \
	--top-module ${TOP_NAME} -Wno-fatal --build-jobs 32 -O3 \
	-Mdir ${HW_BUILD_DIR}

sw_comp:
	make -C ${ZSTD_EXT_SEQ_PROD_PATH} externalSequenceProducer -j32
	mv ${ZSTD_EXT_SEQ_PROD_PATH}/externalSequenceProducer ${SW_BUILD_DIR}/externalSequenceProducer


run_basic_test: hw_comp sw_comp
	cp ${CORPUS_DIR}/alice29.txt ${BASIC_TEST_SIM_OUT_DIR}/
	${HW_SIM_BIN} +input_file=${BASIC_TEST_SIM_OUT_DIR}/alice29.txt +beezip_mode=fast
	${SW_SIM_BIN} ${BASIC_TEST_SIM_OUT_DIR}/alice29.txt ${BASIC_TEST_SIM_OUT_DIR}/alice29.txt.seq ${BASIC_TEST_SIM_OUT_DIR}/alice29.txt.index

run_full_ae: hw_comp sw_comp
	python3 ${BEEZIP_UTILS_DIR}/run_batch_sim.py --sim_path ${HW_SIM_BIN} \
	--entropy_encoder_path ${SW_SIM_BIN} \
	--input_file_dir ${CORPUS_DIR}/silesia \
	--output_file_dir ${FAST_SIM_OUT_DIR} \
	--beezip_mode fast
	python3 ${BEEZIP_UTILS_DIR}/run_batch_sim.py --sim_path ${HW_SIM_BIN} \
	--entropy_encoder_path ${SW_SIM_BIN} \
	--input_file_dir ${CORPUS_DIR}/silesia \
	--output_file_dir ${BALANCED_SIM_OUT_DIR} \
	--beezip_mode balanced
	python3 ${BEEZIP_UTILS_DIR}/run_batch_sim.py --sim_path ${HW_SIM_BIN} \
	--entropy_encoder_path ${SW_SIM_BIN} \
	--input_file_dir ${CORPUS_DIR}/silesia \
	--output_file_dir ${BETTER_SIM_OUT_DIR} \
	--beezip_mode better
	@echo
	@echo "=============== BeeZip Fast Result ==============="
	@echo
	@python3 ${BEEZIP_UTILS_DIR}/merge_sim_result.py --output_file_dir ${FAST_SIM_OUT_DIR}
	@echo
	@echo "=================================================="
	@echo
	@echo
	@echo "============= BeeZip Balanced Result ============="
	@echo
	@python3 ${BEEZIP_UTILS_DIR}/merge_sim_result.py --output_file_dir ${BALANCED_SIM_OUT_DIR}
	@echo
	@echo "=================================================="
	@echo
	@echo
	@echo "============== BeeZip Better Result =============="
	@echo
	@python3 ${BEEZIP_UTILS_DIR}/merge_sim_result.py --output_file_dir ${BETTER_SIM_OUT_DIR}
	@echo
	@echo "=================================================="
	@echo


clean:
	make -C ${ZSTD_EXT_SEQ_PROD_PATH} clean
	rm -rf ${BEEZIP_RUN_DIR}
	mkdir -p ${HW_BUILD_DIR}
	mkdir -p ${SW_BUILD_DIR}
	mkdir -p ${BASIC_TEST_SIM_OUT_DIR}
	mkdir -p ${FAST_SIM_OUT_DIR}
	mkdir -p ${BALANCED_SIM_OUT_DIR}
	mkdir -p ${BETTER_SIM_OUT_DIR}
	clear

# Verification
JOB_PE_TB_DIR := ${BEEZIP_SRC_DIR}/test/job_pe_tb
JOB_PE_TB_CSRC := $(wildcard ${JOB_PE_TB_DIR}/*.cpp)
JOB_PE_TB_INC := ${JOB_PE_TB_DIR}
build_job_pe_tb:
	mkdir -p ${BEEZIP_SIM_DIR}/job_pe_tb
	rm -rf ${BEEZIP_SIM_DIR}/job_pe_tb
	verilator --cc --exe --build -j 1 \
	-f ${JOB_PE_TB_DIR}/job_pe_tb.f -I${INC_DIR_PATH} \
	${JOB_PE_TB_CSRC} -CFLAGS -I${JOB_PE_TB_INC}\
	--top-module job_pe \
	-Mdir ${BEEZIP_SIM_DIR}/job_pe_tb