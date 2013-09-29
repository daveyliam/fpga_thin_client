`timescale 1ns / 1ps

// top level module for ethterm

module main (
	// clock and reset signal from the atlys board
	input brd_clk,
	input brd_rst_n,
	
	// board switches
	input [7:0] sw,
	
	// board buttons
	input [4:0] btn,
	
	// board leds
	output [7:0] led,
	
	// ps2 mouse and keyboard
	input ps2_k_clk,
	input ps2_k_d,
	input ps2_m_clk,
	input ps2_m_d,
	
	// mcb3 external io pins
   inout  [15:0] mcb3_dram_dq,
   output [12:0] mcb3_dram_a,
   output [2:0] mcb3_dram_ba,
   output mcb3_dram_ras_n,
   output mcb3_dram_cas_n,
   output mcb3_dram_we_n,
   output mcb3_dram_odt,
   output mcb3_dram_cke,
   output mcb3_dram_dm,
   inout mcb3_dram_udqs,
   inout mcb3_dram_udqs_n,
   inout mcb3_rzq,
   inout mcb3_zio,
   output mcb3_dram_udm,
   inout mcb3_dram_dqs,
   inout mcb3_dram_dqs_n,
   output mcb3_dram_ck,
   output mcb3_dram_ck_n,
	
	// hdmi tmds output
	output hdmi_out_c0_p,
	output hdmi_out_c0_n,
	output hdmi_out_c1_p,
	output hdmi_out_c1_n,
	output hdmi_out_c2_p,
	output hdmi_out_c2_n,
	output hdmi_out_c3_p,
	output hdmi_out_c3_n,
	
	// ethernet phy gmii
	input eth_tx_clk,
	output eth_tx_gtx,
	output [7:0] eth_tx_d,
	output eth_tx_en,
	output eth_tx_err,
	
	input eth_rx_clk,
	input [7:0] eth_rx_d,
	input eth_rx_err,
	input eth_rx_dv,
	
	output eth_rst_n
);

	// mac address, make sure bits 1 and 0 of the most significant
	// byte are 0.
	// bit 1 is globally unique (0) or locally administered (1).
	// bit 2 is unicast (0) or multicast (1).
	// if either of these is set ethernet frames may travel to the entire
	// network, causing slow devices to send MAC_PAUSE frames which cause
	// the sending computer to slow packet transmission.
	// with these bits set the throughput dropped from 100-125 MB/s to
	// about 1-2 MB/s.
	localparam MAC = 48'h005056abcdef;
	// 0x88b5 is the 'ethertype' used for protocol testing
	// could also use 0x88b6
	localparam TYPE = 16'h88b5;
	
	// eth_mode_100 when asserted causes the eth_mac_rx and
	// eth_mac_tx modules to operate in 100Mbit mode (instead of
	// 1000Mbit mode)
	wire eth_mode_100 = sw[7];
	
	// eth_debug_mode causes ack frames to be sent in reply to
	// every frame received by the eth_decode module
	wire eth_debug_mode = sw[6];
	
	// hdmi_mode_test when asserted causes the hdmi_video module
	// to generate a video test pattern
	wire hdmi_mode_test = sw[5];
	
	// clock and reset signals
	// mcb_clk is 50MHz
	// hdmi_clk is 74.25MHz
	// gtx_clk is 125MHz
	wire mcb_clk;
	wire hdmi_clk_clkgen;
	wire hdmi_clk;
	wire hdmi_clk_2x;
	wire hdmi_clk_10x;
	wire gtx_clk;
	
	// hdmi clock generator
	// a clock generator to generate the ~74.25MHz clock needed for 720p
	// the closest i could find was 50*248/167 = 74.2515, bearing in mind
	// only integers from 1-255 are allowed for numerator and denominator
	
	wire hdmi_clk_clkgen_bufg, hdmi_clkgen_locked;
	DCM_CLKGEN #(
		.CLKFX_DIVIDE(167),
		.CLKFX_MULTIPLY(248),
		.CLKIN_PERIOD(20.000)
	) hdmi_clkgen (
		.CLKIN(mcb_clk),
		.CLKFX(hdmi_clk_clkgen_bufg),
		.CLKFX180(),
		.CLKFXDV(),
		.LOCKED(hdmi_clkgen_locked),
		.PROGDONE(),
		.STATUS(),
		.FREEZEDCM(1'b0),
		.PROGCLK(1'b0),
		.PROGDATA(1'b0),
		.PROGEN(1'b0),
		.RST(!brd_rst_n)
	);
	BUFG hdmi_clk_clkgen_bufg_bufg (.I(hdmi_clk_clkgen_bufg), .O(hdmi_clk_clkgen));
	
	// a PLL_BASE primitive used to create a 10x clock for the serializers, a 2x clock
	// for the 10->5 encoder, and a 1x pixel clock all in phase with each other
	
	wire pll_clkfb, pll_clkout1, pll_clkout2, pll_locked;
	PLL_BASE #(
		.CLKIN_PERIOD(13.4677419),	// period of input clock
		.CLKFBOUT_MULT(10),			// factor to multiply the input clock by
		.CLKOUT0_DIVIDE(1),			// clkout0 is 10 / 1 = 10x clkin
		.CLKOUT1_DIVIDE(10),			// clkout1 is 10 / 10 = 1x clkin
		.CLKOUT2_DIVIDE(5)			// clkout2 is 10 / 5 = 2x clkin
	) hdmi_pll (
		.CLKFBOUT(pll_clkfb),		// feedback output
		.CLKOUT0(hdmi_clk_10x),			// clkout0, 10x for serdes
		.CLKOUT1(pll_clkout1),		// clkout1, 1x pixel clock
		.CLKOUT2(pll_clkout2),		// clkout2, 2x clock for shifting 5-bit data to serdes
		.CLKOUT3(),
		.CLKOUT4(),
		.CLKOUT5(),
		.LOCKED(pll_locked),			// indicates PLL has achieved phase lock
		.CLKFBIN(pll_clkfb),			// feedback input, connected to fbout to form feedback loop
		.CLKIN(hdmi_clk_clkgen),	// the input clock signal
		.RST(!brd_rst_n)						// reset
	);
	
	// only connect the 1x and 2x clock to the clock network, the 10x clock
	// goes directly to the BUFIO2 block in the serializer
	BUFG hdmi_clk_bufg (.I(pll_clkout1), .O(hdmi_clk));
	BUFG hdmi_clk_2x_bufg (.I(pll_clkout2), .O(hdmi_clk_2x));
	
	// ethernet gtx clock generator
	// a clock generator to generate the 125MHz clock for the
	// ethernet transmitter
	
	wire gtx_clk_bufg, gtx_clkgen_locked;
	wire gtx_clk_n, gtx_clk_n_bufg;
	DCM_CLKGEN #(
		.CLKFX_DIVIDE(20),
		.CLKFX_MULTIPLY(50),
		.CLKIN_PERIOD(20.000)
	) gtx_clkgen (
		.CLKIN(mcb_clk),
		.CLKFX(gtx_clk_bufg),
		.CLKFX180(gtx_clk_n_bufg),
		.CLKFXDV(),
		.LOCKED(gtx_clkgen_locked),
		.PROGDONE(),
		.STATUS(),
		.FREEZEDCM(1'b0),
		.PROGCLK(1'b0),
		.PROGDATA(1'b0),
		.PROGEN(1'b0),
		.RST(!brd_rst_n)
	);
	BUFG gtx_clk_bufg_bufg (.I(gtx_clk_bufg), .O(gtx_clk));
	BUFG gtx_clk_n_bufg_bufg (.I(gtx_clk_n_bufg), .O(gtx_clk_n));
	
	ODDR2 gtx_clk_oddr2 (.D0(1'b1), .D1(1'b0), .C0(gtx_clk), .C1(gtx_clk_n), .Q(eth_tx_gtx));
	
	// attach rx_clk (125MHz) to global clock network
	wire rx_clk;
	IBUFG eth_rx_clk_ibufg (
		.I(eth_rx_clk),
		.O(rx_clk)
	);
	
	// attach tx_clk (25MHz) to global clock network
	wire tx_clk_in;
	IBUFG eth_tx_clk_ibufg (
		.I(eth_tx_clk),
		.O(tx_clk_in)
	);
	
	// mux between eth_tx_clk (25MHz) and gtx_clk (125MHz)
	wire tx_clk;
	BUFGMUX bufgmux_tx_clk (
		.I0(gtx_clk),
		.I1(tx_clk_in),
		.S(eth_mode_100),
		.O(tx_clk)
	);
	
	// buffer reset signals
	// (otherwise we get hold violations in place and route)
	
	wire mcb_rst_tmp, mcb_calib_done;
	wire mcb_rst_tmp2 = mcb_rst_tmp || !mcb_calib_done;
	
	reg mcb_rst_r, mcb_rst;
	always @ (posedge mcb_clk or posedge mcb_rst_tmp2)
		{mcb_rst, mcb_rst_r} <= (mcb_rst_tmp2) ? 2'b11 : {mcb_rst_r, 1'b0};
	
	wire rst_tmp = mcb_rst || (!pll_locked);
	//wire rst_tmp = mcb_rst;
	
	reg hdmi_rst_r, hdmi_rst;
	always @ (posedge hdmi_clk or posedge rst_tmp)
		{hdmi_rst, hdmi_rst_r} <= (rst_tmp) ? 2'b11 : {hdmi_rst_r, 1'b0};
	
	reg hdmi_rst_2x_r, hdmi_rst_2x;
	always @ (posedge hdmi_clk_2x or posedge rst_tmp)
		{hdmi_rst_2x, hdmi_rst_2x_r} <= (rst_tmp) ? 2'b11 : {hdmi_rst_2x_r, 1'b0};
	
	reg tx_rst_r, tx_rst;
	always @ (posedge tx_clk or posedge rst_tmp)
		{tx_rst, tx_rst_r} <= (rst_tmp) ? 2'b11 : {tx_rst_r, 1'b0};
	
	reg rx_rst_r, rx_rst;
	always @ (posedge rx_clk or posedge rst_tmp)
		{rx_rst, rx_rst_r} <= (rst_tmp) ? 2'b11 : {rx_rst_r, 1'b0};
	
	assign eth_rst_n = !mcb_rst;
	
	// signals for ddr2 mcb wrapper
	
	wire c3_p0_cmd_en;
	wire [2:0] c3_p0_cmd_instr;
	wire [5:0] c3_p0_cmd_bl;
	wire [29:0] c3_p0_cmd_byte_addr;
	wire c3_p0_cmd_empty;
	wire c3_p0_cmd_full;
	wire c3_p0_wr_en;
	wire [7:0] c3_p0_wr_mask;
	wire [63:0] c3_p0_wr_data;
	wire c3_p0_wr_full;
	wire c3_p0_wr_empty;
	wire c3_p0_wr_error;
	wire c3_p0_wr_underrun;
	wire [6:0] c3_p0_wr_count;
	wire c3_p0_rd_en;
	wire [63:0] c3_p0_rd_data;
	wire c3_p0_rd_full;
	wire c3_p0_rd_empty;
	wire c3_p0_rd_error;
	wire c3_p0_rd_overflow;
	wire [6:0] c3_p0_rd_count;
	
	wire c3_p1_cmd_en;
	wire [2:0] c3_p1_cmd_instr;
	wire [5:0] c3_p1_cmd_bl;
	wire [29:0] c3_p1_cmd_byte_addr;
	wire c3_p1_cmd_empty;
	wire c3_p1_cmd_full;
	wire c3_p1_wr_en;
	wire [7:0] c3_p1_wr_mask;
	wire [63:0] c3_p1_wr_data;
	wire c3_p1_wr_full;
	wire c3_p1_wr_empty;
	wire c3_p1_wr_error;
	wire c3_p1_wr_underrun;
	wire [6:0] c3_p1_wr_count;
	wire c3_p1_rd_en;
	wire [63:0] c3_p1_rd_data;
	wire c3_p1_rd_full;
	wire c3_p1_rd_empty;
	wire c3_p1_rd_error;
	wire c3_p1_rd_overflow;
	wire [6:0] c3_p1_rd_count;

	// instantiate dram mcb wrapper
	atlys_ddr2 #(
		.C3_RST_ACT_LOW(1)
	) u_atlys_ddr2 (
		
		// signals to dram chip
		.mcb3_dram_dq(mcb3_dram_dq),
		.mcb3_dram_a(mcb3_dram_a),
		.mcb3_dram_ba(mcb3_dram_ba),
		.mcb3_dram_ras_n(mcb3_dram_ras_n),
		.mcb3_dram_cas_n(mcb3_dram_cas_n),
		.mcb3_dram_we_n(mcb3_dram_we_n),
		.mcb3_dram_odt(mcb3_dram_odt),
		.mcb3_dram_cke(mcb3_dram_cke),
		.mcb3_dram_dm(mcb3_dram_dm),
		.mcb3_dram_udqs(mcb3_dram_udqs),
		.mcb3_dram_udqs_n(mcb3_dram_udqs_n),
		.mcb3_rzq(mcb3_rzq),
		.mcb3_zio(mcb3_zio),
		.mcb3_dram_udm(mcb3_dram_udm),
		.mcb3_dram_dqs(mcb3_dram_dqs),
		.mcb3_dram_dqs_n(mcb3_dram_dqs_n),
		.mcb3_dram_ck(mcb3_dram_ck),
		.mcb3_dram_ck_n(mcb3_dram_ck_n),

		// clock and reset signals
		.c3_sys_clk(brd_clk),
		.c3_sys_rst_n(brd_rst_n),
		.c3_calib_done(mcb_calib_done),
		.c3_clk0(mcb_clk),
		.c3_rst0(mcb_rst_tmp),

		// port 0 64 bit interface
		// mcb_clk (125MHz) domain
		.c3_p0_cmd_clk(mcb_clk),
		.c3_p0_cmd_en(c3_p0_cmd_en),
		.c3_p0_cmd_instr(c3_p0_cmd_instr),
		.c3_p0_cmd_bl(c3_p0_cmd_bl),
		.c3_p0_cmd_byte_addr(c3_p0_cmd_byte_addr),
		.c3_p0_cmd_empty(c3_p0_cmd_empty),
		.c3_p0_cmd_full(c3_p0_cmd_full),
		.c3_p0_wr_clk(mcb_clk),
		.c3_p0_wr_en(c3_p0_wr_en),
		.c3_p0_wr_mask(c3_p0_wr_mask),
		.c3_p0_wr_data(c3_p0_wr_data),
		.c3_p0_wr_full(c3_p0_wr_full),
		.c3_p0_wr_empty(c3_p0_wr_empty),
		.c3_p0_wr_count(c3_p0_wr_count),
		.c3_p0_wr_underrun(c3_p0_wr_underrun),
		.c3_p0_wr_error(c3_p0_wr_error),
		.c3_p0_rd_clk(mcb_clk),
		.c3_p0_rd_en(c3_p0_rd_en),
		.c3_p0_rd_data(c3_p0_rd_data),
		.c3_p0_rd_full(c3_p0_rd_full),
		.c3_p0_rd_empty(c3_p0_rd_empty),
		.c3_p0_rd_count(c3_p0_rd_count),
		.c3_p0_rd_overflow(c3_p0_rd_overflow),
		.c3_p0_rd_error(c3_p0_rd_error),
		
		// port 1 64 bit interface
		// controlled by hdmi_video
		// hdmi_clk (74.25 MHz) domain
		.c3_p1_cmd_clk(hdmi_clk),
		.c3_p1_cmd_en(c3_p1_cmd_en),
		.c3_p1_cmd_instr(c3_p1_cmd_instr),
		.c3_p1_cmd_bl(c3_p1_cmd_bl),
		.c3_p1_cmd_byte_addr(c3_p1_cmd_byte_addr),
		.c3_p1_cmd_empty(c3_p1_cmd_empty),
		.c3_p1_cmd_full(c3_p1_cmd_full),
		.c3_p1_wr_clk(hdmi_clk),
		.c3_p1_wr_en(c3_p1_wr_en),
		.c3_p1_wr_mask(c3_p1_wr_mask),
		.c3_p1_wr_data(c3_p1_wr_data),
		.c3_p1_wr_full(c3_p1_wr_full),
		.c3_p1_wr_empty(c3_p1_wr_empty),
		.c3_p1_wr_count(c3_p1_wr_count),
		.c3_p1_wr_underrun(c3_p1_wr_underrun),
		.c3_p1_wr_error(c3_p1_wr_error),
		.c3_p1_rd_clk(hdmi_clk),
		.c3_p1_rd_en(c3_p1_rd_en),
		.c3_p1_rd_data(c3_p1_rd_data),
		.c3_p1_rd_full(c3_p1_rd_full),
		.c3_p1_rd_empty(c3_p1_rd_empty),
		.c3_p1_rd_count(c3_p1_rd_count),
		.c3_p1_rd_overflow(c3_p1_rd_overflow),
		.c3_p1_rd_error(c3_p1_rd_error)
	);
	
	// video controller
	// hdmi_mode_bpp selects between 32 bit colour mode (0)
	// or 16 bit colour mode (1) for the hdmi_video module
	wire hdmi_mode_bpp;
	wire hsync, vsync, de, hdmi_fb_num;
	wire [23:0] rgb;
	
	hdmi_video u_hdmi_video (
		.clk(hdmi_clk),
		.rst(hdmi_rst),
		
		.mode_test_in(hdmi_mode_test),
		.mode_bpp_in(hdmi_mode_bpp),
		.fb_num_in(hdmi_fb_num),
	
		.mcb_cmd_en_out(c3_p1_cmd_en),
		.mcb_cmd_instr_out(c3_p1_cmd_instr),
		.mcb_cmd_bl_out(c3_p1_cmd_bl),
		.mcb_cmd_byte_addr_out(c3_p1_cmd_byte_addr),
		.mcb_cmd_empty_in(c3_p1_cmd_empty),
		.mcb_cmd_full_in(c3_p1_cmd_full),
		
		.mcb_wr_en_out(c3_p1_wr_en),
		.mcb_wr_mask_out(c3_p1_wr_mask),
		.mcb_wr_data_out(c3_p1_wr_data),
		.mcb_wr_full_in(c3_p1_wr_full),
		.mcb_wr_empty_in(c3_p1_wr_empty),
		.mcb_wr_error_in(c3_p1_wr_error),
		.mcb_wr_underrun_in(c3_p1_wr_underrun),
		.mcb_wr_count_in(c3_p1_wr_count),
		
		.mcb_rd_en_out(c3_p1_rd_en),
		.mcb_rd_data_in(c3_p1_rd_data),
		.mcb_rd_full_in(c3_p1_rd_full),
		.mcb_rd_empty_in(c3_p1_rd_empty),
		.mcb_rd_error_in(c3_p1_rd_error),
		.mcb_rd_overflow_in(c3_p1_rd_overflow),
		.mcb_rd_count_in(c3_p1_rd_count),
		
		.rgb_out(rgb),
		.hsync_out(hsync),
		.vsync_out(vsync),
		.de_out(de)
	);
	
	// hdmi controller
	
	hdmi_controller u_hdmi_controller (
		.clk(hdmi_clk),
		.rst(hdmi_rst),
		.clk_2x(hdmi_clk_2x),
		.rst_2x(hdmi_rst_2x),
		.clk_10x(hdmi_clk_10x),
		
		.pll_locked(pll_locked),
		
		.rgb_in(rgb),
		.hsync_in(hsync),
		.vsync_in(vsync),
		.de_in(de),
		
		.hdmi_out_c0_p(hdmi_out_c0_p),
		.hdmi_out_c0_n(hdmi_out_c0_n),
		.hdmi_out_c1_p(hdmi_out_c1_p),
		.hdmi_out_c1_n(hdmi_out_c1_n),
		.hdmi_out_c2_p(hdmi_out_c2_p),
		.hdmi_out_c2_n(hdmi_out_c2_n),
		.hdmi_out_c3_p(hdmi_out_c3_p),
		.hdmi_out_c3_n(hdmi_out_c3_n)
	);
	
	wire eth_data_rd_en, eth_data_rd_empty;
	wire [63:0] eth_data_rd_d;
	wire eth_ctl_rd_en, eth_ctl_rd_empty;
	wire [15:0] eth_ctl_rd_d;
	
	wire [7:0] eth_rx_debug;
	
	// ethernet receiver mac
	
	eth_mac_rx eth_mac_rx_0 (
		.clk(rx_clk),
		.rst(rx_rst),
		.rd_clk(mcb_clk),
		.rd_rst(mcb_rst),
		
		.eth_mode_100_in(eth_mode_100),
		.debug_out(eth_rx_debug),
		
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
	wire [15:0] aux;
	
	assign hdmi_mode_bpp = aux[1];
	assign hdmi_fb_num = aux[0];
	
	eth_decode #(
		.MAC(MAC),
		.TYPE(TYPE)
	) eth_decode_0 (
		.clk(mcb_clk),
		.rst(mcb_rst),
		
		.aux_out(aux),
		.debug_mode_in(eth_debug_mode),
		
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
	wire ps2_k_act, ps2_m_act;

	ps2_if ps2_if_0 (
		.clk(mcb_clk),
		.rst(mcb_rst),
		
		.btn(btn),
		.ps2_k_clk_in(ps2_k_clk),
		.ps2_k_d_in(ps2_k_d),
		.ps2_m_clk_in(ps2_m_clk),
		.ps2_m_d_in(ps2_m_d),
		
		.ps2_k_act_out(ps2_k_act),
		.ps2_m_act_out(ps2_m_act),
		
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
	
	wire [7:0] eth_tx_debug;
	
	eth_mac_tx eth_mac_tx_0 (
		.clk(tx_clk),
		.rst(tx_rst),
		.wr_clk(mcb_clk),
		.wr_rst(mcb_rst),
		
		.eth_mode_100_in(eth_mode_100),
		.debug_out(eth_tx_debug),
		
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
	
	// debugging leds
	assign led = (sw[0]) ? aux[15:8] : {eth_tx_debug[3:0], eth_rx_debug[3:0]};
	
endmodule
