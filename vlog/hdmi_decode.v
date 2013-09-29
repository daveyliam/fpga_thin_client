// hdmi_decode module
// by liam davey 11/03/11
// used for simulation to decode 3 tmds channels and create hsync,
// vsync, de output signals and rgb pixel data from them.

module hdmi_decode (
	input clk,
	input rst,
	input [9:0] tmds_c0_in,
	input [9:0] tmds_c1_in,
	input [9:0] tmds_c2_in,
	output reg vsync_out,
	output reg hsync_out,
	output reg de_out,
	output reg [11:0] x_out,
	output reg [11:0] y_out,
	output reg [23:0] rgb_out,
	output wire signed [7:0] cnt_c0_out,
	output wire signed [7:0] cnt_c1_out,
	output wire signed [7:0] cnt_c2_out
);

	wire [23:0] rgb;
	wire vsync, hsync, de;
	
	// decode module to decode each tmds channel
	tmds_decode u_tmds_decode_c0 (
		.clk(clk),
		.rst(rst),
		.q_in(tmds_c0_in),
		.d(rgb[7:0]),
		.de(de),
		.c0(vsync),
		.c1(hsync),
		.cnt(cnt_c0_out));
	
	tmds_decode u_tmds_decode_c1 (
		.clk(clk),
		.rst(rst),
		.q_in(tmds_c1_in),
		.d(rgb[15:8]),
		.de(),
		.c0(),
		.c1(),
		.cnt(cnt_c1_out));
		
	tmds_decode u_tmds_decode_c2 (
		.clk(clk),
		.rst(rst),
		.q_in(tmds_c2_in),
		.d(rgb[23:16]),
		.de(),
		.c0(),
		.c1(),
		.cnt(cnt_c2_out));
	
	reg line_is_active;
	reg hsync_last, vsync_last;
	reg [11:0] x_out_r;
	
	always @ (posedge clk) begin
		if (rst) begin
			x_out <= 0;
			x_out_r <= 0;
			y_out <= 0;
			hsync_last <= 0;
			vsync_last <= 0;
			rgb_out <= 0;
			hsync_out <= 0;
			vsync_out <= 0;
			de_out <= 0;
		end else begin
			if (vsync_last && !vsync) begin
				y_out <= 0;
			end else begin
				if (hsync_last && !hsync) begin
					x_out_r <= 0;
					if (line_is_active) begin
						y_out <= y_out + 1;
						line_is_active <= 1'b0;
					end
				end else begin
					if (de) begin
						line_is_active <= 1'b1;
						x_out_r <= x_out_r + 1;
					end
				end
			end
			x_out <= x_out_r;
			hsync_last <= hsync;
			vsync_last <= vsync;
			rgb_out <= rgb;
			hsync_out <= hsync;
			vsync_out <= vsync;
			de_out <= de;
		end
	end
	
endmodule
