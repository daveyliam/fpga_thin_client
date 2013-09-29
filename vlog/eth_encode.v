`timescale 1ns / 1ps

// ethernet frame encoder
// by liam davey (30/4/11)
//
// reads data from fifo's and constructs ethernet
// frames to send based on that data.
//

module eth_encode #(
	parameter MAC = 48'h010203040506,
	parameter TYPE = 16'habcd
) (
	input clk,
	input rst,
	
	output reg ack_rd_en_out,
	input [63:0] ack_rd_d_in,
	input ack_rd_empty_in,
	
	output reg ps2_rd_en_out,
	input [63:0] ps2_rd_d_in,
	input ps2_rd_empty_in,
	
	output reg ctl_wr_en_out,
	output reg [15:0] ctl_wr_d_out,
	input ctl_wr_full_in,
	
	output reg data_wr_en_out,
	output reg [63:0] data_wr_d_out,
	input data_wr_full_in
);

	localparam PS2_ACK_CODE = 16'h4321;

	reg select;
	
	reg [2:0] state;
	reg [6:0] count;
	
	reg [47:0] mac_dst;
	wire [47:0] mac_src = MAC;
	wire [15:0] type = TYPE;
	reg [15:0] status;
	
	localparam STATE_IDLE = 3'd0;
	localparam STATE_ACK = 3'd1;
	localparam STATE_HEADER_0 = 3'd2;
	localparam STATE_HEADER_1 = 3'd3;
	localparam STATE_DATA = 3'd4;
	localparam STATE_DATA_END = 3'd5;
	localparam STATE_END = 3'd6;

	
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			state <= STATE_IDLE;
			
			ack_rd_en_out <= 0;
			ps2_rd_en_out <= 0;
			
			mac_dst <= 48'hffffffffffff;
			status <= 16'h1234;
			
			ctl_wr_en_out <= 0;
			ctl_wr_d_out <= 0;
			data_wr_en_out <= 0;
			data_wr_d_out <= 0;
			
			select <= 0;
			count <= 0;
	
		end else begin
		
			case (state)
				// wait for one of the input fifo's to
				// become not empty
				STATE_IDLE: begin
					if (!select) begin
						if (!ack_rd_empty_in)
							state <= STATE_ACK;
						else
							select <= !select;
					end else begin
						if (!ps2_rd_empty_in)
							state <= STATE_HEADER_0;
						else
							select <= !select;
					end
					ack_rd_en_out <= 0;
					ps2_rd_en_out <= 0;
					data_wr_en_out <= 0;
					ctl_wr_en_out <= 0;
					count <= 0;
				end
				
				STATE_ACK: begin
					// shift in the 6 byte dest mac and two byte status from the ack fifo
					if (!ack_rd_empty_in && ack_rd_en_out) begin
						state <= STATE_HEADER_0;
						{mac_dst, status} <= ack_rd_d_in;
						ack_rd_en_out <= 0;
					end else
						ack_rd_en_out <= !ack_rd_empty_in;
				end
				
				STATE_HEADER_0: begin
					// write the frame header to the transmit data fifo
					if (!data_wr_full_in) begin
						data_wr_d_out <= {mac_dst, mac_src[47:32]};
						data_wr_en_out <= 1;
						count <= count + 1'd1;
						state <= STATE_HEADER_1;
					end else
						data_wr_en_out <= 0;
				end
				
				STATE_HEADER_1: begin
					// write the frame header to the transmit data fifo
					if (!data_wr_full_in) begin
						data_wr_d_out <= {mac_src[31:0], type, status};
						data_wr_en_out <= 1;
						count <= count + 1'd1;
						state <= (select) ? STATE_DATA : STATE_DATA_END;
					end else
						data_wr_en_out <= 0;
				end
				
				STATE_DATA: begin
					// get data from the ps2 fifo
					if (!ps2_rd_empty_in && ps2_rd_en_out) begin
						state <= STATE_DATA_END;
						data_wr_d_out <= ps2_rd_d_in;
						data_wr_en_out <= 1;
						count <= count + 1'd1;
						ps2_rd_en_out <= 0;
						status <= PS2_ACK_CODE;
					end else begin
						data_wr_en_out <= 0;
						ps2_rd_en_out <= !ps2_rd_empty_in && !data_wr_full_in;
					end
				end
				
				// STATE_DATA_END
				STATE_DATA_END: begin
					// write zero bytes to the tx fifo to satisfy
					// the minimum frame size requirement
					// when count[3] != 0 at least 64 bytes have
					// been written
					data_wr_d_out <= 9'h0;
					if (count[3]) begin
						state <= STATE_END;
						data_wr_en_out <= 0;
					end else begin
						if (!data_wr_full_in) begin
							data_wr_en_out <= 1;
							count <= count + 1'd1;
						end else
							data_wr_en_out <= 0;
					end
				end
				
				// STATE_END
				default: begin
					if (!ctl_wr_full_in) begin
						ctl_wr_d_out <= {11'h0, count};
						ctl_wr_en_out <= 1;
						state <= STATE_IDLE;
					end else
						ctl_wr_en_out <= 0;
				end
			endcase
		end
	end

endmodule
