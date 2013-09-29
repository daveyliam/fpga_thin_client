`timescale 1ns / 1ps

`define SIMULATION 1

module eth_mac_rx_tb;

	reg clk;
	reg rst;
	reg [7:0] eth_rx_d_in;
	reg eth_rx_err_in;
	reg eth_rx_dv_in;

	wire data_wr_en;
	reg data_wr_full;
	wire [8:0] data_wr_d;
	wire ctl_wr_en;
	reg ctl_wr_full;
	wire [17:0] ctl_wr_d;

	eth_mac_rx uut (
		.clk(clk), 
		.rst(rst), 
		.eth_rx_d_in(eth_rx_d_in), 
		.eth_rx_err_in(eth_rx_err_in), 
		.eth_rx_dv_in(eth_rx_dv_in),
		
		.data_wr_en_out(data_wr_en),
		.data_wr_d_out(data_wr_d),
		.data_wr_full_in(data_wr_full),
		
		.ctl_wr_en_out(ctl_wr_en),
		.ctl_wr_d_out(ctl_wr_d),
		.ctl_wr_full_in(ctl_wr_full)
	);
	
	always #5 clk = ~clk;
	
	reg [7:0] count;
	always @ (posedge clk) begin
		if (count < 8'd72) begin
			eth_rx_dv_in <= 1;
			eth_rx_d_in <= frame[count];
			count <= count + 1'd1;
		end else
			eth_rx_dv_in <= 0;
	end

	integer j;
	reg [7:0] frame [71:0]; 
	
	initial $readmemh("sim/eth_frame.dump", frame);

	initial begin
		clk = 0;
		rst = 0;
		eth_rx_d_in = 0;
		eth_rx_err_in = 0;
		eth_rx_dv_in = 0;
		data_wr_full = 0;
		ctl_wr_full = 0;
		count = 8'd100;
		
		#20 rst = 1;
		#20 rst = 0;
		
		#45;
		
		count = 0;
		
		#10000 $finish;
	end
      
endmodule

