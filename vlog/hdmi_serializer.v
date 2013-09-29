`timescale 1ns / 1ps

// 5 bit serializer module
// takes 5 bits each serdesstrobe and serializes them onto s_out
// at a rate determined by ioclk
// need two OSERDES primitives, a master and slave, as each can only serialize
// a maximum of 4 bits at a time

module hdmi_serializer (
	input [4:0]	d,			// 5 bit wide input data
	input serdes_strobe,	// latch input data on this strobe
	input ioclk,			// io clock, connected to CLK0 of OSERDES modules
	input rst,				// reset signal
	input gclk,				// global clock, connected to CLKDIV of OSERDES
	output s_out			// output data, serialized at ioclk rate
	);

	wire d_mosi;		// cascade data from the master to the slave
	wire d_miso;		// cascade data from the slave to the master
	wire t_mosi;		// cascade tristate data from the master to the slave
	wire t_miso;		// cascade tristate data from the slave to the master

	OSERDES2 #(
		.DATA_WIDTH(5), 					// word width, should match DIVIDE setting of BUFPLL
		.DATA_RATE_OQ("SDR"), 			// use SDR, not DDR, for data output path
		.DATA_RATE_OT("SDR"), 			// use SDR, not DDR, for tristate output path
		.SERDES_MODE("MASTER"), 		// this is the master
		.OUTPUT_MODE("SINGLE_ENDED"))	// UG381 suggests this should be SINGLE_ENDED even for differential outputs
	//	.OUTPUT_MODE("DIFFERENTIAL"))
	oserdes_m_1 (
		.OQ(s_out),							// serial data output
		.OCE(1'b1),							// data output clock enable
		.CLK0(ioclk),						// serialize rate
		.CLK1(1'b0),						// unused
		.IOCE(serdes_strobe),			// strobe to capture input parallel data
		.RST(rst),							// reset signal
		.CLKDIV(gclk),						// clock for control signals
		.D4(1'b0),							// data input bit 7, not used					
		.D3(1'b0),							// data input bit 6, not used
		.D2(1'b0),							// data input bit 5, not used
		.D1(d[4]),							// data input bit 4
		.TQ(),								// tristate output, not used
		.T1(1'b0),							// tristate input, not used
		.T2(1'b0),							// tristate input, not used
		.T3(1'b0),							// tristate input, not used
		.T4(1'b0),							// tristate input, not used
		.TRAIN(1'b0),						// enable 'training'
		.TCE(1'b1),							// tristate clock enable
		.SHIFTIN1(1'b1),					// dummy input in master mode
		.SHIFTIN2(1'b1),					// dummy input in master mode
		.SHIFTIN3(d_miso),				// cascade data input from slave
		.SHIFTIN4(t_miso),				// cascade tristate input from slave
		.SHIFTOUT1(d_mosi),				// cascade data output to slave
		.SHIFTOUT2(t_mosi),				// cacade tristate output to slave
		.SHIFTOUT3(),						// dummy output in master mode
		.SHIFTOUT4()						// dummy output in master mode
	);

	OSERDES2 #(
		.DATA_WIDTH(5), 					// word width, should match DIVIDE setting of BUFPLL
		.DATA_RATE_OQ("SDR"), 			// use SDR, not DDR, for data output path
		.DATA_RATE_OT("SDR"), 			// use SDR, not DDR, for tristate output path
		.SERDES_MODE("SLAVE"), 			// this is the slave
		.OUTPUT_MODE("SINGLE_ENDED"))	// UG381 suggests this should be SINGLE_ENDED even for differential outputs
	//	.OUTPUT_MODE("DIFFERENTIAL"))
	oserdes_m_2 (
		.OQ(),								// serial data output, not used in slave
		.OCE(1'b1),							// data output clock enable
		.CLK0(ioclk),						// serialize rate
		.CLK1(1'b0),						// unused
		.IOCE(serdes_strobe),			// strobe to capture input parallel data
		.RST(rst),							// reset signal
		.CLKDIV(gclk),						// clock for control signals
		.D4(d[3]),							// data input bit 3				
		.D3(d[2]),							// data input bit 2
		.D2(d[1]),							// data input bit 1
		.D1(d[0]),							// data input bit 0
		.TQ(),								// tristate output, not used
		.T1(1'b0),							// tristate input, not used
		.T2(1'b0),							// tristate input, not used
		.T3(1'b0),							// tristate input, not used
		.T4(1'b0),							// tristate input, not used
		.TCE(1'b1),							// tristate clock enable
		.TRAIN(1'b0),						// enable 'training'
		.SHIFTIN1(d_mosi),				// cascade data input from master
		.SHIFTIN2(t_mosi),				// cascade tristate input from master
		.SHIFTIN3(1'b1),					// dummy input for slave
		.SHIFTIN4(1'b1),					// dummy input for slave
		.SHIFTOUT1(),						// dummy output for slave
		.SHIFTOUT2(),						// dummy output for slave
		.SHIFTOUT3(d_miso),				// cascade data output from master
		.SHIFTOUT4(t_miso)				// cascade data output from master
	);

endmodule
