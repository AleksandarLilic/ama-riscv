f_vector_table = open("C:/dev/ama-riscv-sim/SW/out/build/ama-riscv-sim/src/vector_table.txt", "r")
f_vector = open("C:/dev/ama-riscv/verif/direct_tb/vector_import.v", "w")

for x in f_vector_table:
    x = x.replace('\n','')
    f_vector.write("\n")
    f_vector.write("integer fd_%s;\n" % (x))
    f_vector.write("reg [31:0] %s;\n" % (x))
    f_vector.write("initial begin    \n")
    f_vector.write("    fd_%s = $fopen({`STIM_PATH, `\"/%s`\", `\".txt`\"}, \"r\");\n" % (x, x))
    f_vector.write("    if (fd_%s) $display(\"File %s opened: %%0d\", fd_%s);\n" % (x, x, x))
    f_vector.write("    else $display(\"File '%s' could not be opened: %%0d\", fd_%s);\n"  % (x, x))
    f_vector.write("    \n")
    f_vector.write("    while (! $feof(fd_%s)) begin\n" % (x))
    f_vector.write("        $fscanf(fd_%s, \"%%d\\n\", %s);\n" % (x, x))
    f_vector.write("        @(posedge clk); \n")
    f_vector.write("    end\n")
    f_vector.write("end\n")

f_vector_table.close()
f_vector.close()

f_vector_table = open("C:/dev/ama-riscv-sim/SW/out/build/ama-riscv-sim/src/vector_table.txt", "r")
f_chk_map = open("C:/dev/ama-riscv/verif/scripts/chk_map.txt", "r")
f_checker = open("C:/dev/ama-riscv/verif/direct_tb/checkers_task.v", "w")
f_checker.write("task run_checkers;\n")
f_checker.write("    integer checker_errors_prev;\n")
f_checker.write("    integer dummy;\n")
f_checker.write("    begin\n")
f_checker.write("        checker_errors_prev = errors;\n")

for x in f_vector_table:
    x = x.replace('\n','')
    x_name = x.replace('chk_','')
    y = f_chk_map.readline()
    y = y.replace('\n','')
    if (y[:1] == "`") : # valid hier path
        f_checker.write("        checker_t(\"%s\", `CHECKER_ACTIVE, %s, %s);\n" % (x_name, y, x))
    else :
        f_checker.write("        checker_t(\"%s\", `CHECKER_INACTIVE, %s, %s);\n" % (x_name, y, x))

f_checker.write("        errors_for_wave = (errors != checker_errors_prev);\n")
f_checker.write("    end // main task body */\n")
f_checker.write("endtask // run_checkers\n")

f_vector_table.close()
f_chk_map.close()
f_checker.close()
