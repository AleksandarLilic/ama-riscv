
# NOTES
# first `set synth_dir "<path_to_synt_dir>"` as path to the vivado synt dir
# e.g. <project_dir>/synt_proj.runs/impl_1
# run from vivado tcl shell: `source script/flash_bit.tcl`

set start [expr {[clock seconds] - 1}]
set device xc7a100t_0

# {bitfile_suffix  wait_time_seconds}
set workloads {}
lappend workloads {"ama_riscv_fpga.dhrystone.dhrystone.bit"     12}
lappend workloads {"ama_riscv_fpga.coremark.coremark.bit"       14}
lappend workloads {"ama_riscv_fpga.stream_int.stream.bit"        4}

lappend workloads {"ama_riscv_fpga.mlp.w8a8.bit"                 2}
lappend workloads {"ama_riscv_fpga.mlp.w4a8.bit"                 2}
lappend workloads {"ama_riscv_fpga.mlp.w2a8.bit"                 2}

lappend workloads {"ama_riscv_fpga.embench.aha-mont64.bit"       6}
lappend workloads {"ama_riscv_fpga.embench.crc32.bit"            6}
lappend workloads {"ama_riscv_fpga.embench.cubic.bit"            12}
lappend workloads {"ama_riscv_fpga.embench.edn.bit"              5}
lappend workloads {"ama_riscv_fpga.embench.huffbench.bit"        4}
lappend workloads {"ama_riscv_fpga.embench.matmult-int.bit"      5}
lappend workloads {"ama_riscv_fpga.embench.md5sum.bit"           4}
lappend workloads {"ama_riscv_fpga.embench.minver.bit"           8}
lappend workloads {"ama_riscv_fpga.embench.nbody.bit"            6}
lappend workloads {"ama_riscv_fpga.embench.nettle-aes.bit"       6}
lappend workloads {"ama_riscv_fpga.embench.nettle-sha256.bit"    6}
lappend workloads {"ama_riscv_fpga.embench.nsichneu.bit"         6}
lappend workloads {"ama_riscv_fpga.embench.picojpeg.bit"         5}
lappend workloads {"ama_riscv_fpga.embench.primecount.bit"       4}
lappend workloads {"ama_riscv_fpga.embench.qrduino.bit"          5}
lappend workloads {"ama_riscv_fpga.embench.sglib-combined.bit"   4}
lappend workloads {"ama_riscv_fpga.embench.slre.bit"             4}
lappend workloads {"ama_riscv_fpga.embench.st.bit"               6}
lappend workloads {"ama_riscv_fpga.embench.statemate.bit"        3}
lappend workloads {"ama_riscv_fpga.embench.tarfind.bit"          5}
lappend workloads {"ama_riscv_fpga.embench.ud.bit"               6}
lappend workloads {"ama_riscv_fpga.embench.wikisort.bit"         3}

lappend workloads {"ama_riscv_fpga.ustress.branch_direct.bit"    2}
lappend workloads {"ama_riscv_fpga.ustress.branch_indirect.bit"  2}
lappend workloads {"ama_riscv_fpga.ustress.call_return.bit"      2}
lappend workloads {"ama_riscv_fpga.ustress.div32.bit"            2}
lappend workloads {"ama_riscv_fpga.ustress.div64.bit"            2}
lappend workloads {"ama_riscv_fpga.ustress.l1d_cache.bit"        2}
lappend workloads {"ama_riscv_fpga.ustress.l1i_cache.bit"        2}
lappend workloads {"ama_riscv_fpga.ustress.load_after_store.bit" 2}
lappend workloads {"ama_riscv_fpga.ustress.mac32.bit"            2}
lappend workloads {"ama_riscv_fpga.ustress.mac64.bit"            2}
lappend workloads {"ama_riscv_fpga.ustress.memcpy.bit"           2}
lappend workloads {"ama_riscv_fpga.ustress.mul32.bit"            2}
lappend workloads {"ama_riscv_fpga.ustress.mul64.bit"            2}

foreach workload $workloads {
    set bitfile  [lindex $workload 0]
    set wait_sec [lindex $workload 1]
    set bitpath  "$synth_dir/$bitfile"

    puts "Flashing $bitpath"
    set_property PROBES.FILE      {} [get_hw_devices $device]
    set_property FULL_PROBES.FILE {} [get_hw_devices $device]
    set_property PROGRAM.FILE $bitpath [get_hw_devices $device]
    program_hw_devices [get_hw_devices $device]
    refresh_hw_device [lindex [get_hw_devices $device] 0]

    puts "Waiting ${wait_sec}s for workload to complete..."
    after [expr {$wait_sec * 1000}]
    puts "Done waiting for $bitfile"
}

puts "All workloads complete."
puts "Runtime: [expr {[clock seconds] - $start}]s"
