`timescale 1ns / 1ps

// ps2 interface module
// by liam davey (01/05/2011)
//
// decodes ps2 data and writes it to a fifo

module ps2_if(
	input clk,
	input rst,
	input [4:0] btn,
	
	// ps2 mouse and keyboard
	input ps2_k_clk_in,
	input ps2_k_d_in,
	input ps2_m_clk_in,
	input ps2_m_d_in,
	
	// ps2 activity
	output reg ps2_k_act_out,
	output reg ps2_m_act_out,
	
	output reg wr_en_out,
	output reg [63:0] wr_d_out,
	input wr_full_in
);

	localparam COUNT_SIZE = 16;
	//localparam COUNT_SIZE = 3;

	reg [4:0] btn_r;
	reg [COUNT_SIZE:0] count;
	
	// when the button state needs to be written to the fifo
	// this will go high for one cycle
	reg btn_rdy;
	
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			count <= 0;
			btn_r <= 0;
			btn_rdy <= 0;
			
		end else begin
			if ((btn != btn_r) && (count[COUNT_SIZE])) begin
				btn_r <= btn;
				btn_rdy <= 1'b1;
				count <= 0;
			end else begin
				btn_rdy <= 1'b0;
				if (!count[COUNT_SIZE])
					count <= count + 1'd1;
			end
		end
	end
	
	// ps2 interface
	//  - 11 bit frames
	//    0  1  2  3  4  5  6  7  8  9 10
	//    0 D0 D1 D2 D3 D4 D5 D6 D7  P  1
	//  - data line should be read on the rising edge of clk
	//  - 1 start bit (always 0)
	//  - 8 data bits
	//  - 1 odd parity bit
	//  - 1 stop bit (always 1)
	//  - data bits transferred LSB first
	//
	// ps2 mouse
	//  - sends 3 11 bit frames
	//  - frame 1, status frame:
	//    0  1  2  3  4  5  6  7  8  9 10
	//    0  L  R  0  1 XS YS XV YV  P  1
	//  - L and R represent mouse button
	//  - XS and YS are the sign bits
	//  - XV and YV are overflow bits (if mouse moves too fast)
	//  - frame 2, x movement amount:
	//    0  1  2  3  4  5  6  7  8  9 10
	//    0 X0 X1 X2 X3 X4 X5 X6 X7  P  1
	//  - frame 3, y movement amount:
	//    0  1  2  3  4  5  6  7  8  9 10
	//    0 Y0 Y1 Y2 Y3 Y4 Y5 Y6 Y7  P  1
	//
	// ps2 keyboard
	// - sends between 2 and 4 11 bit frames
	// - control codes have the MSB set
	// - keyboard scan codes have the MSB clear
	// - transfers consist of one or more control codes
	//   followed by a single keyboard scan code e.g:
	//     E0 1A
	//     E0 F0 08
	//     E0 F0 E0 74
	//
	// this module sends ps2 mouse and keyboard data bytes
	// to the 64 bit wide fifo.
	// for the mouse the format is:
	//  byte 7 6 5 4 3 2      1          0
	//       0 0 0 0 0 status x-movement y-movement
	// for the keyboard the format is:
	//  byte 7 6 5 4 3       2       1       0
	//       0 0 0 0 control control control scan-code
	// where the control codes may be 0 if the transfer
	// was less than 4 bytes.
	//
	
	reg [3:0] ps2_m_bit_count;
	reg [1:0] ps2_m_frame_count;
	reg [7:0] ps2_m_clk_last;
	reg [23:0] ps2_m_r;
	reg ps2_m_rdy;
	
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			ps2_m_bit_count <= 0;
			ps2_m_frame_count <= 0;
			ps2_m_clk_last <= 0;
			ps2_m_r <= 0;
			ps2_m_rdy <= 0;
			ps2_m_act_out <= 0;
			
		end else begin
		
			ps2_m_clk_last <= {ps2_m_clk_last[6:0], ps2_m_clk_in};
			
			if (ps2_m_clk_last == 8'hf0) begin
				// on rising edge of ps2 clock signal
				case (ps2_m_bit_count)
					4'd0: begin
						// idle, waiting for start bit (0)
						ps2_m_bit_count <= (ps2_m_d_in) ? 4'd0 : 4'd1;
						ps2_m_rdy <= 1'b0;
					end
					4'd9: begin
						// odd parity bit
						// TODO: actually check this
						ps2_m_bit_count <= 4'd10;
						ps2_m_rdy <= 1'b0;
					end
					4'd10: begin
						// stop bit (1)
						ps2_m_bit_count <= (ps2_m_d_in) ? 4'd0 : 4'd10;
						// if this is the third byte need to write
						// ps2_m_r to the fifo
						if (ps2_m_frame_count == 2'd2) begin
							ps2_m_rdy <= 1'b1;
							ps2_m_frame_count <= 0;
						end else begin
							ps2_m_rdy <= 1'b0;
							ps2_m_frame_count <= ps2_m_frame_count + 1'd1;
						end
						ps2_m_act_out <= 1'b0;
					end
					default: begin
						// data bits
						// shift into ps2_m_r
						ps2_m_r <= {ps2_m_d_in, ps2_m_r[23:1]};
						ps2_m_bit_count <= ps2_m_bit_count + 1'd1;
						ps2_m_rdy <= 1'b0;
						ps2_m_act_out <= 1'b1;
					end
				endcase
			end else begin
				// if this is not a rising edge of ps2_m_clk
				ps2_m_rdy <= 1'b0;
			end
		end
	end
	
	reg [3:0] ps2_k_bit_count;
	reg [7:0] ps2_k_clk_last;
	reg [31:0] ps2_k_r;
	reg ps2_k_rdy;
	
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			ps2_k_bit_count <= 0;
			ps2_k_clk_last <= 0;
			ps2_k_r <= 0;
			ps2_k_rdy <= 0;
			ps2_k_act_out <= 0;
			
		end else begin
		
			ps2_k_clk_last <= {ps2_k_clk_last[6:0], ps2_k_clk_in};
			
			if (ps2_k_rdy) begin
				ps2_k_r <= 0;
				ps2_k_rdy <= 0;
			end else if (ps2_k_clk_last == 8'hf0) begin
				// on rising edge of ps2 clock signal
				case (ps2_k_bit_count)
					4'd0: begin
						// idle, waiting for start bit (0)
						ps2_k_bit_count <= (ps2_k_d_in) ? 4'd0 : 4'd1;
						ps2_k_rdy <= 1'b0;
					end
					4'd9: begin
						// odd parity bit
						// TODO: actually check this
						ps2_k_bit_count <= 4'd10;
						ps2_k_rdy <= 1'b0;
					end
					4'd10: begin
						// stop bit (1)
						ps2_k_bit_count <= (ps2_k_d_in) ? 4'd0 : 4'd10;
						// if this byte was a scan code, not a control code,
						// then assert ps2_k_rdy so that the ps2_k_r register
						// is written to the fifo
						ps2_k_rdy <= !ps2_k_r[31];
						ps2_k_act_out <= 1'b0;
					end
					default: begin
						// data bits
						// shift into ps2_k_r
						ps2_k_r <= {ps2_k_d_in, ps2_k_r[31:1]};
						ps2_k_bit_count <= ps2_k_bit_count + 1'd1;
						ps2_k_rdy <= 1'b0;
						ps2_k_act_out <= 1'b1;
					end
				endcase
			end else begin
				// if this is not a rising edge of ps2_k_clk
				ps2_k_rdy <= 1'b0;
			end
		end
	end
	
	// this block monitors the btn_rdy and ps2_rdy
	// signals so that when they go high the correct
	// data is written to the fifo.
	// if two rdy signals go high at the same time then
	// some data will be lost.
	
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			wr_en_out <= 0;
			wr_d_out <= 0;
		end else begin
			if (btn_rdy) begin
				wr_en_out <= 1;
				wr_d_out <= {59'h0, btn};
			end else if (ps2_k_rdy) begin
				wr_en_out <= 1;
				// switch around bytes to the proper order
				wr_d_out <= {32'h0, ps2_k_r[7:0], ps2_k_r[15:8], ps2_k_r[23:16], ps2_k_r[31:24]};
			end else if (ps2_m_rdy) begin
				wr_en_out <= 1;
				// switch around bytes to the proper order
				wr_d_out <= {40'h0, ps2_m_r[7:0], ps2_m_r[15:8], ps2_m_r[23:16]};
			end else begin
				wr_en_out <= 0;
				wr_d_out <= 0;
			end
		end
	end
	
endmodule
