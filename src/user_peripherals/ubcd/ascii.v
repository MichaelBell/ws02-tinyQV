module ascii_decoder (
	input wire D0, D1, D2, D3, D4, D5, D6,
	input wire X6, X7, X9, LC, FS, ABI, AL,
	output wire Qa, Qb, Qc, Qd, Qe, Qf, Qg, LTR
);

	wire [6:0] value = {D6, D5, D4, D3, D2, D1, D0};

	reg [6:0] data;
	assign Qa = (data[0] & ABI) ^ ~AL;
	assign Qb = (data[1] & ABI) ^ ~AL;
	assign Qc = (data[2] & ABI) ^ ~AL;
	assign Qd = (data[3] & ABI) ^ ~AL;
	assign Qe = (data[4] & ABI) ^ ~AL;
	assign Qf = (data[5] & ABI) ^ ~AL;
	assign Qg = (data[6] & ABI) ^ ~AL;
	assign LTR = ~(value[6] & ((value[4:0] >= 5'h01) && (value[4:0] <= 5'h1A)));

	always_comb begin
		case (value)
			7'h21: data = 7'h0A;
			7'h22: data = 7'h22;
			7'h23: data = 7'h36;
			7'h24: data = (FS ? 7'h12 : 7'h2D);
			7'h25: data = 7'h24;
			7'h26: data = 7'h78;
			7'h27: data = 7'h42;
			7'h28: data = (FS ? 7'h58 : 7'h39);
			7'h29: data = (FS ? 7'h4C : 7'h0F);
			7'h2A: data = 7'h63;
			7'h2B: data = 7'h46;
			7'h2C: data = 7'h0C;
			7'h2D: data = 7'h40;
			7'h2E: data = (FS ? 7'h10 : 7'h08);
			7'h2F: data = 7'h52;
			7'h30: data = 7'h3F;
			7'h31: data = 7'h06;
			7'h32: data = 7'h5B;
			7'h33: data = 7'h4F;
			7'h34: data = 7'h66;
			7'h35: data = 7'h6D;
			7'h36: data = (X6 ? 7'h7D : 7'h7C);
			7'h37: data = (X7 ? 7'h27 : 7'h07);
			7'h38: data = 7'h7F;
			7'h39: data = (X9 ? 7'h6F : 7'h67);
			7'h3A: data = 7'h09;
			7'h3B: data = 7'h0D;
			7'h3C: data = (FS ? 7'h61 : 7'h46);
			7'h3D: data = (FS ? 7'h41 : 7'h48);
			7'h3E: data = (FS ? 7'h43 : 7'h70);
			7'h3F: data = 7'h53;
			7'h40: data = 7'h7B;
			7'h41: data = 7'h77;
			7'h42: data = 7'h7C;
			7'h43: data = 7'h39;
			7'h44: data = 7'h5E;
			7'h45: data = 7'h79;
			7'h46: data = 7'h71;
			7'h47: data = 7'h3D;
			7'h48: data = 7'h76;
			7'h49: data = (FS ? 7'h05 : 7'h06);
			7'h4A: data = 7'h1E;
			7'h4B: data = 7'h75;
			7'h4C: data = 7'h38;
			7'h4D: data = 7'h2B;
			7'h4E: data = 7'h37;
			7'h4F: data = (FS ? 7'h6B : 7'h3F);
			7'h50: data = 7'h73;
			7'h51: data = 7'h67;
			7'h52: data = 7'h31;
			7'h53: data = (FS ? 7'h2D : 7'h6D);
			7'h54: data = 7'h07;
			7'h55: data = 7'h3E;
			7'h56: data = 7'h6A;
			7'h57: data = 7'h7E;
			7'h58: data = 7'h49;
			7'h59: data = 7'h6E;
			7'h5A: data = (FS ? 7'h1B : 7'h5B);
			7'h5B: data = (FS ? 7'h59 : 7'h39);
			7'h5C: data = 7'h64;
			7'h5D: data = (FS ? 7'h4D : 7'h0F);
			7'h5E: data = 7'h23;
			7'h5F: data = 7'h08;
			7'h60: data = 7'h60;
			7'h61: data = (LC ? (FS ? 7'h44 : 7'h5F) : 7'h77);
			7'h62: data = 7'h7C;
			7'h63: data = (LC ? 7'h58 : 7'h39);
			7'h64: data = 7'h5E;
			7'h65: data = (LC ? (FS ? 7'h18 : 7'h7B) : 7'h79);
			7'h66: data = (LC ? (FS ? 7'h33 : 7'h71) : 7'h71);
			7'h67: data = (LC ? (FS ? 7'h2F : 7'h6F) : 7'h3D);
			7'h68: data = (LC ? 7'h74 : 7'h76);
			7'h69: data = (LC ? 7'h05 : (FS ? 7'h05 : 7'h06));
			7'h6A: data = (LC ? 7'h0E : 7'h1E);
			7'h6B: data = 7'h75;
			7'h6C: data = (LC ? (FS ? 7'h3C : 7'h06) : 7'h38);
			7'h6D: data = (LC ? 7'h55 : 7'h2B);
			7'h6E: data = (LC ? 7'h54 : 7'h37);
			7'h6F: data = (LC ? 7'h5C : (FS ? 7'h6B : 7'h3F));
			7'h70: data = 7'h73;
			7'h71: data = 7'h67;
			7'h72: data = (LC ? 7'h50 : 7'h31);
			7'h73: data = (FS ? 7'h2D : 7'h6D);
			7'h74: data = (LC ? (FS ? 7'h70 : 7'h78) : 7'h07);
			7'h75: data = (LC ? 7'h1C : 7'h3E);
			7'h76: data = (LC ? 7'h1D : 7'h6A);
			7'h77: data = 7'h7E;
			7'h78: data = (LC ? 7'h48 : 7'h49);
			7'h79: data = 7'h6E;
			7'h7A: data = (FS ? 7'h1B : 7'h5B);
			7'h7B: data = (FS ? 7'h69 : 7'h46);
			7'h7C: data = 7'h30;
			7'h7D: data = (FS ? 7'h4B : 7'h70);
			7'h7E: data = 7'h01;
			default: data = 7'h00;
		endcase
	end

endmodule
