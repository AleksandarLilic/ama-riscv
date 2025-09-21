
`include "ama_riscv_defines.svh"

module ama_riscv_imem #(
    parameter unsigned D = 2 // latency >= 1
)(
    input  logic clk,
    input  logic rst,
    rv_if.RX     req,
    rv_if.TX     rsp
);

logic [31:0] mem [0:MEM_SIZE_W-1];

generate
    if (D == 1) begin: g_lat1
        // always ready; CPU can issue a new address every cycle
        assign req.ready = 1'b1;

        // data available on the next clk edge
        always_ff @(posedge clk) begin
            if (rst) begin
                rsp.valid <= 1'b0;
            end else begin
                rsp.valid <= req.valid;
                if (req.valid) rsp.data <= mem[req.data];
            end
        end
    end

    else begin: g_latN
        logic busy;
        logic [$clog2(D):0] cnt;
        logic [CORE_DATA_BUS-1:0] data_r;
        logic [CORE_DATA_BUS-1:0] data;

        // handshake toward the CPU
        assign req.ready = ~busy; // accept only when idle
        assign rsp.data = data;

        always_ff @(posedge clk) begin
            if (rst) begin
                busy <= 1'b0;
                cnt <= 'h0;
                rsp.valid <= 1'b0;
                data_r <= 'h0;
            end else begin
                if (req.valid && req.ready) begin // new request
                    busy <= 1'b1;
                    cnt <= D-2;
                    rsp.valid <= 1'b0;
                    data_r <= mem[req.data]; // initiate the read
                end else if (busy) begin // request in flight
                    if (cnt != 0) begin
                        cnt <= cnt - 1;
                    end else begin // end if latency window, output the data
                        data <= data_r;
                        rsp.valid <= 1'b1;
                        busy <= 1'b0;
                    end
                end
                // consumer took the data
                if (rsp.valid && rsp.ready) rsp.valid <= 1'b0;
            end
        end
    end
endgenerate



endmodule
