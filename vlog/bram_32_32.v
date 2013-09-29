// bram modules of different types
// by liam davey (30/3/2011)

// wrapper module for 16Kb block ram with two 32 bit ports

module bram_32_32 #(
	parameter INIT_00 = 256'h0, parameter INIT_01 = 256'h0,
	parameter INIT_02 = 256'h0, parameter INIT_03 = 256'h0,
	parameter INIT_04 = 256'h0, parameter INIT_05 = 256'h0,
	parameter INIT_06 = 256'h0, parameter INIT_07 = 256'h0,
	parameter INIT_08 = 256'h0, parameter INIT_09 = 256'h0,
	parameter INIT_0A = 256'h0, parameter INIT_0B = 256'h0,
	parameter INIT_0C = 256'h0, parameter INIT_0D = 256'h0,
	parameter INIT_0E = 256'h0, parameter INIT_0F = 256'h0,
	parameter INIT_10 = 256'h0, parameter INIT_11 = 256'h0,
	parameter INIT_12 = 256'h0, parameter INIT_13 = 256'h0,
	parameter INIT_14 = 256'h0, parameter INIT_15 = 256'h0,
	parameter INIT_16 = 256'h0, parameter INIT_17 = 256'h0,
	parameter INIT_18 = 256'h0, parameter INIT_19 = 256'h0,
	parameter INIT_1A = 256'h0, parameter INIT_1B = 256'h0,
	parameter INIT_1C = 256'h0, parameter INIT_1D = 256'h0,
	parameter INIT_1E = 256'h0, parameter INIT_1F = 256'h0,
	parameter INIT_20 = 256'h0, parameter INIT_21 = 256'h0,
	parameter INIT_22 = 256'h0, parameter INIT_23 = 256'h0,
	parameter INIT_24 = 256'h0, parameter INIT_25 = 256'h0,
	parameter INIT_26 = 256'h0, parameter INIT_27 = 256'h0,
	parameter INIT_28 = 256'h0, parameter INIT_29 = 256'h0,
	parameter INIT_2A = 256'h0, parameter INIT_2B = 256'h0,
	parameter INIT_2C = 256'h0, parameter INIT_2D = 256'h0,
	parameter INIT_2E = 256'h0, parameter INIT_2F = 256'h0,
	parameter INIT_30 = 256'h0, parameter INIT_31 = 256'h0,
	parameter INIT_32 = 256'h0, parameter INIT_33 = 256'h0,
	parameter INIT_34 = 256'h0, parameter INIT_35 = 256'h0,
	parameter INIT_36 = 256'h0, parameter INIT_37 = 256'h0,
	parameter INIT_38 = 256'h0, parameter INIT_39 = 256'h0,
	parameter INIT_3A = 256'h0, parameter INIT_3B = 256'h0,
	parameter INIT_3C = 256'h0, parameter INIT_3D = 256'h0,
	parameter INIT_3E = 256'h0, parameter INIT_3F = 256'h0
) (
	input clk_a_in,
	input en_a_in,
	input [3:0] we_a_in,
	input [8:0] addr_a_in,
	input [31:0] wr_d_a_in,
	output [31:0] rd_d_a_out,
	
	input clk_b_in,
	input en_b_in,
	input [3:0] we_b_in,
	input [8:0] addr_b_in,
	input [31:0] wr_d_b_in,
	output [31:0] rd_d_b_out
);

