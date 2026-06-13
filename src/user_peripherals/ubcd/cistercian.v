module dual_cistercian_decoder (
	input wire A1, B1, C1, D1, A2, B2, C2, D2, LT1, LT2, BI, AL,
	output wire U1, V1, W1, X1, Y1, U2, V2, W2, X2, Y2
);

	wire [3:0] value1 = {D1, C1, B1, A1};
	wire [3:0] value2 = {D2, C2, B2, A2};

	reg [4:0] data1;
	reg [4:0] data2;
	assign U1 = ((data1[4] | ~LT1) & BI) ^ ~AL;
	assign V1 = ((data1[3] | ~LT1) & BI) ^ ~AL;
	assign W1 = ((data1[2] | ~LT1) & BI) ^ ~AL;
	assign X1 = ((data1[1] | ~LT1) & BI) ^ ~AL;
	assign Y1 = ((data1[0] | ~LT1) & BI) ^ ~AL;
	assign U2 = ((data2[4] | ~LT2) & BI) ^ ~AL;
	assign V2 = ((data2[3] | ~LT2) & BI) ^ ~AL;
	assign W2 = ((data2[2] | ~LT2) & BI) ^ ~AL;
	assign X2 = ((data2[1] | ~LT2) & BI) ^ ~AL;
	assign Y2 = ((data2[0] | ~LT2) & BI) ^ ~AL;

	always_comb begin
		case (value1)
			0: data1 = 5'b00000;
			1: data1 = 5'b10000;
			2: data1 = 5'b01000;
			3: data1 = 5'b00100;
			4: data1 = 5'b00010;
			5: data1 = 5'b10010;
			6: data1 = 5'b00001;
			7: data1 = 5'b10001;
			8: data1 = 5'b01001;
			9: data1 = 5'b11001;
			10: data1 = 5'b11110;
			11: data1 = 5'b10011;
			12: data1 = 5'b11101;
			13: data1 = 5'b11011;
			14: data1 = 5'b10111;
			15: data1 = 5'b01111;
		endcase
	end

	always_comb begin
		case (value2)
			0: data2 = 5'b00000;
			1: data2 = 5'b10000;
			2: data2 = 5'b01000;
			3: data2 = 5'b00100;
			4: data2 = 5'b00010;
			5: data2 = 5'b10010;
			6: data2 = 5'b00001;
			7: data2 = 5'b10001;
			8: data2 = 5'b01001;
			9: data2 = 5'b11001;
			10: data2 = 5'b11110;
			11: data2 = 5'b10011;
			12: data2 = 5'b11101;
			13: data2 = 5'b11011;
			14: data2 = 5'b10111;
			15: data2 = 5'b01111;
		endcase
	end

endmodule
