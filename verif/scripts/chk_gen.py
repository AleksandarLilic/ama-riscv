f_vector_table = open("C:/dev/ama-riscv-sim/SW/out/build/ama-riscv-sim/src/vector_table.txt", "r")
f_vector = open("C:/dev/ama-riscv/verif/direct_tb/vector_import.sv", "w")

for chk in f_vector_table:
    chk = chk.replace('\n','')
    f_vector.write("\n")
    f_vector.write("int fd_%s;\n" % chk)
    f_vector.write("int sample_cnt_%s = 0;\n" % chk)
    f_vector.write("reg [31:0] sig_%s;\n" % chk)
    f_vector.write("initial begin\n")
    f_vector.write("    forever begin\n")
    f_vector.write("        @ev_load_vector; // wait for test to start\n");
    f_vector.write("        fd_%s = $fopen($sformatf(\"%%0s/test_%%0s/%s.txt\", stim_path, current_test), \"r\");\n" % (chk, chk))
    f_vector.write("        if (fd_%s) begin\n" % chk)
    f_vector.write("            `LOG((\"From test '%%0s' file '%s' opened: %%0d\", current_test, fd_%s));\n" % (chk, chk))
    f_vector.write("        end\n")
    f_vector.write("        else begin\n")
    f_vector.write("            $display(\"File '%s' could not be opened: %%0d. Exiting simulation.\", fd_%s);\n"  % (chk, chk))
    f_vector.write("            $finish;\n")
    f_vector.write("        end\n")
    f_vector.write("        while (! $feof(fd_%s)) begin\n" % chk)
    f_vector.write("            $fscanf(fd_%s, \"%%d\\n\", sig_%s);\n" % (chk, chk))
    f_vector.write("            sample_cnt_%s = sample_cnt_%s + 1; \n" % (chk, chk))
    f_vector.write("            @(posedge clk or posedge sim_done); \n")
    f_vector.write("        end\n")
    f_vector.write("        $fclose(fd_%s);\n" % chk)
    f_vector.write("        `LOG((\"Vector read '%s' done. Samples read: %%0d.\", sample_cnt_%s));\n"  % (chk, chk))
    f_vector.write("        sample_cnt_%s = 0; // reset counter for next test\n" % chk)
    f_vector.write("    end\n")
    f_vector.write("end\n")

f_vector_table.close()
f_vector.close()

str_map_inactive = "dummy" # this is used as a string for ignored checker in chk_map.txt
f_vector_table = open("C:/dev/ama-riscv-sim/SW/out/build/ama-riscv-sim/src/vector_table.txt", "r")
f_chk_map = open("C:/dev/ama-riscv/verif/scripts/chk_map.txt", "r")
f_checker = open("C:/dev/ama-riscv/verif/direct_tb/checkers_task.sv", "w")
f_checker.write("task run_checkers;\n")
f_checker.write("    int checker_errors_prev;\n")
f_checker.write("    int %s = 0;\n" % str_map_inactive)
f_checker.write("    begin\n")
f_checker.write("        checker_errors_prev = errors;\n")

for chk in f_vector_table:
    chk = chk.replace('\n','')
    chk_name = chk.replace('chk_','')
    str_from_map = f_chk_map.readline()
    str_from_map = str_from_map.replace('\n','')
    if (str_from_map != str_map_inactive and str_from_map != "") : # valid hier path
        f_checker.write("        checker_t(\"%s\", `CHECKER_ACTIVE, %s, sig_%s);\n" % (chk_name, str_from_map, chk))
    else :
        f_checker.write("        checker_t(\"%s\", `CHECKER_INACTIVE, %s, sig_%s);\n" % (chk_name, str_map_inactive, chk))

f_checker.write("        errors_for_wave = (errors != checker_errors_prev);\n")
f_checker.write("    end // main task body\n")
f_checker.write("endtask // run_checkers\n")

f_vector_table.close()
f_chk_map.close()
f_checker.close()