`ifndef SIMULATION

	RAMB16BWER #(
		.DATA_WIDTH_A(36),
		.DATA_WIDTH_B(36),
		.INIT_00(INIT_00), .INIT_01(INIT_01), .INIT_02(INIT_02), .INIT_03(INIT_03),
		.INIT_04(INIT_04), .INIT_05(INIT_05), .INIT_06(INIT_06), .INIT_07(INIT_07),
		.INIT_08(INIT_08), .INIT_09(INIT_09), .INIT_0A(INIT_0A), .INIT_0B(INIT_0B),
		.INIT_0C(INIT_0C), .INIT_0D(INIT_0D), .INIT_0E(INIT_0E), .INIT_0F(INIT_0F),
		.INIT_10(INIT_10), .INIT_11(INIT_11), .INIT_12(INIT_12), .INIT_13(INIT_13),
		.INIT_14(INIT_14), .INIT_15(INIT_15), .INIT_16(INIT_16), .INIT_17(INIT_17),
		.INIT_18(INIT_18), .INIT_19(INIT_19), .INIT_1A(INIT_1A), .INIT_1B(INIT_1B),
		.INIT_1C(INIT_1C), .INIT_1D(INIT_1D), .INIT_1E(INIT_1E), .INIT_1F(INIT_1F),
		.INIT_20(INIT_20), .INIT_21(INIT_21), .INIT_22(INIT_22), .INIT_23(INIT_23),
		.INIT_24(INIT_24), .INIT_25(INIT_25), .INIT_26(INIT_26), .INIT_27(INIT_27),
		.INIT_28(INIT_28), .INIT_29(INIT_29), .INIT_2A(INIT_2A), .INIT_2B(INIT_2B),
		.INIT_2C(INIT_2C), .INIT_2D(INIT_2D), .INIT_2E(INIT_2E), .INIT_2F(INIT_2F),
		.INIT_30(INIT_30), .INIT_31(INIT_31), .INIT_32(INIT_32), .INIT_33(INIT_33),
		.INIT_34(INIT_34), .INIT_35(INIT_35), .INIT_36(INIT_36), .INIT_37(INIT_37),
		.INIT_38(INIT_38), .INIT_39(INIT_39), .INIT_3A(INIT_3A), .INIT_3B(INIT_3B),
		.INIT_3C(INIT_3C), .INIT_3D(INIT_3D), .INIT_3E(INIT_3E), .INIT_3F(INIT_3F)
	) ramb16_data (
		// port a
		.CLKA(clk_a_in),
		.RSTA(1'b0),
		.ENA(en_a_in),
		.WEA(we_a_in),
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
		.WEB(we_b_in),
		.ADDRB({addr_b_in, 5'h0}),
		.DIB(wr_d_b_in),
		.DIPB(4'h0),
		.DOB(rd_d_b_out),
		.DOPB(),
		.REGCEB(1'b0)
	);

`else

	// a fake dual port ram for simulation
	
	// 512 * 32 bits = 16Kb
	reg [31:0] ram0 [0:511];
	
	reg [31:0] rd_d_a_out_r;
	reg [31:0] rd_d_b_out_r;
	
	assign rd_d_a_out = rd_d_a_out_r;
	assign rd_d_b_out = rd_d_b_out_r;
	
	// simulate port a
	always @ (posedge clk_a_in) begin
		if (en_a_in) begin
			if(we_a_in[3])
				ram0[addr_a_in][31:24] <= wr_d_a_in[31:24];
			else
				rd_d_a_out_r[31:24] <= ram0[addr_a_in][31:24];
				
			if(we_a_in[2])
				ram0[addr_a_in][23:16] <= wr_d_a_in[23:16];
			else
				rd_d_a_out_r[23:16] <= ram0[addr_a_in][23:16];
			
			if(we_a_in[1])
				ram0[addr_a_in][15:8] <= wr_d_a_in[15:8];
			else
				rd_d_a_out_r[15:8] <= ram0[addr_a_in][15:8];
			
			if(we_a_in[0])
				ram0[addr_a_in][7:0] <= wr_d_a_in[7:0];
			else
				rd_d_a_out_r[7:0] <= ram0[addr_a_in][7:0];
		end
	end
	
	// simulate port b
	always @ (posedge clk_b_in) begin
		if (en_b_in) begin
			if(we_b_in[3])
				ram0[addr_b_in][31:24] <= wr_d_b_in[31:24];
			else
				rd_d_b_out_r[31:24] <= ram0[addr_b_in][31:24];
				
			if(we_b_in[2])
				ram0[addr_b_in][23:16] <= wr_d_b_in[23:16];
			else
				rd_d_b_out_r[23:16] <= ram0[addr_b_in][23:16];
			
			if(we_b_in[1])
				ram0[addr_b_in][15:8] <= wr_d_b_in[15:8];
			else
				rd_d_b_out_r[15:8] <= ram0[addr_b_in][15:8];
			
			if(we_b_in[0])
				ram0[addr_b_in][7:0] <= wr_d_b_in[7:0];
			else
				rd_d_b_out_r[7:0] <= ram0[addr_b_in][7:0];
		end
	end
`endif

endmodule
