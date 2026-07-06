
module pwm #(
    parameter WIDTH = 8,
    parameter INVERT = 0
    ) (
    input wire clk,
    input wire reset,
    input wire strobe,
    output reg out,
    input wire [WIDTH-1:0] level,
    input wire [WIDTH-1:0] wrap
    );

    reg [WIDTH-1:0] count;
    wire pwm_on = count < level;

    always @(posedge clk) begin
        if(reset)
            count <= '0;
        else if(strobe) begin
            if (count >= wrap) count <= '0;
            else count <= count + 1'b1;
        end
    end

    always @(posedge clk)
        out <= reset ? 1'b0: INVERT == 1'b0 ? pwm_on : ! pwm_on;

endmodule
