import csv
from collections import defaultdict
def cluster_and_count(input_file, output_file):
    # 使用 defaultdict 来记录每行内容的计数
    row_dict = defaultdict(int)
    # 读取 CSV 文件，计算每行的出现次数
    with open(input_file, mode='r', newline='') as csvfile:
        csvreader = csv.reader(csvfile)
        for row in csvreader:
            row_tuple = tuple(row)  # 使用 tuple 作为字典的键
            row_dict[row_tuple] += 1
    # 将结果写入新的 CSV 文件
    with open(output_file, mode='w', newline='') as csvfile:
        csvwriter = csv.writer(csvfile)
        for row, count in row_dict.items():
            csvwriter.writerow(list(row) + [count])
# 示例使用
input_file = 'run/sram2p_usage.csv'
output_file = 'run/sram2p_count.csv'
cluster_and_count(input_file, output_file)