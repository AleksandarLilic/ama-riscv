sv unit_test \
--include "$REPO_ROOT/src" \
--include "$REPO_ROOT/verif/direct_tb" \
"$REPO_ROOT/verif/unit_test/ama_riscv_simd_tb.sv" \
"$REPO_ROOT/src/csa.sv" \
"$REPO_ROOT/src/csa_tree_4.sv" \
"$REPO_ROOT/src/csa_tree_8.sv" \
"$REPO_ROOT/src/ama_riscv_simd.sv" \
