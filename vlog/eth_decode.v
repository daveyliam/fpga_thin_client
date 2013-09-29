`timescale 1ns / 1ps

// ethernet decode module
// by liam davey (30/4/11)
//
// decodes incoming ethernet frames.
// frame data read from the eth rx fifo.
// dram data written to the dram fifo.
// frame acknowledgement messages and replies 
// written to the ack fifo.
//
// will break if a frame less than 24 bytes in
// length is read from the FIFO.
//

module eth_decode #(
	parameter MAC = 48'h010203040506,
	parameter TYPE = 16'hffff
) (
	input clk,
	input rst,
	
	// aux out, auxilliary signals which
	// can be set by incoming packets
	output reg [15:0] aux_out,
	
	// debug mode, sends an ack frame for
	// every frame received (normally only
	// ping frames are acknowledged)
	input debug_mode_in,
	
	// control fifo read port
	output reg ctl_rd_en_out,
	input [15:0] ctl_rd_d_in,
	input ctl_rd_empty_in,
	
	// data fifo read port
	output reg data_rd_en_out,
	input [63:0] data_rd_d_in,
	input data_rd_empty_in,
	
	// acknowledge fifo write port
	output reg ack_wr_en_out,
	output reg [63:0] ack_wr_d_out,
	input ack_wr_full_in,
	
	// dram mcb interface
	output reg mcb_cmd_en_out,
	output [2:0] mcb_cmd_instr_out,
	output [5:0] mcb_cmd_bl_out,
	output reg [29:0] mcb_cmd_byte_addr_out,
	input mcb_cmd_empty_in,
	input mcb_cmd_full_in,
	
	output reg mcb_wr_en_out,
	output [7:0] mcb_wr_mask_out,
	output reg [63:0] mcb_wr_data_out,
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
	input [6:0] mcb_rd_count_in
);

	assign mcb_wr_mask_out = 8'h0;
	assign mcb_rd_en_out = 1'b0;
	assign mcb_cmd_instr_out = 3'b000;	// write instruction
	assign mcb_cmd_bl_out = 6'h0;			// burst length of one
	
	localparam MAC_BROADCAST = 48'hffffffffffff;
	
	wire [47:0] mac = MAC;
	wire [47:0] mac_brd = MAC_BROADCAST;
	
	// states for the decode state machine
	
	reg [2:0] state;
	
	localparam STATE_IDLE = 3'd0;
	localparam STATE_HEADER_0 = 3'd1;
	localparam STATE_HEADER_1 = 3'd2;
	localparam STATE_DATA_ADDRESS = 3'd3;
	localparam STATE_DATA = 3'd4;
	localparam STATE_MCB_WRITE = 3'd5;
	localparam STATE_ACK = 3'd6;
	
	reg data_end;
	
	reg [47:0] mac_src;
	reg frame_is_data, frame_is_ping;
	
	reg [11:0] data_length;
	reg [11:0] frame_length;
	
	wire [15:0] status_next = {5'h0, mcb_cmd_empty_in, mcb_wr_full_in, mcb_wr_underrun_in, 1'h0, mcb_wr_count_in};
	reg [15:0] status;
	
	reg [11:0] count;
	
	// sync debug_mode
	reg debug_mode_r, debug_mode;
	always @ (posedge clk or posedge rst)
		{debug_mode, debug_mode_r} <= (rst) ? 2'b00 : {debug_mode_r, debug_mode_in};
	
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			state <= STATE_IDLE;
			
			aux_out <= 0;
			
			ctl_rd_en_out <= 0;
			data_rd_en_out <= 0;
			
			mcb_cmd_en_out <= 0;
			mcb_cmd_byte_addr_out <= 0;
			mcb_wr_en_out <= 0;
			mcb_wr_data_out <= 0;
			
			ack_wr_en_out <= 0;
			ack_wr_d_out <= 0;
			
			mac_src <= MAC_BROADCAST;
			frame_is_data <= 0;
			frame_is_ping <= 0;
			frame_length <= 0;
			data_length <= 0;
			data_end <= 0;
			count <= 0;
			
		end else begin
		
			status <= status_next;
			
			case (state)
				// wait for data in the control fifo.
				// if bit 16 is high then the frame is
				// invalid
				STATE_IDLE: begin
					if (!ctl_rd_empty_in && ctl_rd_en_out) begin
						state <= STATE_HEADER_0;
						ctl_rd_en_out <= 0;
                        // frame length in 64 bit words
						frame_length <= ctl_rd_d_in[14:3];
						frame_is_data <= !ctl_rd_d_in[15];
						frame_is_ping <= !ctl_rd_d_in[15];
					end else
						ctl_rd_en_out <= !ctl_rd_empty_in;
					
					count <= 0;
					data_length <= 0;
					mcb_wr_en_out <= 0;
					ack_wr_en_out <= 0;
					data_end <= 0;
				end
				
				STATE_HEADER_0: begin
					if (!data_rd_empty_in && data_rd_en_out) begin
						if (data_rd_d_in[63:16] != mac)
							frame_is_data <= 0;
						if (data_rd_d_in[63:16] != mac_brd)
							frame_is_ping <= 0;
						mac_src[47:32] <= data_rd_d_in[15:0];
						state <= STATE_HEADER_1;
						count <= count + 1'd1;
						data_rd_en_out <= 0;
					end else
						data_rd_en_out <= !data_rd_empty_in;
				end
				
				STATE_HEADER_1: begin
					if (!data_rd_empty_in && data_rd_en_out) begin
						mac_src[31:0] <= data_rd_d_in[63:32];
						if (data_rd_d_in[31:16] != TYPE) begin
							frame_is_ping <= 0;
							frame_is_data <= 0;
						end
						state <= STATE_DATA_ADDRESS;
						count <= count + 1'd1;
						data_length <= data_rd_d_in[11:0];
						data_rd_en_out <= 0;
					end else
						data_rd_en_out <= !data_rd_empty_in;
				end
				
				STATE_DATA_ADDRESS: begin
					if (!data_rd_empty_in && data_rd_en_out) begin
						state <= STATE_DATA;
						// data_rd_d_in[63:48] is the mask used to select which bits
						// in aux to update with data_rd_d_in[47:32]
						aux_out <= (^data_rd_d_in[63:48] & aux_out) | (data_rd_d_in[63:48] & data_rd_d_in[47:32]);
						count <= count + 1'd1;
						data_rd_en_out <= 0;
					end else
						data_rd_en_out <= !data_rd_empty_in;
				end

				STATE_DATA: begin
					// when data_rd_en_out is high and data_rd_empty is low
					// it means that valid data is ready on data_rd_d_in
					if (!data_rd_empty_in && data_rd_en_out) begin
						state <= STATE_MCB_WRITE;
						count <= count + 1'd1;
						if (count == data_length)
							data_end <= 1;
						mcb_wr_data_out <= data_rd_d_in;
						// do not set rd_en_out in case the mcb fifo is full
						data_rd_en_out <= 0;
					end else
						// if valid data is not present on data_rd_d_in this cycle,
						// set data_rd_en_out if there is still data remaining in
						// the fifo so that data will be available next cycle.
						data_rd_en_out <= !data_rd_empty_in;
					mcb_wr_en_out <= 0;
				end
					
				STATE_MCB_WRITE: begin
					if (frame_is_data && !data_end) begin
						if (!mcb_wr_full_in && !mcb_cmd_full_in) begin
							mcb_wr_en_out <= 1;
							state <= (count == frame_length) ? STATE_ACK : STATE_DATA;
						end else
							mcb_wr_en_out <= 0;
					end else begin
						state <= (count == frame_length) ? STATE_ACK : STATE_DATA;
						mcb_wr_en_out <= 0;
					end
				end
				
				default: begin		// STATE_ACK
					if (!ack_wr_full_in) begin
						if (frame_is_ping || (frame_is_data && debug_mode)) begin
							ack_wr_d_out <= {mac_src, status};
							ack_wr_en_out <= 1;
						end
						state <= STATE_IDLE;
					end else
						ack_wr_en_out <= 0;
					
					mcb_wr_en_out <= 0;
				end
				
			endcase
			
			// read in the memory address when in the right state, or increment
			// after the command fifo written to
			if ((state == STATE_DATA_ADDRESS))
				mcb_cmd_byte_addr_out <= {data_rd_d_in[29:0]};
			else if (mcb_cmd_en_out)
				mcb_cmd_byte_addr_out <= mcb_cmd_byte_addr_out + 30'd8;
			
			// write to the command fifo just after data has been written
			// to the dram data fifo
			mcb_cmd_en_out <= mcb_wr_en_out;
		end
	end

endmodule
