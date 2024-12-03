import os
import subprocess
import argparse
from multiprocessing import Process

# step 1: split input file 
def split_input_file(input_file_path, block_size, output_file_dir):
    # get input file names
    input_file_name = os.path.basename(input_file_path) 
    # create output file dir
    os.makedirs(output_file_dir, exist_ok=True)
    with open(input_file_path, 'rb') as input_file:
        input_data = input_file.read()
        num_blocks = len(input_data) // block_size + 1
        output_file_paths = []
        for i in range(num_blocks):
            start = i * block_size
            end = min((i + 1) * block_size, len(input_data))
            output_file_name = f"{input_file_name}_block_{i}"
            output_file_path = os.path.join(output_file_dir, output_file_name)
            with open(output_file_path, 'wb') as output_file:
                output_file.write(input_data[start:end])
            output_file_paths.append(output_file_path)
    return output_file_paths

# step2: run sim for each block
# spawn *.seq, *.index, *.throughput
def run_sim(sim_path, serializer_path, input_file_path, beezip_mode):
    hqt_map = {
        "fast": "1",
        "balanced": "2",
        "better": "4",
    }
    # run Vbeezip
    args = [sim_path, "+inputFilePath+" + input_file_path, "+hqt+"+hqt_map[beezip_mode], "+enableHashCheck+1"]
    process = subprocess.Popen(args)
    process.wait()
    # run Vseq_serializer
    args = [serializer_path, 
            "+seqFilePath+"+ input_file_path + ".beezip_seq", 
            "+rawFilePath+"+ input_file_path]
    process = subprocess.Popen(args)
    process.wait()
    return process.returncode

# step3: run entropy encoder for each block
# spawn *.compression_ratio
def run_entropy_encoder(entropy_encoder_path, input_file_path):
    args = [entropy_encoder_path, input_file_path, input_file_path + ".beezip_seq_serialized"]
    process = subprocess.Popen(args)
    process.wait()
    return process.returncode

def simulation_single_file(sim_path, serializer_path, entropy_encoder_path, input_file_path, block_size, output_file_dir, beezip_mode):
    print("start simulation of file: " + input_file_path)
    block_path = split_input_file(input_file_path, block_size, output_file_dir)
    # spawn multiple process, each process run_sim() for each block
    p_list = []
    for path in block_path:
        p = Process(target=run_sim, args=(sim_path, serializer_path, path, beezip_mode))
        p.start()
        p_list.append(p)
    for p in p_list:
        p.join()
    # spawn multiple process, each process run_entropy_encoder() for each block
    p_list = []
    for path in block_path:
        p = Process(target=run_entropy_encoder, args=(entropy_encoder_path, path))
        p.start()
        p_list.append(p)


if __name__ == "__main__":
    
    block_size = 8 * 1024 * 1024
    parser = argparse.ArgumentParser()
    parser.add_argument("--sim_path", type=str, required=True)
    parser.add_argument("--serializer_path", type=str, required=True)
    parser.add_argument("--entropy_encoder_path", type=str, required=True)
    parser.add_argument("--input_file_dir", type=str, required=True)
    parser.add_argument("--output_file_dir", type=str, required=True)
    parser.add_argument("--beezip_mode", type=str, required=True)
    args = parser.parse_args()
    sim_path = args.sim_path
    serializer_path = args.serializer_path
    entropy_encoder_path = args.entropy_encoder_path
    input_file_dir = args.input_file_dir
    output_file_dir = args.output_file_dir
    beezip_mode = args.beezip_mode
    
    main_processes = []

    for file_name in os.listdir(input_file_dir):
        input_file_path = os.path.join(input_file_dir, file_name)
        p = Process(target=simulation_single_file, args=(sim_path, serializer_path, entropy_encoder_path, input_file_path, block_size, output_file_dir, beezip_mode))
        p.start()
        main_processes.append(p)

    for p in main_processes:
        p.join()