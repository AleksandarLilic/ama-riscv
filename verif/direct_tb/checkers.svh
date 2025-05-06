function void checker_t;
    // TODO: for back-annotated GLS, timing has to be taken into account,
    // so might revert to task, or disable checkers for GLS
    input string name;
    input reg active;
    input reg [31:0] dut_signal;
    input reg [31:0] model_signal;

    begin
        if (active == 1'b1 && dut_signal !== model_signal) begin
            $display("ERROR @ %0t. Checker: \"%0s\"; DUT: 0x%0h, Model: 0x%0h",
                $time, name, dut_signal, model_signal);
            errors = errors + 1;
        end
    end
endfunction

function void cosim_run_checkers;
    input reg [31:0] rf_chk_act;
    int checker_errors_prev;
    begin
        checker_errors_prev = errors;
        checker_t("pc", `CHECKER_ACTIVE, `DUT_CORE.pc.p.wbk, cosim_pc);
        for (int i = 1; i < 32; i = i + 1) begin
            checker_t($sformatf("x%0d", i),
                      `CHECKER_ACTIVE && rf_chk_act[i],
                      `DUT_RF.rf[i],
                      cosim_rf[i]
            );
        end
        //checker_t("tohost", `CHECKER_ACTIVE, `DUT_CORE.tohost, sig_chk_tohost);
        errors_for_wave = (errors != checker_errors_prev);
    end
endfunction

// user friendly register names for wave
wire [31:0] reg_x1_ra = `DUT_RF.rf[1]; // return address
wire [31:0] reg_x2_sp = `DUT_RF.rf[2]; // stack pointer
wire [31:0] reg_x3_gp = `DUT_RF.rf[3]; // global pointer
wire [31:0] reg_x4_tp = `DUT_RF.rf[4]; // thread pointer
wire [31:0] reg_x5_t0 = `DUT_RF.rf[5]; // temporary/alternate link register
wire [31:0] reg_x6_t1 = `DUT_RF.rf[6]; // temporary
wire [31:0] reg_x7_t2 = `DUT_RF.rf[7]; // temporary
wire [31:0] reg_x8_s0 = `DUT_RF.rf[8]; // saved register/frame pointer
wire [31:0] reg_x9_s1 = `DUT_RF.rf[9]; // saved register
wire [31:0] reg_x10_a0 = `DUT_RF.rf[10]; // function argument/return value
wire [31:0] reg_x11_a1 = `DUT_RF.rf[11]; // function argument/return value
wire [31:0] reg_x12_a2 = `DUT_RF.rf[12]; // function argument
wire [31:0] reg_x13_a3 = `DUT_RF.rf[13]; // function argument
wire [31:0] reg_x14_a4 = `DUT_RF.rf[14]; // function argument
wire [31:0] reg_x15_a5 = `DUT_RF.rf[15]; // function argument
wire [31:0] reg_x16_a6 = `DUT_RF.rf[16]; // function argument
wire [31:0] reg_x17_a7 = `DUT_RF.rf[17]; // function argument
wire [31:0] reg_x18_s2 = `DUT_RF.rf[18]; // saved register
wire [31:0] reg_x19_s3 = `DUT_RF.rf[19]; // saved register
wire [31:0] reg_x20_s4 = `DUT_RF.rf[20]; // saved register
wire [31:0] reg_x21_s5 = `DUT_RF.rf[21]; // saved register
wire [31:0] reg_x22_s6 = `DUT_RF.rf[22]; // saved register
wire [31:0] reg_x23_s7 = `DUT_RF.rf[23]; // saved register
wire [31:0] reg_x24_s8 = `DUT_RF.rf[24]; // saved register
wire [31:0] reg_x25_s9 = `DUT_RF.rf[25]; // saved register
wire [31:0] reg_x26_s10 = `DUT_RF.rf[26]; // saved register
wire [31:0] reg_x27_s11 = `DUT_RF.rf[27]; // saved register
wire [31:0] reg_x28_t3 = `DUT_RF.rf[28]; // temporary
wire [31:0] reg_x29_t4 = `DUT_RF.rf[29]; // temporary
wire [31:0] reg_x30_t5 = `DUT_RF.rf[30]; // temporary
wire [31:0] reg_x31_t6 = `DUT_RF.rf[31]; // temporary
