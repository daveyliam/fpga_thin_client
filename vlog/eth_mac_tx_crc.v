`timescale 1ns / 1ps

// ethernet mac transmit module
// by liam davey (7/4/11)
//
// the eth_tx_d and eth_rx_d 8 bit ports are in little endian bit order
// (bit 7 is msb, bit 0 is lsb) so will need to be assigned in reverse
// to the external ethernet pins.
// this is because the ethernet phy expects to receive octets in big
// endian order (bit 7 lsb, bit 0 msb).
// 

module eth_mac_tx (
	input clk,
	input rst,
	
	// enable signal
	input start_in,
	
	output reg [7:0] eth_tx_d_out,
	output reg eth_tx_en_out,
	output reg eth_tx_err_out,
	
	// fifo interface
	output rd_en_out,
	input [8:0] rd_d_in,
	input rd_empty_in
);

	reg [2:0] count;
	reg [2:0] state;
	reg [31:0] crc;
	
	localparam STATE_IDLE = 3'd0;
	localparam STATE_PREAMBLE = 3'd1;
	localparam STATE_DATA = 3'd2;
	localparam STATE_FCS = 3'd3;
	localparam STATE_IFG1 = 3'd4;
	localparam STATE_IFG2 = 3'd5;
	localparam STATE_ERR = 3'd6;
	
	// the transmitter state machine.
	// reads data from the tx_bram, calculating the CRC32 checksum and
	// outputting the data on the eth_tx_d pins.
	
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			count <= 0;
			state <= STATE_IDLE;
			crc <= 32'hffffffff;
			eth_tx_en_out <= 0;
			eth_tx_d_out <= 0;
			eth_tx_err_out <= 0;
			rd_en_out <= 0;
		end else begin
			case (state)
				// idle state
				// waits for a tx_rdy signal to go high, indicating that
				// data in the bram section is ready
				STATE_IDLE: begin
					if (start_in && !rd_empty_in) begin
						if (rd_d_in[8] && rd_d_in[1:0] == 2'b11) begin
							// error flag
							state <= STATE_ERR;
						end else if (rd_d_in[8] && rd_d_in[1:0] == 2'b00) begin
							// start of frame flag
							state <= STATE_PREAMBLE;
							count <= 3'd0;
						end
						rd_en_out <= 1;
					end else begin
						rd_en_out <= 0;
					end
					crc <= 32'hffffffff;
					eth_tx_en_out <= 0;
					eth_tx_err_out <= 0;
				end
				
				STATE_PREAMBLE: begin
					rd_en_out <= 0;
					eth_tx_en_out <= 1;
					if (count == 3'd7) begin
						eth_tx_d_out <= 8'hab;
						state <= STATE_DATA;
					end else begin
						eth_tx_d_out <= 8'haa;
					end
					count <= count + 3'd1;
				end
				
				STATE_DATA: begin
					if (!rd_empty_in) begin
						if (rd_d_in[8] && (rd_d_in[1:0] == 2'b01)) begin
							// end of frame flag
							eth_tx_d_out <= ~crc[31:24];
							count <= 3'd5;
							state <= STATE_FCS;
						end else if (rd_d_in[8]) begin
							// error or start of frame flag
							state <= STATE_ERR;
						end else begin
							eth_tx_d_out <= rd_d_in[7:0];
						end
						rd_en_out <= 1;
					end else begin
						// if the fifo goes empty while data is being
						// output it is an error
						rd_en_out <= 0;
						state <= STATE_ERR;
					end
				end
				
				STATE_FCS: begin
					rd_en_out <= 0;
					case (count)
						3'd5: eth_tx_d_out <= ~crc[23:16];
						3'd6: eth_tx_d_out <= ~crc[15:8];
						3'd7: begin
							eth_tx_d_out <= ~crc[7:0];
							state <= STATE_IFG1;
						end
					endcase
					count <= count + 3'd1;
				end
				
				STATE_IFG1: begin
					eth_tx_en_out <= 0;
					eth_tx_err_out <= 0;
					eth_tx_d_out <= 0;
					
					if (count == 3'd7)
						state <= STATE_IFG2;
					count <= count + 3'd1;
				end
				
				STATE_IFG2: begin
					if (count == 3'd7)
						state <= STATE_IDLE;
					count <= count + 3'd1;
				end
				
				// error state, occurs when error control byte
				// received on fifo
				default: begin
					rd_en_out <= 0;
					state <= STATE_IFG1;
					eth_tx_err_out <= 1;
					count <= 0;
				end
				
			endcase
			
			// add data to CRC32 calculation
			// the checksum includes only the src and dst mac, the type field, and the data
			if ((state == STATE_DATA) && (!rd_empty_in)) begin
				crc[0] <= rd_d_in[6] ^ rd_d_in[0] ^ crc[24] ^ crc[30];
				crc[1] <= rd_d_in[7] ^ rd_d_in[6] ^ rd_d_in[1] ^ rd_d_in[0] ^ crc[24] ^ crc[25] ^ crc[30] ^ crc[31];
				crc[2] <= rd_d_in[7] ^ rd_d_in[6] ^ rd_d_in[2] ^ rd_d_in[1] ^ rd_d_in[0] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[30] ^ crc[31];
				crc[3] <= rd_d_in[7] ^ rd_d_in[3] ^ rd_d_in[2] ^ rd_d_in[1] ^ crc[25] ^ crc[26] ^ crc[27] ^ crc[31];
				crc[4] <= rd_d_in[6] ^ rd_d_in[4] ^ rd_d_in[3] ^ rd_d_in[2] ^ rd_d_in[0] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30];
				crc[5] <= rd_d_in[7] ^ rd_d_in[6] ^ rd_d_in[5] ^ rd_d_in[4] ^ rd_d_in[3] ^ rd_d_in[1] ^ rd_d_in[0] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31];
				crc[6] <= rd_d_in[7] ^ rd_d_in[6] ^ rd_d_in[5] ^ rd_d_in[4] ^ rd_d_in[2] ^ rd_d_in[1] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31];
				crc[7] <= rd_d_in[7] ^ rd_d_in[5] ^ rd_d_in[3] ^ rd_d_in[2] ^ rd_d_in[0] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[31];
				crc[8] <= rd_d_in[4] ^ rd_d_in[3] ^ rd_d_in[1] ^ rd_d_in[0] ^ crc[0] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28];
				crc[9] <= rd_d_in[5] ^ rd_d_in[4] ^ rd_d_in[2] ^ rd_d_in[1] ^ crc[1] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29];
				crc[10] <= rd_d_in[5] ^ rd_d_in[3] ^ rd_d_in[2] ^ rd_d_in[0] ^ crc[2] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[29];
				crc[11] <= rd_d_in[4] ^ rd_d_in[3] ^ rd_d_in[1] ^ rd_d_in[0] ^ crc[3] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28];
				crc[12] <= rd_d_in[6] ^ rd_d_in[5] ^ rd_d_in[4] ^ rd_d_in[2] ^ rd_d_in[1] ^ rd_d_in[0] ^ crc[4] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30];
				crc[13] <= rd_d_in[7] ^ rd_d_in[6] ^ rd_d_in[5] ^ rd_d_in[3] ^ rd_d_in[2] ^ rd_d_in[1] ^ crc[5] ^ crc[25] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[30] ^ crc[31];
				crc[14] <= rd_d_in[7] ^ rd_d_in[6] ^ rd_d_in[4] ^ rd_d_in[3] ^ rd_d_in[2] ^ crc[6] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30] ^ crc[31];
				crc[15] <= rd_d_in[7] ^ rd_d_in[5] ^ rd_d_in[4] ^ rd_d_in[3] ^ crc[7] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[31];
				crc[16] <= rd_d_in[5] ^ rd_d_in[4] ^ rd_d_in[0] ^ crc[8] ^ crc[24] ^ crc[28] ^ crc[29];
				crc[17] <= rd_d_in[6] ^ rd_d_in[5] ^ rd_d_in[1] ^ crc[9] ^ crc[25] ^ crc[29] ^ crc[30];
				crc[18] <= rd_d_in[7] ^ rd_d_in[6] ^ rd_d_in[2] ^ crc[10] ^ crc[26] ^ crc[30] ^ crc[31];
				crc[19] <= rd_d_in[7] ^ rd_d_in[3] ^ crc[11] ^ crc[27] ^ crc[31];
				crc[20] <= rd_d_in[4] ^ crc[12] ^ crc[28];
				crc[21] <= rd_d_in[5] ^ crc[13] ^ crc[29];
				crc[22] <= rd_d_in[0] ^ crc[14] ^ crc[24];
				crc[23] <= rd_d_in[6] ^ rd_d_in[1] ^ rd_d_in[0] ^ crc[15] ^ crc[24] ^ crc[25] ^ crc[30];
				crc[24] <= rd_d_in[7] ^ rd_d_in[2] ^ rd_d_in[1] ^ crc[16] ^ crc[25] ^ crc[26] ^ crc[31];
				crc[25] <= rd_d_in[3] ^ rd_d_in[2] ^ crc[17] ^ crc[26] ^ crc[27];
				crc[26] <= rd_d_in[6] ^ rd_d_in[4] ^ rd_d_in[3] ^ rd_d_in[0] ^ crc[18] ^ crc[24] ^ crc[27] ^ crc[28] ^ crc[30];
				crc[27] <= rd_d_in[7] ^ rd_d_in[5] ^ rd_d_in[4] ^ rd_d_in[1] ^ crc[19] ^ crc[25] ^ crc[28] ^ crc[29] ^ crc[31];
				crc[28] <= rd_d_in[6] ^ rd_d_in[5] ^ rd_d_in[2] ^ crc[20] ^ crc[26] ^ crc[29] ^ crc[30];
				crc[29] <= rd_d_in[7] ^ rd_d_in[6] ^ rd_d_in[3] ^ crc[21] ^ crc[27] ^ crc[30] ^ crc[31];
				crc[30] <= rd_d_in[7] ^ rd_d_in[4] ^ crc[22] ^ crc[28] ^ crc[31];
				crc[31] <= rd_d_in[5] ^ crc[23] ^ crc[29];
			end
		end
	end

endmodule
