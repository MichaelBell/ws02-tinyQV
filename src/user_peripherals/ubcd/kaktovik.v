module kaktovik_decoder (
	input wire A, B, C, D, E, RBI, VBI, LT, BI, AL,
	output wire Qa, Qb, Qc, Qd, Qe, Qf, Qg, Qh, RBO, V
);

	wire [4:0] value = {E, D, C, B, A};

	reg [7:0] data;
	assign Qa = (((data[0] & (VBI | ~V)) | ~LT) & BI) ^ ~AL;
	assign Qb = (((data[1] & (VBI | ~V)) | ~LT) & BI) ^ ~AL;
	assign Qc = (((data[2] & (VBI | ~V)) | ~LT) & BI) ^ ~AL;
	assign Qd = (((data[3] & (VBI | ~V)) | ~LT) & BI) ^ ~AL;
	assign Qe = (((data[4] & (VBI | ~V)) | ~LT) & BI) ^ ~AL;
	assign Qf = (((data[5] & (VBI | ~V)) | ~LT) & BI) ^ ~AL;
	assign Qg = (((data[6] & (VBI | ~V)) | ~LT) & BI) ^ ~AL;
	assign Qh = (((data[7] & (VBI | ~V)) | ~LT) & BI) ^ ~AL;
	assign RBO = ((value != 0) | RBI | ~LT) & BI;
	assign V = (value >= 20);

	always_comb begin
		case (value)
			0: data = (RBI ? 8'b00000100 : 8'b00000000);
			1: data = 8'b00000001;
			2: data = 8'b00000111;
			3: data = 8'b00001111;
			4: data = 8'b00011111;
			5: data = 8'b00100000;
			6: data = 8'b00100001;
			7: data = 8'b00100111;
			8: data = 8'b00101111;
			9: data = 8'b00111111;
			10: data = 8'b01100000;
			11: data = 8'b01100001;
			12: data = 8'b01100111;
			13: data = 8'b01101111;
			14: data = 8'b01111111;
			15: data = 8'b11100000;
			16: data = 8'b11100001;
			17: data = 8'b11100111;
			18: data = 8'b11101111;
			19: data = 8'b11111111;
			20: data = 8'b11000000;
			21: data = 8'b11000001;
			22: data = 8'b11000111;
			23: data = 8'b11001111;
			24: data = 8'b11011111;
			25: data = 8'b10100000;
			26: data = 8'b10100001;
			27: data = 8'b10100111;
			28: data = 8'b10101111;
			29: data = 8'b10111111;
			30: data = 8'b11111111;
			31: data = 8'b00000000;
		endcase
	end

endmodule
