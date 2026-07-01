// Super simple 2bpp encoder that only outputs pairs of symbols that give imbalance of 0.
module simple_tmds_encode (
	input  wire       clk,
	input  wire       rst_n,

	input  wire [1:0] c,
	input  wire [1:0] d,
	input  wire       den,

	output reg  [9:0] q
);

reg odd;

always @(posedge clk) begin
    if (~rst_n) odd <= 0;
    else begin
        if (den) begin
            odd <= ~odd;
            if (odd) begin
                case (d) // Symbols all have balance -4
                    2'b00: q <= 10'h103;
                    2'b01: q <= 10'h130;
                    2'b10: q <= 10'h230;
                    2'b11: q <= 10'h203;
                endcase
            end else begin
                case (d) // Symbols all have balance +4
                    2'b00: q <= 10'h1fc;
                    2'b01: q <= 10'h1cf;
                    2'b10: q <= 10'h2cf;
                    2'b11: q <= 10'h2fc;
                endcase
            end                
        end else begin
            case (c)
                2'b00: q <= 10'b1101010100;
                2'b01: q <= 10'b0010101011;
                2'b10: q <= 10'b0101010100;
                2'b11: q <= 10'b1010101011;
            endcase
        end
    end
end

endmodule
