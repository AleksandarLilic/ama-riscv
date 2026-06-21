sv unit_test \
--include "$REPO_ROOT/src" \
--include "$REPO_ROOT/verif/direct_tb" \
"$REPO_ROOT/verif/unit_test/ama_riscv_simd_tb.sv" \
"$REPO_ROOT/src/common/csa.sv" \
"$REPO_ROOT/src/common/csa_tree_4.sv" \
"$REPO_ROOT/src/common/csa_tree_8.sv" \
"$REPO_ROOT/src/common/cmp_s_lt.sv" \
"$REPO_ROOT/src/common/add.sv" \
"$REPO_ROOT/src/common/sat_s_add_sub.sv" \
"$REPO_ROOT/src/common/sat_u_add_sub.sv" \
"$REPO_ROOT/src/ama_riscv_simd.sv" \
"$REPO_ROOT/src/ama_riscv_simd_ppgen.sv" \
"$REPO_ROOT/src/ama_riscv_simd_lane_wrapup.sv" \
