#! /usr/bin/env python3

import json
import struct
import subprocess

NRUNS = 5


def bstr_to_int(bstr):
    word = bstr[0:8]
    res = struct.unpack('Q', word)[0]
    return int(res)


def parse_perf_data(data):
    out = {}
    data = data.split("\n")

    for ev_line in data:
        ev_line = ev_line.lstrip().rstrip()
        if ev_line == "":
            continue

        ev_line = ev_line.split(",")
        assert len(ev_line) > 2

        val = ev_line[0].lstrip().rstrip()
        field = ev_line[2].lstrip().rstrip()

        try:
            val = int(val)
        except Exception:
            assert False

        assert field not in out
        out[field] = val

    return out


def run_proc(cmdline, binout):
    print("Running: $> " + cmdline)
    stdout_data = None
    ret = None
    sproc = subprocess.Popen(cmdline,
                             shell=True,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
    stdout_data, stderr_data = sproc.communicate(timeout=300)
    ret = sproc.returncode

    assert ret == 0, "Error running: {}".format(cmdline)

    if binout == 1:
        stdout_data = bstr_to_int(stdout_data)
        return {"tsc": stdout_data}
    elif binout == 0:
        stdout_data = parse_perf_data(stderr_data.decode("utf-8"))
        return stdout_data
    else:
        return None


class Movsb_Params():

    def __init__(self, align_src, align_dst, align_ptr_dst, align_ptr_src):
        self.align_src = align_src
        self.align_dst = align_dst

        self.align_ptr_src = align_ptr_src
        self.align_ptr_dst = align_ptr_dst

    def build_flags(self):
        return "-DALIGN_SRC={} -DALIGN_DST={} -DALIGN_PTR_SRC={} -DALIGN_PTR_DST={}".format(
            self.align_src, self.align_dst, self.align_ptr_dst,
            self.align_ptr_src)

    def misaligned(self):
        return self.align_dst != 0 or self.align_src != 0

    def valid(self):
        if self.align_ptr_src != 0 and self.align_ptr_dst != 0:
            return False
        return True

    def is_stosb(self):
        return False

    def out(self):
        dout = {}

        dout["align_dst"] = self.align_dst
        dout["align_src"] = self.align_src
        dout["align_ptr_dst"] = self.align_ptr_dst
        dout["align_ptr_src"] = self.align_ptr_src
        return dout


class Stosb_Params():

    def __init__(self, align):
        self.align = align

    def build_flags(self):
        return "-DALIGN={}".format(self.align)

    def misaligned(self):
        return self.align != 0

    def valid(self):
        return True

    def out(self):
        return {"align": self.align}

    def is_stosb(self):
        return True


class Align_Params():

    def __init__(self, align_to, align_ptr, align_len, align_end, pure_copy):
        self.align_to = align_to
        self.align_ptr = align_ptr
        self.align_len = align_len
        self.align_end = align_end

        self.pure_copy = pure_copy

    def out(self):
        dout = {}

        dout["align_to"] = self.align_to
        dout["align_ptr"] = self.align_ptr
        dout["align_len"] = self.align_len
        dout["align_end"] = self.align_end
        dout["pure_copy"] = self.pure_copy
        return dout

    def will_align(self):
        return self.align_to != 0

    def is_pure(self):
        return self.pure_copy != 0

    def build_flags(self):
        return "-DALIGN_TO={} -DALIGN_PTR={} -DALIGN_LEN={} -DALIGN_END={} -DPURE_COPY={}".format(
            self.align_to, self.align_ptr, self.align_len, self.align_end,
            self.pure_copy)

    def valid(self, params, loop):
        if self.align_to != 0:
            if self.pure_copy != 0:
                return False

            if loop:
                if self.align_ptr + self.align_len + self.align_end != 0:
                    return False
            else:
                if self.align_ptr + self.align_len + self.align_end == 0:
                    return False

            if (not loop) and self.align_ptr != 0 and self.align_end != 0:
                return False

            if (not loop) and self.align_len != 0 and self.align_end != 0:
                return False

            if params is not None and isinstance(params, Movsb_Params):
                if loop:
                    if params.align_ptr_dst != 0 or params.align_ptr_src != 0:
                        return False
                else:
                    if self.align_ptr != 0 or self.align_end != 0:
                        if params.align_ptr_dst == 0 and params.align_ptr_src == 0:
                            return False
                    else:
                        if params.align_ptr_dst != 0 or params.align_ptr_src != 0:
                            return False

        else:
            if self.align_ptr + self.align_len + self.align_end != 0:
                return False
            if params is not None and isinstance(params, Movsb_Params):
                if params.align_ptr_dst != 0 or params.align_ptr_src != 0:
                    return False

        return True


class Run():

    def __init__(self, todo, mov_todo, set_len, rand_size, fill_val, perf_line,
                 align_params, custom_params):

        self.todo = todo
        self.mov_todo = mov_todo
        self.set_len = set_len
        self.rand_size = rand_size
        self.fill_val = fill_val
        self.perf_line = perf_line

        self.align_params = align_params
        self.custom_params = custom_params

        self.binout = 0
        if self.perf_line is None:
            self.binout = 1

        self.result = None

    def is_loop(self):
        if "MOVSB" in self.todo or "STOSB" in self.todo or "DRY" in self.todo:
            return False
        return True

    def valid(self):
        if not self.is_loop():
            if "CACHE" not in self.mov_todo:
                return False
        if "DRY" in self.todo:
            if self.perf_line is not None:
                return False
            if self.align_params.will_align():
                return False

        if self.align_params.is_pure():
            if self.rand_size != 0:
                return False
            if self.custom_params.misaligned():
                return False
        else:
            if self.perf_line is not None:
                return False

        if self.custom_params.misaligned():
            if "NT" in self.mov_todo:
                if not self.align_params.will_align():
                    return False

        if self.perf_line is None:
            if self.binout != 1:
                return False
        else:
            if self.binout != 0:
                return False

        return self.align_params.valid(
            self.custom_params, self.is_loop()) and self.custom_params.valid()

    def out(self):
        dout = {}
        dout["todo"] = self.todo.lower()
        dout["mov_method"] = self.mov_todo
        dout["set_len"] = self.set_len
        dout["rand_size"] = self.rand_size
        dout["fill_val"] = self.fill_val

        dout["align_params"] = self.align_params.out()
        dout["custom_params"] = self.custom_params.out()
        dout["build"] = self.build_cmdline()
        dout["run"] = self.run_cmdline()
        dout["result"] = self.result
        return dout

    def params(self):
        common = "-DTODO={} -DMOV_TODO={} -DSET_LEN={} -DRAND_SIZE={} -DFILL_VAL={} -DBINOUT={}".format(
            self.todo, self.mov_todo, self.set_len, self.rand_size,
            self.fill_val, self.binout)

        return "{} {} {}".format(common, self.align_params.build_flags(),
                                 self.custom_params.build_flags())

    def is_stosb(self):
        return self.custom_params.is_stosb()

    def src_name(self):
        if self.is_stosb():
            return "stosb-1thread-base.S"
        else:
            return "movsb-1thread-base.S"

    def run_cmdline(self):
        if self.binout == 0:
            return "perf stat -x, --all-user -e {} ./test".format(
                self.perf_line)
        else:
            return "./test"

    def build_cmdline(self):
        return "gcc -s -static -nostartfiles -nodefaultlibs -nostdlib -Wl,--build-id=none tests/{} -o test {}".format(
            self.src_name(), self.params())

    def run(self):
        assert self.valid()

        run_proc(self.build_cmdline(), -1)
        res0 = {}
        for i in range(0, NRUNS):
            res = run_proc(self.run_cmdline(), self.binout)
            for k in res:
                if k not in res0:
                    res0[k] = []
                res0[k].append(res[k])
        for k in res0:
            assert isinstance(res0[k], list)
            assert len(res0[k]) == NRUNS
        self.result = res0


todos_stosb = ["VEC_SET_FWD", "VEC_SET_BKWD", "STOSB_SET", "DRY_RUN"]
mov_todos = ["NT_STORE", "CACHE_STORE"]
set_lens = [
    1, 2, 4, 6, 8, 10, 12, 16, 20, 24, 32, 48, 64, 80, 96, 112, 128, 196, 256,
    384, 512, 1024
]
rand_sizes = [0]
fill_vals = [0, -1]

perf_lines = [
    None,
    "cpu/event=0x24,umask=0xef,name=l2_rqsts_references_no_pf/,cpu/event=0x24,umask=0xe2,name=l2_rqsts_all_rfo_no_pf/,cpu/event=0x24,umask=0xc2,name=l2_rqsts_rfo_hit_no_pf/,cpu/event=0x24,umask=0x22,name=l2_rqsts_rfo_miss_no_pf/",
    "cpu/event=0x24,umask=0xff,name=l2_rqsts_references_no_pf/,cpu/event=0x24,umask=0xf2,name=l2_rqsts_all_rfo_no_pf/,cpu/event=0x24,umask=0xd2,name=l2_rqsts_rfo_hit_no_pf/,cpu/event=0x24,umask=0x32,name=l2_rqsts_rfo_miss_no_pf/",
    "l2_lines_in.all,l2_lines_out.non_silent,l2_lines_out.silent"
]

runs = []
for todo in todos_stosb:
    for mov_todo in mov_todos:
        for set_len in set_lens:
            for rand_size in rand_sizes:
                for fill_val in fill_vals:
                    for perf_line in perf_lines:
                        r = Run(todo, mov_todo, set_len * 1024 * 1024,
                                rand_size, fill_val, perf_line,
                                Align_Params(0, 0, 0, 0, 1), Stosb_Params(0))
                        if not r.valid():
                            continue
                        runs.append(r)

todos_movsb = ["VEC_SET_FWD", "VEC_SET_BKWD", "MOVSB_SET", "DRY_RUN"]
for todo in todos_movsb:
    for mov_todo in mov_todos:
        for set_len in set_lens:
            for rand_size in rand_sizes:
                for fill_val in fill_vals:
                    for perf_line in perf_lines:
                        r = Run(todo, mov_todo, set_len * 1024 * 1024,
                                rand_size, fill_val, perf_line,
                                Align_Params(0, 0, 0, 0, 1),
                                Movsb_Params(0, 0, 0, 0))
                        if not r.valid():
                            continue
                        runs.append(r)

perf_lines = [None]
mov_todos = ["CACHE_STORE"]
set_lens = []
set_lens += [
    256, 512, 1024, 1024 + 512, 2048, 2048 + 1024, 4096 - 128, 4096,
    4096 + 128, 4096 + 2048, 8192, 8192 + 2048, 8192 + 4096, 16384,
    16384 + 4096, 16384 + 8192, 32768
]

align_tos = [0, 1, 2, 4]
align_ptrs = [0, 1]
align_lens = [0, 1]
align_ends = [0, 1]
rand_sizes = [0, 1]

aligns = [0, 1, 33, 65, 97]

for todo in todos_stosb:
    for mov_todo in mov_todos:
        for set_len in set_lens:
            for rand_size in rand_sizes:
                for perf_line in perf_lines:
                    for align_to in align_tos:
                        for align_ptr in align_ptrs:
                            for align_len in align_lens:
                                for align_end in align_ends:
                                    for align in aligns:
                                        r = Run(
                                            todo, mov_todo, set_len, rand_size,
                                            0, perf_line,
                                            Align_Params(
                                                align_to, align_ptr, align_len,
                                                align_end, 0),
                                            Stosb_Params(align))
                                        if not r.valid():
                                            continue

                                        runs.append(r)
                                        if align == 0:
                                            continue

                                        r = Run(
                                            todo, mov_todo, set_len + align,
                                            rand_size, 0, perf_line,
                                            Align_Params(
                                                align_to, align_ptr, align_len,
                                                align_end, 0),
                                            Stosb_Params(align))
                                        if not r.valid():
                                            continue
                                        runs.append(r)
                                        r = Run(
                                            todo, mov_todo, set_len + align,
                                            rand_size, 0, perf_line,
                                            Align_Params(
                                                align_to, align_ptr, align_len,
                                                align_end, 0), Stosb_Params(0))
                                        if not r.valid():
                                            continue
                                        runs.append(r)
align_ptrs = [0, 1]

for todo in todos_movsb:
    for mov_todo in mov_todos:
        for set_len in set_lens:
            for rand_size in rand_sizes:
                for perf_line in perf_lines:
                    for align_to in align_tos:
                        for align_ptr in align_ptrs:
                            for align_len in align_lens:
                                for align_end in align_ends:
                                    for align_ptr_src in align_ptrs:
                                        for align_ptr_dst in align_ptrs:
                                            for align in aligns:
                                                r = Run(
                                                    todo, mov_todo, set_len,
                                                    rand_size, 0, perf_line,
                                                    Align_Params(
                                                        align_to, align_ptr,
                                                        align_len, align_end,
                                                        0),
                                                    Movsb_Params(
                                                        align, 0,
                                                        align_ptr_src,
                                                        align_ptr_dst))
                                                if not r.valid():
                                                    continue
                                                runs.append(r)

                                                if align == 0:
                                                    continue

                                                r = Run(
                                                    todo, mov_todo, set_len,
                                                    rand_size, 0, perf_line,
                                                    Align_Params(
                                                        align_to, align_ptr,
                                                        align_len, align_end,
                                                        0),
                                                    Movsb_Params(
                                                        0, align,
                                                        align_ptr_src,
                                                        align_ptr_dst))
                                                if not r.valid():
                                                    continue
                                                runs.append(r)
                                                r = Run(
                                                    todo, mov_todo, set_len,
                                                    rand_size, 0, perf_line,
                                                    Align_Params(
                                                        align_to, align_ptr,
                                                        align_len, align_end,
                                                        0),
                                                    Movsb_Params(
                                                        align, 2048,
                                                        align_ptr_src,
                                                        align_ptr_dst))
                                                if not r.valid():
                                                    continue
                                                runs.append(r)
                                                r = Run(
                                                    todo, mov_todo, set_len,
                                                    rand_size, 0, perf_line,
                                                    Align_Params(
                                                        align_to, align_ptr,
                                                        align_len, align_end,
                                                        0),
                                                    Movsb_Params(
                                                        2048, align,
                                                        align_ptr_src,
                                                        align_ptr_dst))
                                                if not r.valid():
                                                    continue
                                                runs.append(r)

                                                r = Run(
                                                    todo, mov_todo,
                                                    set_len + align, rand_size,
                                                    0, perf_line,
                                                    Align_Params(
                                                        align_to, align_ptr,
                                                        align_len, align_end,
                                                        0),
                                                    Movsb_Params(
                                                        0, 0, align_ptr_src,
                                                        align_ptr_dst))
                                                if not r.valid():
                                                    continue

runsout = {}
i = 0
f = open("log.txt", "w+")
for run in runs:
    run.run()
    runsout[i] = run.out()
    f.write(json.dumps(run.out(), indent=2) + "\n")
    f.flush()

f.write("------------\n")
f.write(json.dumps(runsout, indent=2) + "\n")
f.flush()
f.close()
