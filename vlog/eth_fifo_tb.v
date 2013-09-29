`timescale 1ns / 1ps

module eth_fifo_tb;

	reg rst;
	reg rd_clk;
	reg rd_en_in;
	reg wr_clk;
	reg wr_en_in;
	reg wr_chk_in;
	reg wr_clr_in;
	reg [35:0] wr_d_in;
	wire [35:0] rd_d_out;
	wire rd_empty_out;
	wire wr_full_out;
	
	eth_fifo uut (
		.rst(rst), 
		.rd_clk(rd_clk), 
		.rd_en_in(rd_en_in), 
		.rd_d_out(rd_d_out),
		.rd_empty_out(rd_empty_out), 
		.wr_clk(wr_clk), 
		.wr_en_in(wr_en_in), 
		.wr_chk_in(wr_chk_in), 
		.wr_clr_in(wr_clr_in), 
		.wr_d_in(wr_d_in), 
		.wr_full_out(wr_full_out)
	);

	always #8 rd_clk = !rd_clk;
	always #5 wr_clk = !wr_clk;

	integer i;
	
	initial begin
		rst = 0;
		rd_clk = 0;
		wr_clk = 0;
		
		#20 rst = 1;
		#20 rst = 0;
	end

	initial begin
		wr_en_in = 0;
		wr_chk_in = 0;
		wr_clr_in = 0;
		wr_d_in = 0;

		#55;
		
		for (i = 0; i < 10; i = i + 1) begin
			#10 wr_d_in = i;
			wr_en_in = 1;
			wr_chk_in = 0;
			wr_clr_in = 0;
		end
		
		#10 wr_d_in = 99;
		wr_en_in = 1;
		wr_chk_in = 1;
		wr_clr_in = 0;
		
		for (i = 0; i < 10; i = i + 1) begin
			#10 wr_d_in = i + 20;
			wr_en_in = 1;
			wr_chk_in = 0;
			wr_clr_in = 0;
		end
		
		#10 wr_d_in = 64'd0;
		wr_en_in = 1;
		wr_chk_in = 0;
		wr_clr_in = 1;

		for (i = 0; i < 512; i = i + 1) begin
			#10 wr_d_in = i + 10;
			wr_en_in = 1;
			wr_chk_in = 0;
			wr_clr_in = 0;
		end
		
		#10 wr_d_in = 0;
		wr_en_in = 0;
		wr_chk_in = 0;
		wr_clr_in = 0;
		
		#1000 wr_d_in = 98;
		wr_en_in = 1;
		wr_chk_in = 1;
		wr_clr_in = 0;
		
		#10 wr_d_in = 0;
		wr_en_in = 0;
		wr_chk_in = 0;
		wr_clr_in = 0;
	
	end
	
	integer j;
	initial begin
		rd_en_in = 0;
		
		#8;
		
		#256;
		
		for (j = 0; j < 2000; j = j + 1) begin
			#32 rd_en_in = 1;
			#16 rd_en_in = 0;
		end
	
	end
      
endmodule

