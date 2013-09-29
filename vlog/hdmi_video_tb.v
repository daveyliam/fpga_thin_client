`timescale 1ns / 1ps

module hdmi_video_tb;

	reg clk;
	reg rst;
	reg test_mode_in;
	reg mcb_cmd_empty_in;
	reg mcb_cmd_full_in;
	reg mcb_wr_full_in;
	reg mcb_wr_empty_in;
	reg mcb_wr_error_in;
	reg mcb_wr_underrun_in;
	reg [6:0] mcb_wr_count_in;
	reg [63:0] mcb_rd_data_in;
	reg mcb_rd_full_in;
	reg mcb_rd_empty_in;
	reg mcb_rd_error_in;
	reg mcb_rd_overflow_in;
	reg [6:0] mcb_rd_count_in;

	wire mcb_cmd_en_out;
	wire [2:0] mcb_cmd_instr_out;
	wire [5:0] mcb_cmd_bl_out;
	wire [29:0] mcb_cmd_byte_addr_out;
	wire mcb_wr_en_out;
	wire [7:0] mcb_wr_mask_out;
	wire [63:0] mcb_wr_data_out;
	wire mcb_rd_en_out;
	wire vsync_out;
	wire hsync_out;
	wire de_out;
	wire [23:0] rgb_out;

	hdmi_video uut (
		.clk(clk), 
		.rst(rst), 
		.test_mode_in(test_mode_in),
		.dbuf_toggle_in(1'b0),
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
		.mcb_rd_count_in(mcb_rd_count_in), 
		.vsync_out(vsync_out), 
		.hsync_out(hsync_out), 
		.de_out(de_out), 
		.rgb_out(rgb_out)
	);
	
	always #5 clk = !clk;
	
	always @ (posedge clk) begin
	   if (mcb_rd_en_out)
			mcb_rd_data_in <= mcb_rd_data_in + 1'd1;
	end
	
	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 0;
		test_mode_in = 0;
		mcb_cmd_empty_in = 0;
		mcb_cmd_full_in = 0;
		mcb_wr_full_in = 0;
		mcb_wr_empty_in = 0;
		mcb_wr_error_in = 0;
		mcb_wr_underrun_in = 0;
		mcb_wr_count_in = 0;
		mcb_rd_data_in = 0;
		mcb_rd_full_in = 0;
		mcb_rd_empty_in = 0;
		mcb_rd_error_in = 0;
		mcb_rd_overflow_in = 0;
		mcb_rd_count_in = 0;

		// Wait 100 ns for global reset to finish
		#50 rst = 1;
		#50 rst = 0;

	end
      
endmodule

