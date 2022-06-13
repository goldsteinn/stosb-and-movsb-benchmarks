import sys
import statistics
from common_util import strs

SIZE = None
sz = None
arr = []
fmt = "{:>15}{:>8} GB/s ( +- {:>6})    {:>8} GB/s ( +- {:>6})   {:>6}%"
print(" " * 18 + "{:<20}          {:<20}       Delta(%)".format(
    "movntdq xmm (5 runs)", "movnti GPR (5 runs)"))
print(" " * 18 + "{:>20}       {:>20}".format("-----------------------",
                                              "-----------------------"))
print(fmt.format("size", "BW", "stdev", "BW", "stdev", ""))

for line in open(sys.argv[1]):
    line = strs(line)

    if line == "":
        print(
            fmt.format(
                sz, round(statistics.mean(arr[0]), 2),
                round(statistics.stdev(arr[0]), 2),
                round(statistics.mean(arr[1]), 2),
                round(statistics.stdev(arr[1]), 2),
                round(
                    100.0 -
                    100 * statistics.mean(arr[0]) / statistics.mean(arr[1]),
                    2)))
        SIZE = None
        arr = []
        continue

    if "MB" in line:
        SIZE = (int(line.split()[0]) * 1024 * 1024)
        sz = line
        continue
    line = line.split(",")
    for i in range(0, len(line)):
        GB = SIZE / (1024 * 1024 * 1024)
        S_TIME = int(line[i]) / (2 * 1024 * 1024 * 1024)
        S_TIME /= ((1 << 33) / (SIZE))

        line[i] = GB / S_TIME
    arr.append(line)
