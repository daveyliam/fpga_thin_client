`timescale 1ns / 1ps

// dram mcb interface module
// by liam davey (30/4/11)
//
// reads data and addresses from a fifo and
// writes them to the dram mcb fifo's.
//

module eth_mcb_if (
	input clk,
	input rst,
	
	output reg rd_en_out,
	input [35:0] rd_d_in,
	input rd_empty_in,
	
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
	assign mcb_cmd_bl_out = 6'h0;	// burst length of one
	
	reg rd_rdy;
	//reg mcb_cmd_en;
	reg toggle;

	always @ (posedge clk) begin
		if (rst) begin
			mcb_cmd_byte_addr_out <= 0;
			mcb_wr_en_out <= 0;
			mcb_wr_data_out <= 0;
			
			rd_en_out <= 0;
			rd_rdy <= 0;
			//mcb_cmd_en <= 0;
			toggle <= 0;
			
		end else begin
		
			rd_rdy <= rd_en_out;
			//mcb_cmd_en_out <= mcb_cmd_en;
		
			if (!mcb_wr_full_in && !mcb_cmd_full_in) begin
				rd_en_out <= !rd_empty_in;
				if (rd_rdy && rd_en_out) begin
					if (rd_d_in[33]) begin
						// bit 33 is start of frame marker
						// the entry contains the address to write
						// following data entries to
						mcb_wr_en_out <= 0;
						toggle <= 0;
						
					end else begin
						// 'toggle' select whether to write to the upper
						// or lower 32 bits of the write fifo data register.
						// the data is only actually written to the fifo
						// when the lower 32 bits are replaced.
						if (!toggle) begin
							mcb_wr_data_out[63:32] <= rd_d_in[31:0];
							mcb_wr_data_out[31:0] <= 0;
							mcb_wr_en_out <= 0;
						end else begin
							mcb_wr_data_out[31:0] <= rd_d_in[31:0];
							mcb_wr_en_out <= 1;
						end
						toggle <= !toggle;
					end
					
				end else begin
					// if the mcb write and command fifo's are ready but
					// the rx fifo is either empty or not ready
					mcb_wr_en_out <= 0;
				end
				
			end else begin
				// if the mcb write or command fifo's are full
				rd_en_out <= 0;
				mcb_wr_en_out <= 0;
			end
			
			if (rd_d_in[33])
				mcb_cmd_byte_addr_out <= rd_d_in[29:0];
			else if (mcb_cmd_en_out)
				mcb_cmd_byte_addr_out <= mcb_cmd_byte_addr_out + 29'd8;
			
			mcb_cmd_en_out <= mcb_wr_en_out;
		end
	end
endmodule
