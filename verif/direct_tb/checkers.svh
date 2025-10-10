function void checker_t;
    // TODO: for back-annotated GLS, timing has to be taken into account,
    // so might revert to task, or disable checkers for GLS
    input string name;
    input reg active;
    input reg [31:0] dut_val;
    input reg [31:0] model_val;

    begin
        if (active == 1'b1 && dut_val !== model_val) begin
            `LOG_E($sformatf(
                "Mismatch @ %0t. Checker: \"%0s\"; DUT: 0x%8h, Model: 0x%8h",
                $time, name, dut_val, model_val)
            );
        end
    end
endfunction

function void cosim_run_checkers;
    input reg [31:0] rf_chk_act;
    int checker_errors_prev;
    begin
        checker_errors_prev = errors;
        checker_t("pc", `CHECKER_ACTIVE, `DUT_CORE.pc.wbk, cosim_pc);
        checker_t("inst", `CHECKER_ACTIVE, `DUT_CORE.inst.wbk, cosim_inst);
        for (int i = 1; i < 32; i = i + 1) begin
            checker_t(
                $sformatf("x%0d", i),
                `CHECKER_ACTIVE && rf_chk_act[i],
                `DUT_RF.rf[i],
                cosim_rf[i]
            );
        end
        //checker_t("tohost", `CHECKER_ACTIVE, `DUT_CORE.tohost, sig_chk_tohost);
        errors_for_wave = (errors != checker_errors_prev);
    end
endfunction
