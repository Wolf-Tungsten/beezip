import os
import re
import argparse



def get_all_file_with_ext(dir_path, ext):
    file_list = []
    for file_name in os.listdir(dir_path):
        if file_name.endswith(ext):
            file_list.append((file_name, os.path.join(dir_path, file_name)))
    return sorted(file_list, key=lambda x: x[0])

def get_original_file_name(file_name):
    return file_name.split("_block_")[0]

def get_compression_ratio(file_name):
    with open(file_name, 'r') as f:
        # 寻找 compression_ratio: .3f 的数字
        s = f.read()
        numbers = re.findall(r'\d+\.\d+', s)
        return float(numbers[0])

def get_compressed_length(file_name):
    with open(file_name, 'r') as f:
        s = f.read()
        compressed_length = int(re.findall(r'compressed_length: (\d+)', s)[0]) 
        return compressed_length
    
def get_throughput(file_name):
    with open(file_name, 'r') as f:
        #length: 5345280
        #cycle: 429437
        s = f.read()
        length = int(re.findall(r'length: (\d+)', s)[0])
        cycle = int(re.findall(r'cycle: (\d+)', s)[0])
        return length, cycle
    
if __name__ == "__main__":

    # output_file_dir = "/home/gaoruihao/hdd0/project/zstd-accelerator-experiment/output_file/verilator"
    parser = argparse.ArgumentParser()
    parser.add_argument("--output_file_dir", type=str, required=True)
    args = parser.parse_args()
    output_file_dir = args.output_file_dir
    print(output_file_dir)

    throughput_file_list = get_all_file_with_ext(output_file_dir, ".throughput")
    compression_ratio_file_list = get_all_file_with_ext(output_file_dir, ".compression_ratio")
    result_dict = {}
    for (thf_name, thf_path), (comp_name, comp_path) in zip(throughput_file_list, compression_ratio_file_list):
        original_file_name = get_original_file_name(thf_name)
        assert original_file_name == get_original_file_name(comp_name)
        if original_file_name not in result_dict:
            result_dict[original_file_name] = []
        result_dict[original_file_name].append((get_compressed_length(comp_path), *get_throughput(thf_path)))
    avg_length_arr = []
    avg_cycle_arr = []
    avg_compressed_length_arr = []
    file_count = 0
    for file_name, sub_results in result_dict.items():
        file_compressed_length = 0
        file_length = 0
        file_cycle = 0
        for compressed_length, length, cycle in sub_results:
            avg_length_arr.append(length)
            avg_cycle_arr.append(cycle)
            avg_compressed_length_arr.append(compressed_length)
            file_compressed_length += compressed_length
            file_length += length
            file_cycle += cycle
        file_count += 1
        print("File: %s, Throughput = %.2f GB/s, Compression Ratio = %.2f" % (file_name, file_length / file_cycle * 1000 / 1024, file_length / file_compressed_length))
    
    comp_ratio = sum(avg_length_arr) / sum(avg_compressed_length_arr)
    print("Summary: Throughtput = %.2f GB/s, Compression Ratio = %.2f" % (sum(avg_length_arr) / sum(avg_cycle_arr) * 1000 / 1024, comp_ratio))