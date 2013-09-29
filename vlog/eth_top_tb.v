`timescale 1ns / 1ps

// ethernet top level module test bench
// by liam davey (13/4/11)
//

`define SIMULATION 1

`include "bram_32_32.v"
`include "bram_64_64.v"
`include "eth_mac.v"
`include "eth_mcb_if.v"
`include "eth_top.v"

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

	eth_top uut_eth_top (
		.clk(clk),
		.rst(rst),
		
		.eth_rx_clk_in(eth_rx_clk_in),
		.eth_rx_d_in(eth_rx_d_in),
		.eth_rx_err_in(eth_rx_err_in),
		.eth_rx_dv_in(eth_rx_dv_in),
		.eth_gtx_clk_out(eth_gtx_clk_out),
		.eth_tx_d_out(eth_tx_d_out),
		.eth_tx_en_out(eth_tx_en_out),
		.eth_tx_err_out(eth_tx_err_out),
		
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
	
	always #5 clk = ~clk;
	always #6 eth_rx_clk_in = ~eth_rx_clk_in;
	
	reg [31:0] crc_n_r;
	reg [31:0] crc_n;
	integer i;
	
	always @ (posedge eth_rx_clk_in) begin
		crc_n <= ~uut_eth_top.eth_mac_0.rx_crc;
	end
	
	integer j;
	reg [7:0] frame [85:0]; 
	
	initial $readmemh("../sim/eth_frame.dump", frame);
	
	initial begin
		$dumpfile("../sim/eth_tb.vcd");
		$dumpvars;
		
		clk = 1;
		rst = 0;
		eth_rx_clk_in = 1;
		eth_rx_d_in = 0;
		eth_rx_err_in = 0;
		eth_rx_dv_in = 0;
		mcb_cmd_empty_in = 1;
		mcb_cmd_full_in = 0;	
		mcb_wr_full_in = 0;
		mcb_wr_empty_in = 1;
		mcb_wr_error_in = 0;
		mcb_wr_underrun_in = 0;
		mcb_wr_count_in = 0;
		mcb_rd_data_in = 0;
		mcb_rd_full_in = 0;
		mcb_rd_empty_in = 1;
		mcb_rd_error_in = 0;
		mcb_rd_overflow_in = 0;
		mcb_rd_count_in = 0;
	
		#20 rst = 1;
		#20 rst = 0;
		
		#50;
		
		for(j = 0; j < 86; j = j + 1) begin
			#12 eth_rx_dv_in = 1;
			eth_rx_d_in = frame[j];
		end
		
		#12 eth_rx_dv_in = 0;
		
		#10000 $finish;
	end
endmodule
