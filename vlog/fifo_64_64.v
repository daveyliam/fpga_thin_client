`timescale 1ns / 1ps

// asynchronous fifo with two 64 bit ports
// the fifo 'entries' are block rams rather than registers
// by liam davey (7/4/2011)

module fifo_64_64 (
	input rst,

	input rd_clk_in,
	input rd_en_in,
	output rd_empty_out,
	
	input bram_rd_en_in,
	input [8:0] bram_rd_addr_in,
	output [63:0] bram_rd_d_out,
	
	input wr_clk_in,
	input wr_en_in,
	output wr_full_out,
	
	input bram_wr_en_in,
	input [8:0] bram_wr_addr_in,
	input [63:0] bram_wr_d_in
);

	reg [1:0] head, tail;

	always @ (posedge rd_clk_in) begin
		if (rd_en_in) begin
			case (tail)
				2'b00: tail <= 2'b01;
				2'b01: tail <= 2'b11;
				2'b11: tail <= 2'b10;
				2'b10: tail <= 2'b00;
			endcase
		end
	end

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
