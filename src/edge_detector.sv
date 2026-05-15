module edge_detector #(
    parameter WIDTH = 1
)(
    input  logic             clk,
    input  logic             rst,
    input  logic [WIDTH-1:0] signal_in,
    output logic [WIDTH-1:0] edge_detect_pulse
);

//-----------------------------------------------------------------------------
// Signals
logic [WIDTH-1:0] catch;
logic [WIDTH-1:0] catch_q1;

//-----------------------------------------------------------------------------
// Edge detector
always @(posedge clk) begin
    if (rst) begin
        catch    <= {WIDTH{1'b0}};
        catch_q1 <= {WIDTH{1'b0}};
    end
    else begin
        catch    <= signal_in;
        catch_q1 <= catch;
    end
end

// Input was low and it's high now
assign edge_detect_pulse = (catch & ~catch_q1);

endmodule
