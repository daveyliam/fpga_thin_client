`timescale 1ns / 1ps

// ethernet mac and mcb_if testbench
// by liam davey (13/4/11)
//

`include "bram_32_32.v"
`include "bram_64_64.v"
`include "eth_mac.v"
`include "eth_mcb_if.v"

module eth_tb();

	reg clk;
	reg rst;
	
	reg eth_rx_clk_in;
	reg [7:0] eth_rx_d_in;
	reg eth_rx_err_in;
	reg eth_rx_dv_in;
	
	wire eth_gtx_clk_out;
	wire [7:0] eth_tx_d_out;
	wire eth_tx_en_out;
	wire eth_tx_err_out;
	
	wire rx_clk;
	wire rx_en;
	wire [8:0] rx_addr;
	wire [63:0] rx_d;
	
	wire tx_clk;
	wire tx_en;
	wire [8:0] tx_addr;
	reg [63:0] tx_d;
	
	wire [1:0] rx_rdy;
	reg [1:0] rx_done;

	wire [1:0] tx_done;
	reg [1:0] tx_rdy;
	
	wire mcb_cmd_en_out;
	wire [2:0] mcb_cmd_instr_out;
	wire [5:0] mcb_cmd_bl_out;
	wire [29:0] mcb_cmd_byte_addr_out;
	reg mcb_cmd_empty_in;
	reg mcb_cmd_full_in;
	
	wire mcb_wr_en_out;
	wire [7:0] mcb_wr_mask_out;
	wire [63:0] mcb_wr_data_out;
	reg mcb_wr_full_in;
	reg mcb_wr_empty_in;
	reg mcb_wr_error_in;
	reg mcb_wr_underrun_in;
	reg [6:0] mcb_wr_count_in;
	
	wire mcb_rd_en_out;
	reg [63:0] mcb_rd_data_in;
	reg mcb_rd_full_in;
	reg mcb_rd_empty_in;
	reg mcb_rd_error_in;
	reg mcb_rd_overflow_in;
	reg [6:0] mcb_rd_count_in;

	eth_mac uut_eth_mac #(
		.mac(48'h1234567890ab),
		.type(16'habcd)
	) (
		.clk(clk),
		.rst(rst),
		
		.eth_rx_clk_in(eth_rx_clk_in),
		.eth_rx_d_in(eth_rx_d_in),
		.eth_rx_err_in(eth_rx_err_in),
		.eth_rx_dv_in(eth_rx_dv_in),
		.eth_gtx_clk_out(eth_gtx_clk_out),
		.eth_tx_d_out(eth_tx_d_out),
		.eth_tx_en_out(eth_tx_en_out),
		.eth_tx_err_out(eth_rx_err_out),
		
		.rx_clk_out(rx_clk),
		.rx_en_out(rx_en),
		.rx_addr_out(rx_addr),
		.rx_d_out(rx_d),
		
		.tx_clk_out(tx_clk),
		.tx_en_out(tx_en),
		.tx_addr_out(tx_addr),
		.tx_d_in(tx_d),
		
		.rx_rdy_out(rx_rdy),
		.rx_done_in(rx_done),

		.tx_done_out(tx_done),
		.tx_rdy_in(tx_rdy)
	);

	module uut_eth_mcb_if (
		.clk(clk),
		.rst(rst),

		.rx_en_out(rx_en),
		.rx_addr_out(rx_addr),
		.rx_d_in(rx_d),
		
		.tx_en_out(tx_en),
		.tx_addr_out(tx_addr),
		.tx_d_out(tx_d),
		
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
		.mcb_wr_count(mcb_wr_count),
		
		.mcb_rd_en_out(mcb_rd_en_out),
		.mcb_rd_data_in(mcb_rd_data_in),
		.mcb_rd_full_in(mcb_rd_full_in),
		.mcb_rd_empty_in(mcb_rd_empty_in),
		.mcb_rd_error_in(mcb_rd_error_in),
		.mcb_rd_overflow_in(mcb_rd_overflow_in),
		.mcb_rd_count(mcb_rd_count),
		
		.rx_done_out(rx_done),
		.rx_rdy_in(rx_rdy),
		.tx_rdy_out(tx_rdy),
		.tx_done_in(tx_done)
	);
	
	
