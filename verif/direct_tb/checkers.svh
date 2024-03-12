task checker_t;
    input string name;
    input reg active;
    input reg [31:0] dut_signal;
    input reg [31:0] model_signal;
    
    begin
        if (active == 1'b1 && dut_signal !== model_signal) begin
            $display("ERROR @ %0t. Checker: \"%0s\"; DUT: %0d, Model: %0d ", 
                $time, name, dut_signal, model_signal);
            errors = errors + 1;
        end
    end
endtask

task run_checkers;
    int checker_errors_prev;
    begin
        checker_errors_prev = errors;
        checker_t("pc", `CHECKER_ACTIVE, `DUT_CORE.pc_wb, cosim_pc);
        checker_t("x1", `CHECKER_ACTIVE, `DUT_RF.x1_ra, cosim_rf[1]);
        checker_t("x2", `CHECKER_ACTIVE, `DUT_RF.x2_sp, cosim_rf[2]);
        checker_t("x3", `CHECKER_ACTIVE, `DUT_RF.x3_gp, cosim_rf[3]);
        checker_t("x4", `CHECKER_ACTIVE, `DUT_RF.x4_tp, cosim_rf[4]);
        checker_t("x5", `CHECKER_ACTIVE, `DUT_RF.x5_t0, cosim_rf[5]);
        checker_t("x6", `CHECKER_ACTIVE, `DUT_RF.x6_t1, cosim_rf[6]);
        checker_t("x7", `CHECKER_ACTIVE, `DUT_RF.x7_t2, cosim_rf[7]);
        checker_t("x8", `CHECKER_ACTIVE, `DUT_RF.x8_s0, cosim_rf[8]);
        checker_t("x9", `CHECKER_ACTIVE, `DUT_RF.x9_s1, cosim_rf[9]);
        checker_t("x10", `CHECKER_ACTIVE, `DUT_RF.x10_a0, cosim_rf[10]);
        checker_t("x11", `CHECKER_ACTIVE, `DUT_RF.x11_a1, cosim_rf[11]);
        checker_t("x12", `CHECKER_ACTIVE, `DUT_RF.x12_a2, cosim_rf[12]);
        checker_t("x13", `CHECKER_ACTIVE, `DUT_RF.x13_a3, cosim_rf[13]);
        checker_t("x14", `CHECKER_ACTIVE, `DUT_RF.x14_a4, cosim_rf[14]);
        checker_t("x15", `CHECKER_ACTIVE, `DUT_RF.x15_a5, cosim_rf[15]);
        checker_t("x16", `CHECKER_ACTIVE, `DUT_RF.x16_a6, cosim_rf[16]);
        checker_t("x17", `CHECKER_ACTIVE, `DUT_RF.x17_a7, cosim_rf[17]);
        checker_t("x18", `CHECKER_ACTIVE, `DUT_RF.x18_s2, cosim_rf[18]);
        checker_t("x19", `CHECKER_ACTIVE, `DUT_RF.x19_s3, cosim_rf[19]);
        checker_t("x20", `CHECKER_ACTIVE, `DUT_RF.x20_s4, cosim_rf[20]);
        checker_t("x21", `CHECKER_ACTIVE, `DUT_RF.x21_s5, cosim_rf[21]);
        checker_t("x22", `CHECKER_ACTIVE, `DUT_RF.x22_s6, cosim_rf[22]);
        checker_t("x23", `CHECKER_ACTIVE, `DUT_RF.x23_s7, cosim_rf[23]);
        checker_t("x24", `CHECKER_ACTIVE, `DUT_RF.x24_s8, cosim_rf[24]);
        checker_t("x25", `CHECKER_ACTIVE, `DUT_RF.x25_s9, cosim_rf[25]);
        checker_t("x26", `CHECKER_ACTIVE, `DUT_RF.x26_s10, cosim_rf[26]);
        checker_t("x27", `CHECKER_ACTIVE, `DUT_RF.x27_s11, cosim_rf[27]);
        checker_t("x28", `CHECKER_ACTIVE, `DUT_RF.x28_t3, cosim_rf[28]);
        checker_t("x29", `CHECKER_ACTIVE, `DUT_RF.x29_t4, cosim_rf[29]);
        checker_t("x30", `CHECKER_ACTIVE, `DUT_RF.x30_t5, cosim_rf[30]);
        checker_t("x31", `CHECKER_ACTIVE, `DUT_RF.x31_t6, cosim_rf[31]);
        //checker_t("tohost", `CHECKER_ACTIVE, `DUT_CORE.tohost, sig_chk_tohost);
        errors_for_wave = (errors != checker_errors_prev);
    end // main task body
endtask // run_checkers
