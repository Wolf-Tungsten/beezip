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
        return float(f.read())
    
def get_throughput(file_name):
    with open(file_name, 'r') as f:
        s = f.read()
        numbers = re.findall(r'\d+', s)
        return tuple(map(int, numbers))

def weighted_average(value, weight):
    if len(value) != len(weight):
        return "Error: The length of value and weight arrays should be the same."
    
    total_weight = sum(weight)
    weighted_sum = sum([value[i] * weight[i] for i in range(len(value))])
    
    return weighted_sum / total_weight
    
if __name__ == "__main__":

    # output_file_dir = "/home/gaoruihao/hdd0/project/zstd-accelerator-experiment/output_file/verilator"
    parser = argparse.ArgumentParser()
    parser.add_argument("--output_file_dir", type=str, required=True)
    args = parser.parse_args()
    output_file_dir = args.output_file_dir

    throughput_file_list = get_all_file_with_ext(output_file_dir, ".throughput")
    compression_ratio_file_list = get_all_file_with_ext(output_file_dir, ".comp_ratio")
    result_dict = {}
    for (thf_name, thf_path), (comp_name, comp_path) in zip(throughput_file_list, compression_ratio_file_list):
        original_file_name = get_original_file_name(thf_name)
        assert original_file_name == get_original_file_name(comp_name)
        if original_file_name not in result_dict:
            result_dict[original_file_name] = []
        result_dict[original_file_name].append((get_compression_ratio(comp_path), *get_throughput(thf_path)))
    avg_length_arr = []
    avg_cycle_arr = []
    avg_comp_ratio_arr = []
    avg_comp_length = []
    for file_name, sub_results in result_dict.items():
        length_arr = []
        cycle_arr = []
        comp_ratio_arr = []
        for comp_ratio, length, cycle in sub_results:
            length_arr.append(length)
            cycle_arr.append(cycle)
            comp_ratio_arr.append(comp_ratio)
            avg_length_arr.append(length)
            avg_cycle_arr.append(cycle)
            avg_comp_length.append(length / comp_ratio)
        comp_ratio = weighted_average(comp_ratio_arr, length_arr)
        throughput = sum(length_arr) / sum(cycle_arr)
    
    comp_ratio = sum(avg_length_arr) / sum(avg_comp_length)
    print("Throughtput = %.2f GB/s, Compression Ratio = %.2f" % (sum(avg_length_arr) / sum(avg_cycle_arr) * 1000 / 1024, comp_ratio))