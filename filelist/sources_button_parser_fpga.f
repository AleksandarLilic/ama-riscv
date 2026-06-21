sv unit_test \
--include "$REPO_ROOT/src" \
"$REPO_ROOT/verif/unit_test/button_parser_fpga_tb.sv" \
"$REPO_ROOT/src/fpga/button_parser_fpga.sv" \
"$REPO_ROOT/src/common/button_parser.sv" \
"$REPO_ROOT/src/common/synchronizer.sv" \
"$REPO_ROOT/src/common/debouncer.sv" \
"$REPO_ROOT/src/common/edge_detector.sv" \
