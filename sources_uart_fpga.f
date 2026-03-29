sv unit_test \
--include "$REPO_ROOT/src" \
--include "$REPO_ROOT/verif/direct_tb" \
"$REPO_ROOT/verif/unit_test/uart_fpga_tb.sv"\
"$REPO_ROOT/src/uart_fpga.sv" \
"$REPO_ROOT/src/uart.sv" \
"$REPO_ROOT/src/uart_tx.sv" \
"$REPO_ROOT/src/uart_rx.sv" \
