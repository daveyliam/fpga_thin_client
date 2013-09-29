`timescale 1ns / 1ps

// create a 4KB block ram with two 64 bit ports from two 32 bit port
// block rams
// by liam davey (7/4/2011)

module bram_64_64 (
	input clk_a_in,
	input en_a_in,
	input [7:0] we_a_in,
	input [8:0] addr_a_in,
	input [63:0] wr_d_a_in,
	output [63:0] rd_d_a_out,
	
	input clk_b_in,
	input en_b_in,
	input [7:0] we_b_in,
	input [8:0] addr_b_in,
	input [63:0] wr_d_b_in,
	output [63:0] rd_d_b_out
);

	bram_32_32 bram_64_64_1 (
		.clk_a_in(clk_a_in),
		.en_a_in(en_a_in),
		.we_a_in(we_a_in[7:4]),
		.addr_a_in(addr_a_in),
		.wr_d_a_in(wr_d_a_in[63:32]),
		.rd_d_a_out(rd_d_a_out[63:32]),
		
		.clk_b_in(clk_b_in),
		.en_b_in(en_b_in),
		.we_b_in(we_b_in[7:4]),
		.addr_b_in(addr_b_in),
		.wr_d_b_in(wr_d_b_in[63:32]),
		.rd_d_b_out(rd_d_b_out[63:32])
	);
	
	bram_32_32 bram_64_64_0 (
		.clk_a_in(clk_a_in),
		.en_a_in(en_a_in),
		.we_a_in(we_a_in[3:0]),
		.addr_a_in(addr_a_in),
		.wr_d_a_in(wr_d_a_in[31:0]),
		.rd_d_a_out(rd_d_a_out[31:0]),
		
		.clk_b_in(clk_b_in),
		.en_b_in(en_b_in),
		.we_b_in(we_b_in[3:0]),
		.addr_b_in(addr_b_in),
		.wr_d_b_in(wr_d_b_in[31:0]),
		.rd_d_b_out(rd_d_b_out[31:0])
	);
	
endmodule
