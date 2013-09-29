`timescale 1ns / 1ps

// create a 8KB block ram with a 64 bit port and an 8 bit port from four
// 2KB block rams (with 32 and 8 bit ports)
// by liam davey (7/4/2011)

module bram_64_8 (
	input clk_a_in,
	input en_a_in,
	input [7:0] we_a_in,
	input [9:0] addr_a_in,
	input [63:0] wr_d_a_in,
	output [63:0] rd_d_a_out,
	
	input clk_b_in,
	input en_b_in,
	input we_b_in,
	input [12:0] addr_b_in,
	input [7:0] wr_d_b_in,
	output [7:0] rd_d_b_out
);

	// port 'a' glue (64 bit from four 16 bit bram ports)
	wire [3:0] en_a = {	en_a_in && addr_a_in[9] && addr_a_in[1],
								en_a_in && addr_a_in[9] && !addr_a_in[1],
								en_a_in && !addr_a_in[9] && addr_a_in[1],
								en_a_in && !addr_a_in[9] && !addr_a_in[1]};
	wire [10:0] addr_a = {addr_a_in[8:2], addr_a_in[0]};
	wire [31:0] rd_d_a [3:0];
	
	reg [1:0] en_a_r;
	always @ (posedge clk_a_in)
		en_a_r <= en_a;
	assign rd_d_a_out = 	(en_a_r[3]) ? {rd_d_a[3], rd_d_a[2]} : 
								(en_a_r[1]) ? {rd_d_a[1], rd_d_a[0]} : 8'h00;
	

	// port 'b' glue (8 bit port from four 8 bit bram ports)
	wire [3:0] en_b = {	en_b_in &&  addr_b_in[12] &&  addr_b_in[2],
								en_b_in &&  addr_b_in[12] && !addr_b_in[2],
								en_b_in && !addr_b_in[12] &&  addr_b_in[2],
								en_b_in && !addr_b_in[12] && !addr_b_in[2]};
	wire [11:0] addr_b = {addr_b_in[11:3], addr_b_in[1:0]}
	wire [7:0] rd_d_b [3:0];
	
	reg [3:0] en_b_r;
	always @ (posedge clk_b_in)
		en_b_r <= en_b;
	assign rd_d_b_out = 	(en_b_r[3]) ? rd_d_b[3] : 
								(en_b_r[2]) ? rd_d_b[2] : 
								(en_b_r[1]) ? rd_d_b[1] : 
								(en_b_r[0]) ? rd_d_b[0] : 8'h00;
	
	
	bram_32_8 bram_64_8_3 (
		.clk_a_in(clk_a_in),
		.en_a_in(en_a[3]),
		.we_a_in(we_a[3]),
		.addr_a_in(addr_a),
		.wr_d_a_in(wr_d_a[3]),
		.rd_d_a_out(rd_d_a[3]),
		
		.clk_b_in(clk_b_in),
		.en_b_in(en_b[3]),
		.we_b_in(we_b[3]),
		.addr_b_in(addr_b),
		.wr_d_b_in(wr_d_b[3]),
		.rd_d_b_out(rd_d_b[3])
	);
	
	bram_32_8 bram_64_8_2 (
		.clk_a_in(clk_a_in),
		.en_a_in(en_a[2]),
		.we_a_in(we_a[2]),
		.addr_a_in(addr_a),
		.wr_d_a_in(wr_d_a[2]),
		.rd_d_a_out(rd_d_a[2]),
		
		.clk_b_in(clk_b_in),
		.en_b_in(en_b[2]),
		.we_b_in(we_b[2]),
		.addr_b_in(addr_b),
		.wr_d_b_in(wr_d_b[2]),
		.rd_d_b_out(rd_d_b[2])
	);
	
	bram_32_8 bram_64_8_1 (
		.clk_a_in(clk_a_in),
		.en_a_in(en_a_[1]),
		.we_a_in(we_a_[1]),
		.addr_a_in(addr_a),
		.wr_d_a_in(wr_d_a_[1]),
		.rd_d_a_out(rd_d_a_[1]),
		
		.clk_b_in(clk_b_in),
		.en_b_in(en_b_[1]),
		.we_b_in(we_b_[1]),
		.addr_b_in(addr_b),
		.wr_d_b_in(wr_d_b_[1]),
		.rd_d_b_out(rd_d_b_[1])
	);
	
	bram_32_8 bram_64_8_0 (
		.clk_a_in(clk_a_in),
		.en_a_in(en_a_[0]),
		.we_a_in(we_a_[0]),
		.addr_a_in(addr_a),
		.wr_d_a_in(wr_d_a_[0]),
		.rd_d_a_out(rd_d_a_[0]),
		
		.clk_b_in(clk_b_in),
		.en_b_in(en_b_[0]),
		.we_b_in(we_b_[0]),
		.addr_b_in(addr_b),
		.wr_d_b_in(wr_d_b_[0]),
		.rd_d_b_out(rd_d_b_[0])
	);
	
endmodule
