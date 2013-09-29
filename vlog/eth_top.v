`timescale 1ns / 1ps

// ethernet top level module
// connects the eth_mcb_if and eth_mac modules
// by liam davey (13/4/11)
//

module eth_top (
	// input 125MHz clock
	input clk,
	input rst,
	
	input eth_rx_clk_in,
	input [7:0] eth_rx_d_in,
	input eth_rx_err_in,
	input eth_rx_dv_in,
	
	output eth_gtx_clk_out,
	output [7:0] eth_tx_d_out,
	output eth_tx_en_out,
	output eth_tx_err_out,
	
	output mcb_cmd_en_out,
	output [2:0] mcb_cmd_instr_out,
	output [5:0] mcb_cmd_bl_out,
	output [29:0] mcb_cmd_byte_addr_out,
	input mcb_cmd_empty_in,
	input mcb_cmd_full_in,
	
	output mcb_wr_en_out,
	output [7:0] mcb_wr_mask_out,
	output [63:0] mcb_wr_data_out,
	input mcb_wr_full_in,
	input mcb_wr_empty_in,
	input mcb_wr_error_in,
	input mcb_wr_underrun_in,
	input [6:0] mcb_wr_count_in,
	
	output mcb_rd_en_out,
	input [63:0] mcb_rd_data_in,
	input mcb_rd_full_in,
	input mcb_rd_empty_in,
	input mcb_rd_error_in,
	input mcb_rd_overflow_in,
	input [6:0] mcb_rd_count_in
);
	
	// attach rx_clk (125MHz) to global clock network
	wire rx_clk;
	`ifndef SIMULATION
	IBUFG eth_rx_clk_ibufg (
		.I(eth_rx_clk_in),
		.O(rx_clk)
	);
	`else
	assign rx_clk = eth_rx_clk_in;
	`endif

	// gtx_clk_out is the same as the 125MHz input clock
	assign eth_gtx_clk_out = clk;
	
	// buffer the 'rx_rst' signal through 2 flip flops
	// each to avoid metastability issues
	reg [1:0] rx_rst_r;
	always @ (posedge rx_clk)
		rx_rst_r <= (rst) ? 2'b00 : {rst, rx_rst_r[1]};
	wire rx_rst = rx_rst[0];
	

	// ethernet receiver
	eth_mac_rx eth_mac_rx_0 (
		.clk(rx_clk),
		.rst(rx_rst),
		
		.eth_rx_d_in(eth_rx_d_in),
		.eth_rx_err_in(eth_rx_err_in),
		.eth_rx_dv_in(eth_rx_dv_in),
		
		.wr_en_out(mac_wr_en),
		.wr_d_out(mac_wr_d),
		.wr_full_in(mac_full)
	);
	
	// receive fifo
	// dual 9 bit ports, 2048 entries
	fifo_9x2048 rx_fifo (
		.clk(clk),
		.rst(rst),
		
		.rd_en(mcb_rd_en),
		.dout(mcb_rd_d),
		.empty(mcb_rd_empty),
		
		.wr_en(mac_wr_en),
		.din(mac_wr_d),
		.full(mac_wr_full)
	);
	
	wire tx_start;
	
	// ethernet transmitter
	eth_mac_tx eth_mac_tx_0 (
		.clk(clk),
		.rst(rst),
		
		.start_in(tx_start),
		
		.eth_tx_d_out(eth_tx_d_out),
		.eth_tx_en_out(eth_tx_en_out),
		.eth_tx_err_out(eth_rx_err_out),
		
		.rd_en_out(mac_rd_en),
		.rd_d_in(mac_rd_d),
		.rd_empty_in(mac_rd_empty)
	);
	
	// transmit fifo
	// dual 9 bit ports, 2048 entries
	fifo_9x2048 tx_fifo (
		.clk(clk),
		.rst(rst),
		
		.rd_en(mac_rd_en),
		.dout(mac_rd_d),
		.empty(mac_rd_empty),
		
		.wr_en(mcb_wr_en),
		.din(mcb_wr_d),
		.full(mcb_wr_full)
	);

	eth_mcb_if eth_mcb_if_0 (
		.clk(clk),
		.rst(rst),

		.rd_en_out(mcb_rd_en),
		.rd_empty_in(mcb_rd_empty),
		.rd_addr_out(mcb_rd_addr),
		.rd_d_in(mcb_rd_d),
		
		.wr_start(tx_start),
		.wr_en_out(mcb_wr_en),
		.wr_d_out(mcb_wr_d),
		.wr_full_in(mcb_wr_full),
		
		.mcb_cmd_en_out(mcb_cmd_en_out),
		.mcb_cmd_instr_out(mcb_cmd_instr_out),
		.mcb_cmd_bl_out(mcb_cmd_bl_out),
		.mcb_cmd_byte_addr_out(mcb_cmd_byte_addr_out),
		.mcb_cmd_empty_in(mcb_cmd_empty_in),
		.mcb_cmd_full_in(mcb_cmd_full_in),
		
		.mcb_wr_en_out(mcb_wr_en_out),
		.mcb_wr_mask_out(mcb_wr_mask_out),
		.mcb_wr_data_out(mcb_wr_data_out),
		.mcb_wr_full_in(mcb_wr_full_in),
		.mcb_wr_empty_in(mcb_wr_empty_in),
		.mcb_wr_error_in(mcb_wr_error_in),
		.mcb_wr_underrun_in(mcb_wr_underrun_in),
		.mcb_wr_count_in(mcb_wr_count_in),
		
		.mcb_rd_en_out(mcb_rd_en_out),
		.mcb_rd_data_in(mcb_rd_data_in),
		.mcb_rd_full_in(mcb_rd_full_in),
		.mcb_rd_empty_in(mcb_rd_empty_in),
		.mcb_rd_error_in(mcb_rd_error_in),
		.mcb_rd_overflow_in(mcb_rd_overflow_in),
		.mcb_rd_count_in(mcb_rd_count_in)
	);
	
endmodule
	
