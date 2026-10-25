// sar_logic.v: N-bit SAR controller (binary search, one bit per clock)
//
// Handshake: pulse `start` -> `sample` high for 1 cycle (close bootstrapped switch)
//            -> N conversion cycles -> `done` high for 1 cycle with `result` valid.
// `dac` drives the CDAC switch array (MSB first). `cmp` = 1 means Vin >= Vdac.
module sar_logic #(
    parameter N = 8
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         cmp,
    output reg          sample,
    output reg          done,
    output reg  [N-1:0] dac,
    output reg  [N-1:0] result
);
    localparam [1:0] IDLE = 2'd0, SAMP = 2'd1, CONV = 2'd2;

    reg [1:0]   state;
    reg [N-1:0] mask;   // one-hot: bit currently under test

    wire [N-1:0] kept = cmp ? dac : (dac & ~mask);  // resolve current bit

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state  <= IDLE;
            sample <= 1'b0;
            done   <= 1'b0;
            dac    <= {N{1'b0}};
            result <= {N{1'b0}};
            mask   <= {N{1'b0}};
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: if (start) begin
                    sample <= 1'b1;
                    state  <= SAMP;
                end
                SAMP: begin
                    sample <= 1'b0;
                    mask   <= {1'b1, {(N-1){1'b0}}};
                    dac    <= {1'b1, {(N-1){1'b0}}};
                    state  <= CONV;
                end
                CONV: if (mask[0]) begin
                    dac    <= kept;
                    result <= kept;
                    done   <= 1'b1;
                    state  <= IDLE;
                end else begin
                    dac  <= kept | (mask >> 1);
                    mask <= mask >> 1;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
