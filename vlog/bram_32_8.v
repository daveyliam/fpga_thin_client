`timescale 1ns / 1ps

// wrapper module for 16Kb block ram with a 32 bit and an 8 bit port
// by liam davey (7/4/2011)

module bram_32_8 (
	input clk_a_in,
	input en_a_in,
	input [3:0] we_a_in,
	input [8:0] addr_a_in,
	input [31:0] wr_d_a_in,
	output [31:0] rd_d_a_out,
	
	input clk_b_in,
	input en_b_in,
	input we_b_in,
	input [10:0] addr_b_in,
	input [7:0] wr_d_b_in,
	output [7:0] rd_d_b_out
);

`ifndef SIMULATION

	wire [31:0] rd_d_b_32_0;
	
	RAMB16BWER #(
		.DATA_WIDTH_A(36),
		.DATA_WIDTH_B(9)
	) bram_32_8_0 (
		// port a
		.CLKA(clk_a_in),
		.RSTA(1'b0),
		.ENA(en_a_in),
		.WEA(we_a_in[3:0]),
		.ADDRA({addr_a_in, 5'h0}),
		.DIA(wr_d_a_in),
		.DIPA(4'h0),
		.DOA(rd_d_a_out),
		.DOPA(),
		.REGCEA(1'b0),

		// port b
		.CLKB(clk_b_in),
		.RSTB(1'b0),
		.ENB(en_b_in),
		.WEB({3'b0, we_b_in}),
		.ADDRB({addr_b_in, 3'h0}),
		.DIB({24'h0, wr_d_b_in}),
		.DIPB(4'h0),
		.DOB(rd_d_b_32_0),
		.DOPB(),
		.REGCEB(1'b0)
	);
	
	assign rd_d_b_out = rd_d_b_32_0[7:0];

`else

	// a fake dual port ram for simulation
	
	// 512 * 32 bits = 16Kb
	reg [31:0] ram0 [0:511];
	
	reg [31:0] rd_d_a_out_r;
	reg [7:0] rd_d_b_out_r;
	
	assign rd_d_a_out = rd_d_a_out_r;
	assign rd_d_b_out = rd_d_b_out_r;

	integer i;
	
	// port a, 32 bit interface
	always @ (posedge clk_a_in) begin
		if (en_a_in) begin
			for (i = 0; i < 4; i = i + 1) begin
				if(we_a_in[i])
					ram0[addr_a_in][((8 * (i + 1)) - 1):(8 * i)] <= wr_d_a_in[((8 * (i + 1)) - 1):(8 * i)];
				else
					rd_d_a_out_r[((8 * (i + 1)) - 1):(8 * i)] <= ram0[addr_a_in][((8 * (i + 1)) - 1):(8 * i)];
			end
		end
	end
	
	// port b, 8 bit interface
	always @ (posedge clk_b_in) begin
		if (en_b_in) begin
			if (we_b_in)
				case (addr_b_in[1:0])
					2'b11: ram0[addr_b_in[10:2]][7:0] <= wr_d_b_in;
					2'b10: ram0[addr_b_in[10:2]][15:8] <= wr_d_b_in;
					2'b01: ram0[addr_b_in[10:2]][23:16] <= wr_d_b_in;
					2'b00: ram0[addr_b_in[10:2]][31:24] <= wr_d_b_in;
				endcase
			else
				case (addr_b_in[1:0])
					2'b11: rd_d_b_out_r[7:0] <= ram0[addr_b_in[10:2]][7:0];
					2'b10: rd_d_b_out_r[7:0] <= ram0[addr_b_in[10:2]][15:8];
					2'b01: rd_d_b_out_r[7:0] <= ram0[addr_b_in[10:2]][23:16];
					2'b00: rd_d_b_out_r[7:0] <= ram0[addr_b_in[10:2]][31:24];
				endcase
		end
	end
	
`endif

endmodule
