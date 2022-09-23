f_vector_table = open("C:/dev/ama-riscv-sim/SW/out/build/ama-riscv-sim/src/vector_table.txt", "r")
f_vector = open("C:/dev/ama-riscv/verif/direct_tb/vector_import.v", "w")

for x in f_vector_table:
    x = x.replace('\n','')
    f_vector.write("\n")
    f_vector.write("integer fd_%s;\n" % (x))
    f_vector.write("integer sample_cnt_%s = 0;\n" % (x))
    f_vector.write("reg [31:0] %s;\n" % (x))
    f_vector.write("initial begin\n")
    f_vector.write("    fd_%s = $fopen($sformatf(\"%%0s/%s.txt\", stim_path), \"r\");\n" % (x, x))
    f_vector.write("    if (fd_%s) begin\n" % (x))
    f_vector.write("        $display(\"File '%s' opened: %%0d\", fd_%s);\n" % (x, x))
    f_vector.write("    end\n")
    f_vector.write("    else begin\n")
    f_vector.write("        $display(\"File '%s' could not be opened: %%0d. Exiting simulation.\", fd_%s);\n"  % (x, x))
    f_vector.write("        $finish;\n")
    f_vector.write("    end\n")
    f_vector.write("    while (! $feof(fd_%s)) begin\n" % (x))
    f_vector.write("        $fscanf(fd_%s, \"%%d\\n\", %s);\n" % (x, x))
    f_vector.write("        sample_cnt_%s = sample_cnt_%s + 1; \n" % (x, x))
    f_vector.write("        @(posedge clk); \n")
    f_vector.write("    end\n")
    f_vector.write("end\n")
    f_vector.write("initial begin\n")
    f_vector.write("    @(posedge sim_done); \n")
    f_vector.write("    $display(\"Vector read '%s' done. Samples read: %%0d.\", sample_cnt_%s);\n"  % (x, x))
    f_vector.write("end\n")

f_vector_table.close()
f_vector.close()

map_inactive="dummy" # this is used as a string for ignored checker in chk_map.txt
f_vector_table = open("C:/dev/ama-riscv-sim/SW/out/build/ama-riscv-sim/src/vector_table.txt", "r")
f_chk_map = open("C:/dev/ama-riscv/verif/scripts/chk_map.txt", "r")
f_checker = open("C:/dev/ama-riscv/verif/direct_tb/checkers_task.v", "w")
f_checker.write("task run_checkers;\n")
f_checker.write("    integer checker_errors_prev;\n")
f_checker.write("    integer %s;\n" % (map_inactive))
f_checker.write("    begin\n")
f_checker.write("        checker_errors_prev = errors;\n")

for x in f_vector_table:
    x = x.replace('\n','')
    x_name = x.replace('chk_','')
    y = f_chk_map.readline()
    y = y.replace('\n','')
    if (y != map_inactive and y != "") : # valid hier path
        f_checker.write("        checker_t(\"%s\", `CHECKER_ACTIVE, %s, %s);\n" % (x_name, y, x))
    else :
        f_checker.write("        checker_t(\"%s\", `CHECKER_INACTIVE, %s, %s);\n" % (x_name, map_inactive, x))

f_checker.write("        errors_for_wave = (errors != checker_errors_prev);\n")
f_checker.write("    end // main task body\n")
f_checker.write("endtask // run_checkers\n")

f_vector_table.close()
f_chk_map.close()
f_checker.close()
