`timescale 1ns / 1ps

// ethernet top level module
// connects the eth_mcb_if and eth_mac modules
// by liam davey (13/4/11)
//

module eth_mac (
	input clk,
	input rst,
	input gtx_clk,
	input gtx_rst,
	input rx_clk,
	input rx_rst,
	
	input data_rd_en_in,
	output [8:0] data_rd_d_out,
	output data_rd_empty_out,
	
	input ctl_rd_en_in,
	output [17:0] ctl_rd_d_out,
	output ctl_rd_empty_out,
	
	input data_wr_en_in,
	input [8:0] data_wr_d_in,
	output data_wr_full_out,
	
	input ctl_wr_en_in,
	input [17:0] ctl_wr_d_in,
	output ctl_wr_full_out,
	
	input [7:0] eth_rx_d_in,
	input eth_rx_err_in,
	input eth_rx_dv_in,
	
	output [7:0] eth_tx_d_out,
	output eth_tx_en_out,
	output eth_tx_err_out
);

	wire rx_data_wr_en, rx_data_wr_full;
	wire [8:0] rx_data_wr_d;
	wire rx_ctl_wr_en, rx_ctl_wr_full;
	wire [17:0] rx_ctl_wr_d;
	

	// ethernet receiver
	
	eth_mac_rx eth_mac_rx_0 (
		.clk(rx_clk),
		.rst(rx_rst),
		
		.eth_rx_d_in(eth_rx_d_in),
		.eth_rx_dv_in(eth_rx_dv_in),
		.eth_rx_err_in(eth_rx_err_in),
		
		.data_wr_en_out(rx_data_wr_en),
		.data_wr_d_out(rx_data_wr_d),
		.data_wr_full_in(rx_data_wr_full),
		
		.ctl_wr_en_out(rx_ctl_wr_en),
		.ctl_wr_d_out(rx_ctl_wr_d),
		.ctl_wr_full_in(rx_ctl_wr_full)
	);
	
	afifo_9_9_8k fifo_rx_data (
		.rst(rst),
		
		.wr_clk(rx_clk),
		.wr_en(rx_data_wr_en),
		.din(rx_data_wr_d),
		.full(rx_data_wr_full),
		
		.rd_clk(clk),
		.rd_en(data_rd_en_in),
		.dout(data_rd_d_out),
		.empty(data_rd_empty_out)
	);
	
	afifo_18_18_1k fifo_rx_ctl (
		.rst(rst),
		
		.wr_clk(rx_clk),
		.wr_en(rx_ctl_wr_en),
		.din(rx_ctl_wr_d),
		.full(rx_ctl_wr_full),
		
		.rd_clk(clk),
		.rd_en(ctl_rd_en_in),
		.dout(ctl_rd_d_out),
		.empty(ctl_rd_empty_out)
	);
	
	
	// ethernet transmitter
	
	wire tx_data_rd_en, tx_data_rd_empty;
	wire [8:0] tx_data_rd_d;
	wire tx_ctl_rd_en, tx_ctl_rd_empty;
	wire [17:0] tx_ctl_rd_d;
	
	eth_mac_tx eth_mac_tx_0 (
		.clk(gtx_clk),
		.rst(gtx_rst),
		
		.eth_tx_d_out(eth_tx_d_out),
		.eth_tx_en_out(eth_tx_en_out),
		.eth_tx_err_out(eth_tx_err_out),
		
		.data_rd_en_out(tx_data_rd_en),
		.data_rd_d_in(tx_data_rd_d),
		.data_rd_empty_in(tx_data_rd_empty),
		
		.ctl_rd_en_out(tx_ctl_rd_en),
		.ctl_rd_d_in(tx_ctl_rd_d),
		.ctl_rd_empty_in(tx_ctl_rd_empty)
	);
	
	afifo_9_9_8k fifo_tx_data (
		.rst(rst),
		//.clk(gtx_clk),
		
		.wr_clk(clk),
		.wr_en(data_wr_en_in),
		.din(data_wr_d_in),
		.full(data_wr_full_out),
		
		.rd_clk(gtx_clk),
		.rd_en(tx_data_rd_en),
		.dout(tx_data_rd_d),
		.empty(tx_data_rd_empty)
	);
	
	afifo_18_18_1k fifo_tx_ctl (
		.rst(rst),
		
		.wr_clk(clk),
		.wr_en(ctl_wr_en_in),
		.din(ctl_wr_d_in),
		.full(ctl_wr_full_out),
		
		.rd_clk(gtx_clk),
		.rd_en(tx_ctl_rd_en),
		.dout(tx_ctl_rd_d),
		.empty(tx_ctl_rd_empty)
	);
	
endmodule
	
