sv work \
--include "$REPO_ROOT/src" \
--include "$REPO_ROOT/verif/direct_tb" \
"$REPO_ROOT/src/ama_riscv_defines.svh" \
"$REPO_ROOT/verif/direct_tb/ama_riscv_tb_defines.svh" \
"$REPO_ROOT/verif/direct_tb/ama_riscv_core_top_tb.sv" \
"$REPO_ROOT/src/ama_riscv_alu.sv" \
"$REPO_ROOT/src/ama_riscv_core_top.sv" \
"$REPO_ROOT/src/ama_riscv_core.sv" \
"$REPO_ROOT/src/ama_riscv_decoder.sv" \
"$REPO_ROOT/src/ama_riscv_fe_ctrl.sv" \
"$REPO_ROOT/src/ama_riscv_imm_gen.sv" \
"$REPO_ROOT/src/ama_riscv_operand_forwarding.sv" \
"$REPO_ROOT/src/ama_riscv_reg_file.sv" \
"$REPO_ROOT/src/ama_riscv_icache.sv" \
"$REPO_ROOT/src/ama_riscv_dcache.sv" \
"$REPO_ROOT/src/ama_riscv_mem.sv" \
