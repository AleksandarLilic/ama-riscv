sv standalone_tb \
--include "$REPO_ROOT/src" \
--include "$REPO_ROOT/verif/direct_tb" \
"$REPO_ROOT/verif/direct_tb/standalone_tb/uart_tb.sv"\
"$REPO_ROOT/src/uart.sv" \
"$REPO_ROOT/src/uart_tx.sv" \
"$REPO_ROOT/src/uart_rx.sv" \
