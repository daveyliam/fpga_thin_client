`timescale 1ns / 1ps

// asynchronous fifo for ethernet module
// by liam davey (28/04/11)
//
// an asynchronous fifo that only allows data to be read
// up to a 'checkpoint'.
// the 'clr' signal when asserted clears data to the point
// where the checkpoint was set.
//

module eth_fifo (
	input rst,
	
	input rd_clk,
	input rd_en_in,
	output [35:0] rd_d_out,
	output rd_empty_out,
	
	input wr_clk,
	input wr_en_in,
	input wr_chk_in,
	input wr_clr_in,
	input [35:0] wr_d_in,
	output wr_full_out
);

	localparam ADDRESS_WIDTH = 11;
	
	reg [ADDRESS_WIDTH - 1:0] tail, head, head_chk;
	wire do_write, do_clear, do_read;
	
	bram_36_36_8k bram (
		.clka(wr_clk),
		.wea(do_write),
		.addra(head),
		.dina(wr_d_in),
		
		.clkb(rd_clk),
		.addrb(tail),
		.doutb(rd_d_out)
	);
	
	// convert to gray encoding
	wire [ADDRESS_WIDTH - 1:0] head_gray = {head[ADDRESS_WIDTH - 1], head[ADDRESS_WIDTH - 1:1] ^ head[ADDRESS_WIDTH - 2:0]};
	wire [ADDRESS_WIDTH - 1:0] head_chk_gray = {head_chk[ADDRESS_WIDTH - 1], head_chk[ADDRESS_WIDTH - 1:1] ^ head_chk[ADDRESS_WIDTH - 2:0]};
	wire [ADDRESS_WIDTH - 1:0] tail_gray = {tail[ADDRESS_WIDTH - 1], tail[ADDRESS_WIDTH - 1:1] ^ tail[ADDRESS_WIDTH - 2:0]};
	
	// check if head and tail equal (across clock domains!)
	wire equal = head_gray == tail_gray;
	wire equal_chk = head_chk_gray == tail_gray;
	
	// empty status depends on the saved head address while the full
	// status depends on the temporary head address
	//
	// going empty:
	// h[8:7] t[8:7] |  gray
	//     00     11 | 00 10
	//     01     00 | 01 00
	//     10     01 | 11 01
	//     11     10 | 10 11
	//
	// going full:
	// h[8:7] t[8:7] |  gray
	//     00     01 | 00 01
	//     01     10 | 01 11
	//     10     11 | 11 10
	//     11     00 | 10 00
	//
	
	wire [3:0] quadrant = 		{head_gray[ADDRESS_WIDTH - 1:ADDRESS_WIDTH - 2],
										 tail_gray[ADDRESS_WIDTH - 1:ADDRESS_WIDTH - 2]};
	wire [3:0] quadrant_chk = 	{head_chk_gray[ADDRESS_WIDTH - 1:ADDRESS_WIDTH - 2],
										 tail_gray[ADDRESS_WIDTH - 1:ADDRESS_WIDTH - 2]};
	
	reg status_rd, status_wr;
	
	wire wr_full = status_wr && equal;
	wire rd_empty = !status_rd && equal_chk;
	
	assign wr_full_out = wr_full;
	assign rd_empty_out = rd_empty;
	
	assign do_write = (wr_en_in && !wr_full && !wr_clr_in);
	assign do_read = (rd_en_in && !rd_empty);
	
	// write port
	always @ (posedge wr_clk or posedge rst) begin
		if (rst) begin
			head <= 0;
			head_chk <= 0;
			status_wr <= 0;
			
		end else begin
		
			if (			(quadrant == 4'b0010) || 
							(quadrant == 4'b0100) ||
							(quadrant == 4'b1101) ||
							(quadrant == 4'b1011))
				status_wr <= 0;
			else if (	(quadrant == 4'b0001) || 
							(quadrant == 4'b0111) ||
							(quadrant == 4'b1110) ||
							(quadrant == 4'b1000))
				status_wr <= 1;
		
			//wr_full <= wr_full_next;
			
			if (wr_en_in && wr_chk_in)
				head_chk <= head + 1'd1;
				
			if (wr_en_in && wr_clr_in)
				head <= head_chk;
			else if (do_write)
				head <= head + 1'd1;
		end
	end
	
	// read port
	always @ (posedge rd_clk or posedge rst) begin
		if (rst) begin
			tail <= 0;
			status_rd <= 0;
		end else begin
		
			if (			(quadrant_chk == 4'b0010) || 
							(quadrant_chk == 4'b0100) ||
							(quadrant_chk == 4'b1101) ||
							(quadrant_chk == 4'b1011))
				status_rd <= 0;
			else if (	(quadrant_chk == 4'b0001) || 
							(quadrant_chk == 4'b0111) ||
							(quadrant_chk == 4'b1110) ||
							(quadrant_chk == 4'b1000))
				status_rd <= 1;
			
			if (do_read)
				tail <= tail + 1'd1;
		end
	end

endmodule
