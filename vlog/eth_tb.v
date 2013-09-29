`timescale 1ns / 1ps

`define SIMULATION 1

module eth_tb;
	reg clk;
	reg rst;
	reg gtx_clk;
	reg gtx_rst;
	reg rx_clk;
	reg rx_rst;

	reg [7:0] eth_rx_d;
	reg eth_rx_err;
	reg eth_rx_dv;
	wire [7:0] eth_tx_d;
	wire eth_tx_en;
	wire eth_tx_err;
	
	assign mcb_clk = clk;
	assign mcb_rst = rst;
	
	reg [4:0] btn;
	
	localparam MAC = 48'h0010a47bea80;
	localparam TYPE = 16'h0800;
	
	reg c3_p0_cmd_empty;
	reg c3_p0_cmd_full;
	reg c3_p0_wr_full;
	reg c3_p0_wr_empty;
	reg c3_p0_wr_error;
	reg c3_p0_wr_underrun;
	reg [6:0] c3_p0_wr_count;
	reg c3_p0_rd_full;
	reg c3_p0_rd_empty;
	reg c3_p0_rd_error;
	reg c3_p0_rd_overflow;
	reg [6:0] c3_p0_rd_count;
	reg [63:0]c3_p0_rd_data;
	
	wire c3_p0_cmd_en;
	wire [2:0] c3_p0_cmd_instr;
	wire [5:0] c3_p0_cmd_bl;
	wire [29:0] c3_p0_cmd_byte_addr;
	wire c3_p0_wr_en;
	wire [7:0] c3_p0_wr_mask;
	wire [63:0] c3_p0_wr_data;
	wire c3_p0_rd_en;
	
	wire eth_data_rd_en, eth_data_rd_empty;
	wire [63:0] eth_data_rd_d;
	wire eth_ctl_rd_en, eth_ctl_rd_empty;
	wire [15:0] eth_ctl_rd_d;
	
	reg eth_mode_100;
	
	// ethernet receiver mac
	
	eth_mac_rx eth_mac_rx_0 (
		.clk(rx_clk),
		.rst(rx_rst),
		.rd_clk(mcb_clk),
		.rd_rst(mcb_rst),
		
		.eth_mode_100_in(eth_mode_100),
		
		.eth_rx_d_in(eth_rx_d),
		.eth_rx_dv_in(eth_rx_dv),
		.eth_rx_err_in(eth_rx_err),
		
		.data_rd_en_in(eth_data_rd_en),
		.data_rd_d_out(eth_data_rd_d),
		.data_rd_empty_out(eth_data_rd_empty),
		
		.ctl_rd_en_in(eth_ctl_rd_en),
		.ctl_rd_d_out(eth_ctl_rd_d),
		.ctl_rd_empty_out(eth_ctl_rd_empty)
	);
	
	// ethernet frame decoder
	
	wire ack_wr_en, ack_wr_full;
	wire [63:0] ack_wr_d;
	
	eth_decode #(
		.MAC(MAC),
		.TYPE(TYPE)
	) eth_decode_0 (
		.clk(mcb_clk),
		.rst(mcb_rst),
		
		.dbuf_toggle_out(),
		
		.data_rd_en_out(eth_data_rd_en),
		.data_rd_d_in(eth_data_rd_d),
		.data_rd_empty_in(eth_data_rd_empty),
			
		.ctl_rd_en_out(eth_ctl_rd_en),
		.ctl_rd_d_in(eth_ctl_rd_d),
		.ctl_rd_empty_in(eth_ctl_rd_empty),
		
		.ack_wr_en_out(ack_wr_en),
		.ack_wr_d_out(ack_wr_d),
		.ack_wr_full_in(ack_wr_full),
		
		.mcb_cmd_en_out(c3_p0_cmd_en),
		.mcb_cmd_instr_out(c3_p0_cmd_instr),
		.mcb_cmd_bl_out(c3_p0_cmd_bl),
		.mcb_cmd_byte_addr_out(c3_p0_cmd_byte_addr),
		.mcb_cmd_empty_in(c3_p0_cmd_empty),
		.mcb_cmd_full_in(c3_p0_cmd_full),
		
		.mcb_wr_en_out(c3_p0_wr_en),
		.mcb_wr_mask_out(c3_p0_wr_mask),
		.mcb_wr_data_out(c3_p0_wr_data),
		.mcb_wr_full_in(c3_p0_wr_full),
		.mcb_wr_empty_in(c3_p0_wr_empty),
		.mcb_wr_error_in(c3_p0_wr_error),
		.mcb_wr_underrun_in(c3_p0_wr_underrun),
		.mcb_wr_count_in(c3_p0_wr_count),
		
		.mcb_rd_en_out(c3_p0_rd_en),
		.mcb_rd_data_in(c3_p0_rd_data),
		.mcb_rd_full_in(c3_p0_rd_full),
		.mcb_rd_empty_in(c3_p0_rd_empty),
		.mcb_rd_error_in(c3_p0_rd_error),
		.mcb_rd_overflow_in(c3_p0_rd_overflow),
		.mcb_rd_count_in(c3_p0_rd_count)
	);
	
	// sync fifo between ethernet encoder and decoder
	// for acknowledgement message transfer
	
	wire ack_rd_en, ack_rd_empty;
	wire [71:0] ack_rd_d_72;
	wire [63:0] ack_rd_d = ack_rd_d_72[63:0];
	

	sfifo_72_72_2k ack_fifo (
		.clk(mcb_clk),
		.rst(mcb_rst),
		
		.wr_en(ack_wr_en),
		.din({8'h0, ack_wr_d}),
		.full(ack_wr_full),
		
		.rd_en(ack_rd_en),
		.dout(ack_rd_d_72),
		.empty(ack_rd_empty)
	);
	
	// ps2 module
	wire ps2_wr_en, ps2_wr_full;
	wire [63:0] ps2_wr_d;

	ps2_if ps2_if_0 (
		.clk(mcb_clk),
		.rst(mcb_rst),
		
		.btn(btn),
		
		.wr_en_out(ps2_wr_en),
		.wr_d_out(ps2_wr_d),
		.wr_full_in(ps2_wr_full)
	);
	
	// sync fifo between ps2 module and the ethernet frame
	// encoding module
	
	wire ps2_rd_en, ps2_rd_empty;
	wire [71:0] ps2_rd_d_72;
	wire [63:0] ps2_rd_d = ps2_rd_d_72[63:0];
	
	sfifo_72_72_2k ps2_fifo (
		.clk(mcb_clk),
		.rst(mcb_rst),
		.din({8'h0, ps2_wr_d}),
		.wr_en(ps2_wr_en),
		.rd_en(ps2_rd_en),
		.dout(ps2_rd_d_72),
		.full(ps2_wr_full),
		.empty(ps2_rd_empty)
	);
	
	wire eth_data_wr_en, eth_data_wr_full;
	wire [63:0] eth_data_wr_d;
	wire eth_ctl_wr_en, eth_ctl_wr_full;
	wire [15:0] eth_ctl_wr_d;
	
	// ethernet frame encoder
	
	eth_encode #(
		.MAC(MAC),
		.TYPE(TYPE)
	) eth_encode_0 (
		.clk(mcb_clk),
		.rst(mcb_rst),
		
		.ack_rd_en_out(ack_rd_en),
		.ack_rd_d_in(ack_rd_d),
		.ack_rd_empty_in(ack_rd_empty),
		
		.ps2_rd_en_out(ps2_rd_en),
		.ps2_rd_d_in(ps2_rd_d),
		.ps2_rd_empty_in(ps2_rd_empty),

		.data_wr_en_out(eth_data_wr_en),
		.data_wr_d_out(eth_data_wr_d),
		.data_wr_full_in(eth_data_wr_full),
			
		.ctl_wr_en_out(eth_ctl_wr_en),
		.ctl_wr_d_out(eth_ctl_wr_d),
		.ctl_wr_full_in(eth_ctl_wr_full)
	);
	
	// ethernet transmitter mac
	
	eth_mac_tx eth_mac_tx_0 (
		.clk(gtx_clk),
		.rst(gtx_rst),
		.wr_clk(mcb_clk),
		.wr_rst(mcb_rst),
		
		.eth_mode_100_in(eth_mode_100),
		
		.eth_tx_d_out(eth_tx_d),
		.eth_tx_en_out(eth_tx_en),
		.eth_tx_err_out(eth_tx_err),
		
		.data_wr_en_in(eth_data_wr_en),
		.data_wr_d_in(eth_data_wr_d),
		.data_wr_full_out(eth_data_wr_full),
		
		.ctl_wr_en_in(eth_ctl_wr_en),
		.ctl_wr_d_in(eth_ctl_wr_d),
		.ctl_wr_full_out(eth_ctl_wr_full)
	);
	
	always #10 clk = !clk;
	always #5 gtx_clk = !gtx_clk;
	always #5 rx_clk = !rx_clk;

	integer j;
	reg [7:0] frame [71:0];
	reg [7:0] count;
	
	initial $readmemh("sim/eth_frame.dump", frame);
	
	always @ (posedge rx_clk) begin
		count <= count + 1'd1;
		
		if (count[7:1] < 8'd72) begin
			if (count[0])
				eth_rx_d <= {4'h0, frame[count[7:1]][7:4]};
			else
				eth_rx_d <= {4'h0, frame[count[7:1]][3:0]};
			eth_rx_dv <= 1;
		end else begin
			eth_rx_dv <= 0;
			eth_rx_d <= 0;
		end
		/*
		if (count < 8'd72) begin
			eth_rx_d <= frame[count];
			eth_rx_dv <= 1;
		end else begin
			eth_rx_dv <= 0;
			eth_rx_d <= 0;
		end*/
	end
	
	initial begin
		#1900 c3_p0_wr_full = 1;
		#100 c3_p0_wr_full = 0;
	end
	
	initial begin
		clk = 0;
		rst = 0;
		gtx_clk = 0;
		gtx_rst = 0;
		rx_clk = 0;
		rx_rst = 0;
		eth_rx_d = 0;
		eth_rx_err = 0;
		eth_rx_dv = 0;
		count = 100;
		eth_mode_100 = 1;
		
		c3_p0_cmd_empty = 1;
		c3_p0_cmd_full = 0;
		c3_p0_wr_full = 0;
		c3_p0_wr_empty = 1;
		c3_p0_wr_error = 0;
		c3_p0_wr_underrun = 0;
		c3_p0_wr_count = 0;
		c3_p0_rd_full = 0;
		c3_p0_rd_empty = 1;
		c3_p0_rd_error = 0;
		c3_p0_rd_overflow = 0;
		c3_p0_rd_count = 0;
		c3_p0_rd_data = 0;
		
		btn = 0;

		#100 rst = 1;
		gtx_rst = 1;
		rx_rst = 1;
		#100 rst = 0;
		gtx_rst = 0;
		rx_rst = 0;
		
		#545;
		
		count = 0;
		
		#100;
		
		btn = 5'b00101;
		
		#200 btn = 5'b00100;
		
		#100 btn = 5'b00000;
		
	end
      
endmodule

