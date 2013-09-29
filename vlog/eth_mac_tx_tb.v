`timescale 1ns / 1ps

module eth_mac_tx_tb;
	reg clk;
	reg rst;
	reg wr_en_in;
	reg wr_clr_in;
	reg wr_chk_in;
	reg [35:0] wr_d_in;
	wire [7:0] eth_tx_d_out;
	wire eth_tx_en_out;
	wire eth_tx_err_out;
	wire wr_full_out;
	
	wire rd_en, rd_empty;
	wire [35:0] rd_d;
	
	eth_fifo tx_fifo (
		.rst(rst),
		
		.rd_clk(clk),
		.rd_en_in(rd_en),
		.rd_d_out(rd_d),
		.rd_empty_out(rd_empty),
		
		.wr_clk(clk),
		.wr_en_in(wr_en_in),
		.wr_clr_in(wr_clr_in),
		.wr_chk_in(wr_chk_in),
		.wr_d_in(wr_d_in),
		.wr_full_out(wr_full_out)
	);
	
	eth_mac_tx uut (
		.clk(clk), 
		.rst(rst), 
		.eth_tx_d_out(eth_tx_d_out), 
		.eth_tx_en_out(eth_tx_en_out), 
		.eth_tx_err_out(eth_tx_err_out),
		.rd_en_out(rd_en),
		.rd_d_in(rd_d), 
		.rd_empty_in(rd_empty)
	);

	always #5 clk = ~clk;
	
	always @ (posedge clk) begin
		if (rst) begin
			wr_d_in <= 0;
			wr_en_in <= 0;
			wr_chk_in <= 0;
			wr_clr_in <=0;
		
		end else begin
			if (!wr_full_out) begin
				wr_d_in[31:0] <= wr_d_in[31:0] + 32'd1;
				wr_d_in[32] <= (wr_d_in[4:0] == 5'h1f);
				wr_chk_in   <= (wr_d_in[4:0] == 5'h1f);
				wr_en_in <= 1;
			end else begin
				wr_en_in <= 0;
				wr_chk_in <= 0;
			end
			wr_clr_in <= 0;
		end
	end

	initial begin
		clk = 0;
		rst = 0;
		
		#25 rst = 1;
		#20 rst = 0;
		
	end
      
endmodule

