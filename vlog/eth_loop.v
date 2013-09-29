`timescale 1ns / 1ps

// ethernet loopback module
// by liam davey (29/4/11)
//

module eth_loop (
	input clk,
	input rst,
	
	output reg rd_en_out,
	input rd_end_in,
	input [8:0] rd_d_in,
	input rd_empty_in,
	
	output reg wr_chk_out,
	output reg wr_clr_out,
	output reg wr_en_out,
	output reg [8:0] wr_d_out,
	input wr_full_in
);
	
	reg [1:0] state;
	reg [1:0] sub_state;
	reg [5:0] bl;
	
	reg [47:0] mac_src, mac_dst;
	reg [15:0] type, length;
	
	localparam STATE_IDLE = 2'd0;
	localparam STATE_HEADER = 2'd1;
	localparam STATE_DATA = 2'd2;

	always @ (posedge clk) begin
		if (rst) begin
			
			state <= STATE_IDLE;
			sub_state <= 0;
			
			wr_chk_out <= 0;
			wr_clr_out <= 0;
			wr_en_out <= 0;
			wr_d_out <= 0;
			
			rd_en_out <= 0;
			
			mac_src <= 0;
			mac_dst <= 0;
			type <= 0;
			
		end else begin	
			case (state)
				// wait for start of frame flag
				STATE_IDLE: begin
					if (!rd_empty) begin
						state <= STATE_HEADER;
						sub_state <= 0;
						count <= 0;
					end
					rd_en_out <= 0;
					wr_en_out <= 0;
				end
				
				// read frame ethernet header
				STATE_HEADER: begin
					case (sub_state)
						2'd0: begin
							// get the 48 bit source mac
							mac_src <= rd_d_in[63:16];
							mac_dst[47:32] <= rd_d_in[15:0];
							sub_state <= 2'd1;
						end
						
						2'd1: begin
							// get the 48 bit destination mac
							mac_dst[31:0] <= sr[63:32];
							type <= rd_d_in[31:16];
							length <= rd_d_in[15:0];
							sub_state <= 2'd0;
							state <= STATE_DATA;
						end
					endcase
					rd_en_out <= 1;
				end
				
				STATE_DATA: begin
					if (!mcb_wr_full_in) begin
						mcb_wr_data_out <= rd_d_in;
						mcb_wr_en_out <= 1;
						rd_en_out <= 1;
						bl <= bl - 6'd1;
					end else begin
						mcb_wr_en_out <= 0;
					end
					
					// set the mcb command enable signal when all the data
					// has been written to the fifo
					if (!mcb_wr_full_in && (bl == 6'd0)) begin
						mcb_cmd_en_out <= 1;
						state <= STATE_IDLE;
					end else
						mcb_cmd_en_out <= 0;
					
					bl <= bl - 6'd1;
				end
				
				// read data from mcb read fifo and write to the ethernet fifo
				STATE_MCB_READ: begin
					mcb_cmd_en_out <= !sub_state[0];
					sub_state[0] <= 1;
					
					// read data from mcb read fifo when it is not empty
					// and there is space in the ethernet write fifo
					mcb_rd_en_out <= !mcb_rd_empty && !wr_full_in;
					
					// when mcb_rd_en_out is asserted it means that
					// mcb_rd_data_in has valid data
					if (mcb_rd_en_out) begin
						wr_d_out <= mcb_rd_data_in;
						// go to the idle state after all words in the burst
						// have been read
						if (bl == 6'd0)
							state <= STATE_IDLE;
						bl <= bl - 6'd1;
					end
					wr_en_out <= mcb_rd_en_out;
					wr_chk_out <= mcb_rd_en_out && (bl == 6'b0);
				end
			endcase
		end
	end

endmodule
