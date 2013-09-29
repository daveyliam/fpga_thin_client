`timescale 1ns / 1ps
`define SIMULATION 1
//`include "bram_fifo.v"
//`include "rl_decode.v"
`include "hdmi_timing.v"
`include "tmds_encode.v"
`include "hdmi_encode.v"
`include "tmds_decode.v"
`include "hdmi_decode.v"

// HDMI Encode Test Bench
// By Liam Davey 10/03/11
// =======================
// Tests the complete fifo -> tmds data path

module hdmi_encode_tb;

	parameter XRES = 8'd4;
	parameter YRES = 8'd4;

	reg clk, rst;
	
	wire hsync, vsync, de;
	wire [11:0] x, y;
	
	reg hsync_r, vsync_r, de_r;
	reg [23:0] rgb_r;
	
	hdmi_timing u_hdmi_timing (
		.clk(clk),
		.rst(rst),
		.de(de),
		.hsync(hsync),
		.vsync(vsync),
		.x_out(x),
		.y_out(y)
	);

	wire [9:0] tmds_c0, tmds_c1, tmds_c2;
	
	always @ (posedge clk) begin
		if (rst) begin
			hsync_r <= 0;
			vsync_r <= 0;
			de_r <= 0;
			rgb_r <= 0;
		end else begin
			if (de) begin
				rgb_r <= x ^ y;
			end else begin
				rgb_r <= 0;
			end
			vsync_r <= vsync;
			hsync_r <= hsync;
			de_r <= de;
		end
	end

	hdmi_encode u_hdmi_encode (
		.clk(clk),
		.rst(rst),
		.de_in(de_r),
		.hsync_in(hsync_r),
		.vsync_in(vsync_r),
		.rgb_in(rgb_r),
		.tmds_c0(tmds_c0),
		.tmds_c1(tmds_c1),
		.tmds_c2(tmds_c2)
	);
	
	
	wire vsync_out, hsync_out, de_out;
	wire [11:0] x_out, y_out;
	wire [23:0] rgb_out;
	
	hdmi_decode u_hdmi_decode (
		.clk(clk),
		.rst(rst),
		.tmds_c0_in(tmds_c0),
		.tmds_c1_in(tmds_c1),
		.tmds_c2_in(tmds_c2),
		.vsync_out(vsync_out),
		.hsync_out(hsync_out),
		.de_out(de_out),
		.x_out(x_out),
		.y_out(y_out),
		.rgb_out(rgb_out),
		.cnt_c0_out(),
		.cnt_c1_out(),
		.cnt_c2_out()
	);
	
	// 'video' ram to write decoded data to
	reg [23:0] vram [0:4095];
	reg [7:0] frame_count;
	reg after_first_vsync;
	
	always @ (negedge vsync) begin
		after_first_vsync <= 1;
		if (after_first_vsync) begin
			frame_count <= frame_count + 1;
			$display("frame #%d", frame_count);
			$display("%x %x %x %x", vram[0],  vram[1],  vram[2],  vram[3]);
			$display("%x %x %x %x", vram[4],  vram[5],  vram[6],  vram[7]);
			$display("%x %x %x %x", vram[8],  vram[9],  vram[10], vram[11]);
			$display("%x %x %x %x", vram[12], vram[13], vram[14], vram[15]);
		end
	end
	
	always @ (posedge clk) begin
		if (rst) begin
			after_first_vsync <= 0;
		end else begin
			if (de_out && after_first_vsync) begin
				vram[y_out * XRES + x_out] <= rgb_out;
			end
		end
	end
	
	always begin
		#5 clk = ~clk;
	end
	
	initial begin
		$dumpfile("hdmi_encode_tb.vcd");
		$dumpvars;
		rst = 0;
		clk = 0;
		frame_count = 0;
		after_first_vsync = 1;
		
		#20 rst = 1;
		#20 rst = 0;
	
		#10000 $finish;
	end
endmodule
