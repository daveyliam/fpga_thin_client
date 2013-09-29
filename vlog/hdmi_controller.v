`timescale 1ns / 1ps

// HDMI Controller
// By Liam Davey 07/03/11
// =======================
// connects the hdmi_clockgen, hdmi_encode, and hdmi_serialize modules
// together


module hdmi_controller (
	input clk,
	input rst,
	input clk_2x,
	input rst_2x,
	input clk_10x,
	
	input pll_locked,
	
	input [23:0] rgb_in,
	input hsync_in,
	input vsync_in,
	input de_in,
	
	// to the hdmi output pins
	output hdmi_out_c0_p,
	output hdmi_out_c0_n,
	output hdmi_out_c1_p,
	output hdmi_out_c1_n,
	output hdmi_out_c2_p,
	output hdmi_out_c2_n,
	output hdmi_out_c3_p,
	output hdmi_out_c3_n
);
	
	wire [9:0] tmds_c0, tmds_c1, tmds_c2;

	// this following modules encode input 24-bit rgb data to 3 10-bit
	// tmds data streams.
	// make _SURE_ that 'pclk' (74M pixel clock) is used rather than
	// 'clk' (100M board clock). was a nightmare trying to debug when
	// clk was used instead (seemed to function ok in simulation, but
	// just would not work on fpga! at least i now know why not)
	
	// instantiate tmds encoder for each channel
	
	// blue channel, also encodes hsync and vsync
	tmds_encode u_tmds_encode_0 (
		.clk(clk),
		.rst(rst),
		.d(rgb_in[7:0]),
		.de(de_in),
		.c0(hsync_in),
		.c1(vsync_in),
		.q_out(tmds_c0)
	);
	
	// green channel
	tmds_encode u_tmds_encode_1 (
		.clk(clk),
		.rst(rst),
		.d(rgb_in[15:8]),
		.de(de_in),
		.c0(1'b0),
		.c1(1'b0),
		.q_out(tmds_c1)
	);

	// red channel
	tmds_encode u_tmds_encode_2 (
		.clk(clk),
		.rst(rst),
		.d(rgb_in[23:16]),
		.de(de_in),
		.c0(1'b0),
		.c1(1'b0),
		.q_out(tmds_c2)
	);

	// now we need to serialize the 3 10-bit tmds channels

	// a BUFPLL primitive, used to drive (SERDES) IO.
	// PLLIN input must be either clkout0 or clkout1 from a PLL.
	// GCLK input is used to align SERDESSTROBE, so it must match
	// the expected SERDESSTROBE frequency.
	// IOCLK is the clock used to serialize the data for output.
	// SERDESSTROBE is used to latch in parallel data to the serializer.
	
	wire serdes_strobe;
	wire bufpll_lock;
	wire bufpll_ioclk;
	BUFPLL #(
		.DIVIDE(5)						// 5 bits output per serdes strobe 
	) bufpll_hdmi (
		.PLLIN(clk_10x),				// input from PLL clkout0
		.GCLK(clk_2x),					// input 2x clock to align serdes strobe
		.LOCKED(pll_locked),		// input signal from PLL indicating it has locked
		.IOCLK(bufpll_ioclk),			// output, connects to CLK0 of IOSERDES
		.SERDESSTROBE(serdes_strobe),	// output, connects to IOCE of IOSERDES
		.LOCK(bufpll_lock)				// output, synchronized LOCKED signal from PLL
	);

	wire s_out_c0, s_out_c1, s_out_c2, s_out_c3;
	wire serializer_reset = rst || !bufpll_lock;
	
	reg [29:0] tmds_30_r, tmds_30;
	reg toggle;
	always @ (posedge clk_2x or posedge rst_2x) begin
		if (rst_2x) begin
			tmds_30_r <= 0;
			tmds_30 <= 0;
			toggle <= 0;
		end else begin
			if (toggle)
				{tmds_30_r, tmds_30} <= {tmds_c0, tmds_c1, tmds_c2, tmds_30_r};
			toggle <= !toggle;
		end
	end

	// now the serializer modules, one for each channel (red, green, blue)
	hdmi_serializer hdmi_ser_0 (
		.d((toggle) ? (tmds_30[29:25]) : (tmds_30[24:20])),
		.ioclk(bufpll_ioclk),
		.serdes_strobe(serdes_strobe),
		.rst(serializer_reset),
		.gclk(clk_2x),
		.s_out(s_out_c0)
	);
	
	hdmi_serializer hdmi_ser_1 (
		.d((toggle) ? (tmds_30[19:15]) : (tmds_30[14:10])),
		.ioclk(bufpll_ioclk),
		.serdes_strobe(serdes_strobe),
		.rst(serializer_reset),
		.gclk(clk_2x),
		.s_out(s_out_c1)
	);
	
	hdmi_serializer hdmi_ser_2 (
		.d((toggle) ? (tmds_30[9:5]) : (tmds_30[4:0])),
		.ioclk(bufpll_ioclk),
		.serdes_strobe(serdes_strobe),
		.rst(serializer_reset),
		.gclk(clk_2x),
		.s_out(s_out_c2)
	);
	
	// the hdmi clock is output on channel 3
	// the clock frequency is the same as the pixel clock, that is,
	// each clock cycle 10 bits are transferred on each differential
	// pair.
	// the easiest way to generate this clock is with another serializer,
	// so that the skew between clock and data is minimized
	
	hdmi_serializer hdmi_ser_3 (
		.d((toggle) ? (5'b11111) : (5'b00000)),
		.ioclk(bufpll_ioclk),
		.serdes_strobe(serdes_strobe),
		.rst(serializer_reset),
		.gclk(clk_2x),
		.s_out(s_out_c3)
	);
	
	// connect OSERDES serial outputs to differential output buffers OBUFDS.
	// OBUFDS primitives connect an input to a pair of differential output pins.
	OBUFDS hdmi_obuf_c0 (.I(s_out_c0), .O(hdmi_out_c0_p), .OB(hdmi_out_c0_n));
	OBUFDS hdmi_obuf_c1 (.I(s_out_c1), .O(hdmi_out_c1_p), .OB(hdmi_out_c1_n));
	OBUFDS hdmi_obuf_c2 (.I(s_out_c2), .O(hdmi_out_c2_p), .OB(hdmi_out_c2_n));
	OBUFDS hdmi_obuf_c3 (.I(s_out_c3), .O(hdmi_out_c3_p), .OB(hdmi_out_c3_n));
	
endmodule
