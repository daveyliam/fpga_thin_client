`timescale 1ns / 1ps
// ethernet mac receiver module
// by liam davey (7/4/11)
//
// this module consists of two parts, the first part connects to the
// actual ethernet pins and hence runs at eth_rx_clk clock rate.
// it removes the preamble and writes the frame data to an asynchronous
// fifo (9 bit port, 1 bit used to flag control bytes).
// the read side of the fifo connects to the other part of the module,
// which transfers the frame to block ram and checks the FCS (CRC32).
// if the CRC is valid the block is clocked out (similar to a fifo).
//
// the eth_tx_d and eth_rx_d 8 bit ports are in little endian bit order
// (bit 7 is msb, bit 0 is lsb) so will need to be assigned in reverse
// to the external ethernet pins.
// this is because the ethernet phy expects to receive octets in big
// endian order (bit 7 lsb, bit 0 msb).
// 

module eth_mac_rx (
	input clk,
	input rst,
	
	input eth_rx_clk_in,
	input [7:0] eth_rx_d_in,
	input eth_rx_err_in,
	input eth_rx_dv_in,
	
	output reg wr_en_out,
	output reg [10:0] wr_addr_out,
	output [7:0] wr_d_out,

	output reg done_out,
	input full_in
);

	localparam STATE_IDLE = 2'd0;
	localparam STATE_PREAMBLE = 2'd1;
	localparam STATE_DATA = 2'd2;
	localparam STATE_ERR = 2'd3;
	
	reg [1:0] state;

	reg fifo_wr_en, fifo_rd_en;
	reg [8:0] fifo_wr_d;
	wire [8:0] fifo_rd_d;
	wire fifo_full, fifo_empty;
	
	fifo_9x16 eth_rx_fifo (
	  .rst(rst),
	  .wr_clk(eth_rx_clk_in),
	  .rd_clk(clk),
	  .din(fifo_wr_d),
	  .wr_en(fifo_wr_en),
	  .rd_en(fifo_rd_en),
	  .dout(fifo_rd_d),
	  .full(fifo_full),
	  .empty(fifo_empty)
  );
  
	// the receiver state machine.
	// read data from eth rx pins and write to small async fifo.
	always @ (posedge eth_rx_clk_in or posedge rst) begin
		if (rst) begin
			state <= STATE_IDLE;
			fifo_wr_en <= 0;
			fifo_wr_d <= 0;
		end else begin
			case (state)
				// idle state
				// waits for the first byte of the preamble
				// enters the preamble state if a bram buffer is free,
				// otherwise go to the error state (drop frame)
				STATE_IDLE: begin
					fifo_wr_en <= 0;
					if (eth_rx_dv_in && !eth_rx_err_in && (eth_rx_d_in == 8'hAA))
						state <= RX_STATE_PREAMBLE;
				end
				
				// preamble state
				// reads the 7 bytes of preamble before going to the
				// next state when the start of frame byte is received
				STATE_PREAMBLE: begin
					if (eth_rx_err_in || !eth_rx_dv_in)
						state <= STATE_ERR;
					else if (eth_rx_d_in == 8'haa)
						state <= STATE_PREAMBLE;
					else if (eth_rx_d_in == 8'hab && !fifo_full) begin
						// 0xAB is the start of frame field
						// when it is received go to the data state
						state <= STATE_DATA;
						// send start of frame control byte
						fifo_wr_en <= 1;
						fifo_wr_d <= 9'h100;
					end else
						state <= STATE_ERR;
				end
				
				// data state
				STATE_DATA: begin
					if (eth_rx_err_in || fifo_full) begin
						state <= STATE_ERR;
						fifo_wr_en <= 0;
					end else if (!eth_rx_dv_in) begin
						state <= STATE_IDLE;
						// end of frame control byte
						fifo_wr_d <= 9'h101;
						fifo_wr_en <= 1;
					end else begin
						fifo_wr_d <= {1'b0, eth_rx_d_in};
						fifo_wr_en <= 1;
					end
				end
				
				// error state
				STATE_ERR: begin
					// wait for dv and err to go low before returning
					// to idle state.
					// also wait for space in fifo so that an error
					// control byte can be written
					if (!eth_rx_dv_in && !eth_rx_err_in && !fifo_full) begin
						state <= STATE_IDLE;
						// error control byte
						fifo_wr_d <= 9'h1ff;
						fifo_wr_en <= 1;
					end
				end
			endcase
		end
	end
	
	
	reg [31:0] crc;
	wire crc_ok_next = (crc == 32'hc704dd7b);
	reg crc_ok, error, eof;
	reg [7:0] length_lower;
	
	wire fifo_rdy = !full_in && !fifo_rd_empty;
	wire ctl_rdy = fifo_rdy && fifo_rd_d[8];
	wire data_rdy = fifo_rdy && !fifo_rd_d[8];

	// the receiver state machine.
	// reads data from the async fifo and writes to bram
	always @ (posedge clk or posedge rst) begin

		if (rst) begin
			fifo_rd_en <= 0;
			done_out <= 0;
			wr_en_out <= 0;
			wr_addr_out <= 11'd2;
			wr_d_out <= 0;
			crc <= 32'hffffffff;
			crc_ok <= 0;
			error <= 0;
			length_lower <= 0;
			eof <= 0;
		
		end else begin
			
			// eof state
			// the lower byte of the frame length is written
			// in this state.
			if (eof) begin
				fifo_rd_en <= 0;
				done_out <= 1;
				
				wr_addr_out <= 11'd1;
				wr_d_out <= length_lower;
				eof <= 0;
				
			end else if (ctl_rdy) begin
				fifo_rd_en <= 1;
				done_out <= 0;
				
				case (fifo_rd_d[1:0])
				
					// start of frame
					2'b00: begin
						done_out <= 0;
						wr_en_out <= 0;
						wr_addr_out <= 11'd2;
						wr_d_out <= 0;
						crc <= 32'hffffffff;
						crc_ok <= 0;
						error <= 0;
					end
					
					// end of frame
					// if crc ok and no errors write upper byte of length
					// and go to eof state where lower byte is written
					2'b01: begin
						if (!error && crc_ok) begin
							eof <= 1;
							wr_en_out <= 1;
							wr_addr_out <= 11'd0;
							wr_d_out[7:3] <= 5'h00;
							{wr_d_out[2:0], length_lower} <= wr_addr_out - 11'd16;
						end
					end
					
					// error or invalid control byte
					default: begin
						error <= 1;
						wr_en_out <= 0;
					end
				endcase
			
			end else if (data_rdy) begin
				fifo_rd_en <= 1;
				done_out <= 0;
				
				// top 16 bytes of bram will be:
				// | 0:1          | 2:7     | 8:13    | 14:15 |
				// | frame_length | mac_src | mac_dst | type  |
				
				wr_addr_out <= wr_addr_out + 11'd1;
				wr_d_out <= fifo_rd_d;
				wr_en_out <= 1;
				
				// calculate the crc of the received data
				crc[0] <= fifo_rd_d[6] ^ fifo_rd_d[0] ^ crc[24] ^ crc[30];
				crc[1] <= fifo_rd_d[7] ^ fifo_rd_d[6] ^ fifo_rd_d[1] ^ fifo_rd_d[0] ^ crc[24] ^ crc[25] ^ crc[30] ^ crc[31];
				crc[2] <= fifo_rd_d[7] ^ fifo_rd_d[6] ^ fifo_rd_d[2] ^ fifo_rd_d[1] ^ fifo_rd_d[0] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[30] ^ crc[31];
				crc[3] <= fifo_rd_d[7] ^ fifo_rd_d[3] ^ fifo_rd_d[2] ^ fifo_rd_d[1] ^ crc[25] ^ crc[26] ^ crc[27] ^ crc[31];
				crc[4] <= fifo_rd_d[6] ^ fifo_rd_d[4] ^ fifo_rd_d[3] ^ fifo_rd_d[2] ^ fifo_rd_d[0] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30];
				crc[5] <= fifo_rd_d[7] ^ fifo_rd_d[6] ^ fifo_rd_d[5] ^ fifo_rd_d[4] ^ fifo_rd_d[3] ^ fifo_rd_d[1] ^ fifo_rd_d[0] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31];
				crc[6] <= fifo_rd_d[7] ^ fifo_rd_d[6] ^ fifo_rd_d[5] ^ fifo_rd_d[4] ^ fifo_rd_d[2] ^ fifo_rd_d[1] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31];
				crc[7] <= fifo_rd_d[7] ^ fifo_rd_d[5] ^ fifo_rd_d[3] ^ fifo_rd_d[2] ^ fifo_rd_d[0] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[31];
				crc[8] <= fifo_rd_d[4] ^ fifo_rd_d[3] ^ fifo_rd_d[1] ^ fifo_rd_d[0] ^ crc[0] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28];
				crc[9] <= fifo_rd_d[5] ^ fifo_rd_d[4] ^ fifo_rd_d[2] ^ fifo_rd_d[1] ^ crc[1] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29];
				crc[10] <= fifo_rd_d[5] ^ fifo_rd_d[3] ^ fifo_rd_d[2] ^ fifo_rd_d[0] ^ crc[2] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[29];
				crc[11] <= fifo_rd_d[4] ^ fifo_rd_d[3] ^ fifo_rd_d[1] ^ fifo_rd_d[0] ^ crc[3] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28];
				crc[12] <= fifo_rd_d[6] ^ fifo_rd_d[5] ^ fifo_rd_d[4] ^ fifo_rd_d[2] ^ fifo_rd_d[1] ^ fifo_rd_d[0] ^ crc[4] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30];
				crc[13] <= fifo_rd_d[7] ^ fifo_rd_d[6] ^ fifo_rd_d[5] ^ fifo_rd_d[3] ^ fifo_rd_d[2] ^ fifo_rd_d[1] ^ crc[5] ^ crc[25] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[30] ^ crc[31];
				crc[14] <= fifo_rd_d[7] ^ fifo_rd_d[6] ^ fifo_rd_d[4] ^ fifo_rd_d[3] ^ fifo_rd_d[2] ^ crc[6] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30] ^ crc[31];
				crc[15] <= fifo_rd_d[7] ^ fifo_rd_d[5] ^ fifo_rd_d[4] ^ fifo_rd_d[3] ^ crc[7] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[31];
				crc[16] <= fifo_rd_d[5] ^ fifo_rd_d[4] ^ fifo_rd_d[0] ^ crc[8] ^ crc[24] ^ crc[28] ^ crc[29];
				crc[17] <= fifo_rd_d[6] ^ fifo_rd_d[5] ^ fifo_rd_d[1] ^ crc[9] ^ crc[25] ^ crc[29] ^ crc[30];
				crc[18] <= fifo_rd_d[7] ^ fifo_rd_d[6] ^ fifo_rd_d[2] ^ crc[10] ^ crc[26] ^ crc[30] ^ crc[31];
				crc[19] <= fifo_rd_d[7] ^ fifo_rd_d[3] ^ crc[11] ^ crc[27] ^ crc[31];
				crc[20] <= fifo_rd_d[4] ^ crc[12] ^ crc[28];
				crc[21] <= fifo_rd_d[5] ^ crc[13] ^ crc[29];
				crc[22] <= fifo_rd_d[0] ^ crc[14] ^ crc[24];
				crc[23] <= fifo_rd_d[6] ^ fifo_rd_d[1] ^ fifo_rd_d[0] ^ crc[15] ^ crc[24] ^ crc[25] ^ crc[30];
				crc[24] <= fifo_rd_d[7] ^ fifo_rd_d[2] ^ fifo_rd_d[1] ^ crc[16] ^ crc[25] ^ crc[26] ^ crc[31];
				crc[25] <= fifo_rd_d[3] ^ fifo_rd_d[2] ^ crc[17] ^ crc[26] ^ crc[27];
				crc[26] <= fifo_rd_d[6] ^ fifo_rd_d[4] ^ fifo_rd_d[3] ^ fifo_rd_d[0] ^ crc[18] ^ crc[24] ^ crc[27] ^ crc[28] ^ crc[30];
				crc[27] <= fifo_rd_d[7] ^ fifo_rd_d[5] ^ fifo_rd_d[4] ^ fifo_rd_d[1] ^ crc[19] ^ crc[25] ^ crc[28] ^ crc[29] ^ crc[31];
				crc[28] <= fifo_rd_d[6] ^ fifo_rd_d[5] ^ fifo_rd_d[2] ^ crc[20] ^ crc[26] ^ crc[29] ^ crc[30];
				crc[29] <= fifo_rd_d[7] ^ fifo_rd_d[6] ^ fifo_rd_d[3] ^ crc[21] ^ crc[27] ^ crc[30] ^ crc[31];
				crc[30] <= fifo_rd_d[7] ^ fifo_rd_d[4] ^ crc[22] ^ crc[28] ^ crc[31];
				crc[31] <= fifo_rd_d[5] ^ crc[23] ^ crc[29];
				
				crc_ok <= crc_ok_next;
				
			end else begin
				// fifo empty or bram full
				fifo_rd_en <= 0;
				done_out <= 0;
			end
		end
	end
endmodule
