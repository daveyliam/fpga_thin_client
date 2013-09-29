// video controller
// by Liam Davey (20/04/11)

module hdmi_video (
	input clk,
	input rst,
	
	input mode_test_in,
	input mode_bpp_in,
	input fb_num_in,
	
	output reg mcb_cmd_en_out,
	output [2:0] mcb_cmd_instr_out,
	output [5:0] mcb_cmd_bl_out,
	output reg [29:0] mcb_cmd_byte_addr_out,
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
	input [6:0] mcb_rd_count_in,
	
	output reg vsync_out,
	output reg hsync_out,
	output reg de_out,
	output [23:0] rgb_out
);

	assign mcb_wr_mask_out = 8'h0;
	assign mcb_wr_en_out = 1'b0;
	assign mcb_wr_data_out = 64'b0;
	// always assert rd_en so that data in the read
	// fifo needs to be read on the same cycle that
	// the rd_empty signal goes low
	assign mcb_rd_en_out = 1'b1;
	// set read instruction and burst length of 8
	assign mcb_cmd_bl_out = 6'd7;
	assign mcb_cmd_instr_out = 3'b001;
	
	// sync fb_num
	reg fb_num_r, fb_num;
	always @ (posedge clk or posedge rst)
		{fb_num, fb_num_r} <= (rst) ? 2'b00 : {fb_num_r, fb_num_in};
	
	// video signal timing parameters
	// 1280 x 720 x 60Hz @ 74.25MHz
	localparam X_DE_START = 12'd0;
	localparam X_DE_STOP = 12'd1280;
	localparam X_SYNC_START = 12'd1390;
	localparam X_SYNC_STOP = 12'd1430;
	localparam X_STOP = 12'd1650;
	
	localparam Y_DE_START = 12'd0;
	localparam Y_DE_STOP = 12'd720;
	localparam Y_SYNC_START = 12'd725;
	localparam Y_SYNC_STOP = 12'd730;
	localparam Y_STOP = 12'd750;
	
	localparam BURSTS_PER_LINE_16 = 7'd40;
	localparam BURSTS_PER_LINE_32 = 7'd80;
	
	wire mode_bpp_32 = !mode_bpp_in;
	wire mode_bpp_16 = mode_bpp_in;
	
	// these signals are asserted when the x and y counters reach certain
	// values.
	
	wire x_de_start   = x == X_DE_START;
	wire x_de_stop    = x == X_DE_STOP;
	wire x_sync_start = x == X_SYNC_START;
	wire x_sync_stop  = x == X_SYNC_STOP;
	wire x_stop       = x == (X_STOP - 1'd1);
	
	wire y_de_start   = y == Y_DE_START;
	wire y_de_stop    = y == Y_DE_STOP;
	wire y_sync_start = y == Y_SYNC_START;
	wire y_sync_stop  = y == Y_SYNC_STOP;
	wire y_stop       = y == (Y_STOP - 1'd1);
	
	reg x_de, y_de;

	// 12 bit counter (0-4095) for the x and y axis
	reg [11:0] x, y;
	
	// x and y next values
	wire [11:0] y_next = (x_stop) ? ((y_stop) ? 12'd0 : y + 12'd1) : y;
	wire [11:0] x_next = (x_stop) ? 12'd0 : x + 12'd1;
	
	// test if de should be enabled
	wire y_de_next = y_de_start ? 1'b1 : (y_de_stop ? 1'b0 : y_de);
	wire x_de_next = x_de_start ? 1'b1 : (x_de_stop ? 1'b0 : x_de);
	wire de_next = y_de_next && x_de_next;
	
	// test if hsync or vsync should be enabled
	wire hsync_next = x_sync_start ? 1'b1 : (x_sync_stop ? 1'b0 : hsync_out);
	wire vsync_next = y_sync_start ? 1'b1 : (y_sync_stop ? 1'b0 : vsync_out);
	
	// buffer to hold an entire horizontal
	// line of pixel values
	
	reg lbuf_wr_en, lbuf_rd_en;
	reg [9:0] lbuf_wr_addr;
	reg [71:0] lbuf_wr_d;
	reg [9:0] lbuf_rd_addr;
	wire [71:0] lbuf_rd_d;
	
	bram_72_72_8k line_buf (
		.clka(clk),
		.clkb(clk),
		.wea(lbuf_wr_en),
		.addra(lbuf_wr_addr),
		.dina(lbuf_wr_d),
		.addrb(lbuf_rd_addr),
		.doutb(lbuf_rd_d)
	);
	
	// 24 bit colour
	// 8 bit red, 8 bit blue, 8 bit green
	
	reg [23:0] rgb;
	wire [23:0] rgb_test = {x[7:0] ^ y[7:0], x[7:0], y[7:0]};
	assign rgb_out = (de_out) ? ((mode_test_in) ? rgb_test : rgb) : 24'h0;
	
	//reg [15:0] tmp;
	
	reg [1:0] de, hsync, vsync;
	
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			x_de <= 0; y_de <= 0;
			de <= 0;
			hsync <= 0; vsync <= 0;
			de_out <= 0;
			hsync_out <= 0; vsync_out <= 0;
			x <= X_SYNC_START; y <= Y_SYNC_START;
			lbuf_rd_addr <= 0;
			rgb <= 0;
			
		end else begin
			x <= x_next;
			y <= y_next;
			x_de <= x_de_next;
			y_de <= y_de_next;
			{de_out, de} <= {de, de_next};
			{hsync_out, hsync} <= {hsync, hsync_next};
			{vsync_out, vsync} <= {vsync, vsync_next};
			
			// x      | 0 1 2 3 4 5 6 7 0 1
			// de[0]  | 0 1 1 1 1 1 1 1 1 1
			// de[1]  | 0 0 1 1 1 1 1 1 1 1
			// de_out | 0 0 0 1 1 1 1 1 1 1
			// pixel  | - - - 0 1 2 3 4 5 6
			
			// rgb needs to be set on the cycle that x[1:0] == 2
			// so that rgb contains the correct value when de_out
			// first goes high
			
			// the lbuf_rd_addr should be set when x[1:0] == 0,
			// so that data is ready on lbuf_rd_d when de_out goes high
			
			if (mode_bpp_32) begin
				// 32 bit mode
				// increment lbuf_rd_addr every second pixel
				if (!de[1])
					lbuf_rd_addr <= 0;
				else if (x[0] == 1'b0)
					lbuf_rd_addr <= lbuf_rd_addr + 1'd1;
				
				// qemu outputs bgr32 format by default so flip the byte order
				rgb <= (x[0] == 1'b0) ? 
					{lbuf_rd_d[47:40], lbuf_rd_d[55:48], lbuf_rd_d[63:56]} : 
					{lbuf_rd_d[15:8], lbuf_rd_d[23:16], lbuf_rd_d[31:24]};
					
			end else begin
				// 16 bit mode
				// increment lbuf_rd_addr once every four pixels
				if (!de[1])
					lbuf_rd_addr <= 0;
				else if (x[1:0] == 2'h0)
					lbuf_rd_addr <= lbuf_rd_addr + 1'd1;
				
				// mplayer uses a strange 16 bit format:
				// it seems byte swapped (endianness? network order?) but
				// also bgr when it should be rgb
				// 15 14 13 12 11 10  9  8  |  7  6  5  4  3  2  1  0
				// g2 g1 g0 r4 r3 r2 r1 r0  | b4 b3 b2 b1 b0 g5 g4 g3
				
				case (x[1:0])
					2'h2: rgb <= {lbuf_rd_d[60:56], 3'h0, lbuf_rd_d[50:48], lbuf_rd_d[63:61], 2'h0, lbuf_rd_d[55:51], 3'h0};
					2'h3: rgb <= {lbuf_rd_d[44:40], 3'h0, lbuf_rd_d[34:32], lbuf_rd_d[47:45], 2'h0, lbuf_rd_d[39:35], 3'h0};
					2'h0: rgb <= {lbuf_rd_d[28:24], 3'h0, lbuf_rd_d[18:16], lbuf_rd_d[31:29], 2'h0, lbuf_rd_d[23:19], 3'h0};
					2'h1: rgb <= {lbuf_rd_d[12:8],  3'h0, lbuf_rd_d[2:0],   lbuf_rd_d[15:13], 2'h0, lbuf_rd_d[7:3],   3'h0};
				endcase
			end
		end
	end
	
	// 2048 * 4 = 8192 bytes per line
	// 2048 lines in total
	// byte_addr[12:0] is line position (0-8191)
	// byte_addr[23:13] is line number (0-2047)
	// byte_addr[24] selects the frame buffer (fb0 or fb1)
	
	always @ (posedge clk) begin
		if (rst || mode_test_in) begin
			mcb_cmd_en_out <= 0;
			mcb_cmd_byte_addr_out <= 0;
			lbuf_wr_en <= 0;
			lbuf_wr_addr <= 0;
			lbuf_wr_d <= 0;
			
		end else begin
			if (x_de_stop) begin
				// when data enable goes low at the end of a horizontal
				// line, schedule dram reads for the next line
				mcb_cmd_en_out <= 1;
				if (y_stop) begin
					// only switch framebuffers at the end of each frame
					mcb_cmd_byte_addr_out[24] <= fb_num;
					// line number (0 - 2048)
					mcb_cmd_byte_addr_out[23:13] <= 0;
				end else
					// line number (0 - 2048)
					mcb_cmd_byte_addr_out[23:13] <= mcb_cmd_byte_addr_out[23:13] + 11'd1;
				
				// line burst number (0 - 127)
				mcb_cmd_byte_addr_out[12:6] <= 0;
				lbuf_wr_addr <= 0;
				lbuf_wr_en <= 0;
				
			end else begin
				// schedule new burst reads
				// 32-bit: every 16 pixels, 80 bursts per line
				// 16-bit: every 32 pixels, 40 bursts per line
				
				if (	(!mcb_cmd_full_in) && (x[3:0] == 4'h0) &&
						((mode_bpp_32  && (mcb_cmd_byte_addr_out[12:6] != BURSTS_PER_LINE_32)) ||
						 (mode_bpp_16  && (mcb_cmd_byte_addr_out[12:6] != BURSTS_PER_LINE_16) && !x[4]))) begin
					mcb_cmd_en_out <= 1;
					mcb_cmd_byte_addr_out[12:6] <= mcb_cmd_byte_addr_out[12:6] + 1'd1;
				end else
					mcb_cmd_en_out <= 0;
				
				// as soon as data is present in the read fifo write
				// it to the line buffer
				if (!mcb_rd_empty_in) begin
					lbuf_wr_en <= 1;
					lbuf_wr_d <= {8'h0, mcb_rd_data_in};
				end else
					lbuf_wr_en <= 0;
				
				// increment the line buffer address after the data
				// is written
				if (lbuf_wr_en)
					lbuf_wr_addr <= lbuf_wr_addr + 1'd1;
			end
		end
	end
endmodule
