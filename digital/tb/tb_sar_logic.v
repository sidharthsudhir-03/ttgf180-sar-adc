// tb_sar_logic.v: ideal-comparator testbench. Run with: make rtl-sim
`timescale 1ns/1ps
module tb_sar_logic;
    localparam N = 8;
    reg clk = 0, rst_n = 0, start = 0;
    reg  [N-1:0] vin;                 // "analog" input as an ideal code
    wire sample, done;
    wire [N-1:0] dac, result;
    wire cmp = (vin >= dac);          // ideal comparator

    sar_logic #(.N(N)) dut (.clk(clk), .rst_n(rst_n), .start(start), .cmp(cmp),
                            .sample(sample), .done(done), .dac(dac), .result(result));

    always #10 clk = ~clk;            // 50 MHz

    integer i, errors = 0;
    initial begin
        $dumpfile("tb_sar_logic.vcd");
        $dumpvars(0, tb_sar_logic);
        repeat (2) @(posedge clk);
        rst_n = 1;
        for (i = 0; i < 64; i = i + 1) begin
            vin = (i == 0) ? 0 : (i == 1) ? {N{1'b1}} : $random;
            @(negedge clk) start = 1;
            @(negedge clk) start = 0;
            @(posedge done); #1;
            if (result !== vin) begin
                errors = errors + 1;
                $display("FAIL vin=%0d result=%0d", vin, result);
            end
        end
        if (errors == 0) $display("PASS: 64 conversions");
        else             $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
