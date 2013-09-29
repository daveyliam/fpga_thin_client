`timescale 1ns / 1ps

// ethernet crc module
// by liam davey (20/04/11)

// calculates or checks the CRC 32 of a message 
// input 8-bits at a time.

module eth_crc(
	input clk,
	input rst,
	
	input en_in,
	input [7:0] d_in,
	
	output [31:0] crc_out,
	output crc_ok
);

	reg [31:0] crc;
	wire [31:0] crc_next;
	
	genvar i;
	
	generate
		for (i = 0; i < 32; i = i + 1) begin : for_gen_crc_out
			assign crc_out[i] = !crc_next[31 - i];
		end
	endgenerate
	
	assign crc_ok = (crc == 32'hc704dd7b);
	
	wire [7:0] d;
	generate
		for (i = 0; i < 8; i = i + 1) begin : for_gen_crc_d
			assign d[i] = d_in[7 - i];
		end
	endgenerate
	
	assign crc_next[0] = d[6] ^ d[0] ^ crc[24] ^ crc[30];
	assign crc_next[1] = d[7] ^ d[6] ^ d[1] ^ d[0] ^ crc[24] ^ crc[25] ^ crc[30] ^ crc[31];
	assign crc_next[2] = d[7] ^ d[6] ^ d[2] ^ d[1] ^ d[0] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[30] ^ crc[31];
	assign crc_next[3] = d[7] ^ d[3] ^ d[2] ^ d[1] ^ crc[25] ^ crc[26] ^ crc[27] ^ crc[31];
	assign crc_next[4] = d[6] ^ d[4] ^ d[3] ^ d[2] ^ d[0] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30];
	assign crc_next[5] = d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[1] ^ d[0] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31];
	assign crc_next[6] = d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[2] ^ d[1] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31];
	assign crc_next[7] = d[7] ^ d[5] ^ d[3] ^ d[2] ^ d[0] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[31];
	assign crc_next[8] = d[4] ^ d[3] ^ d[1] ^ d[0] ^ crc[0] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28];
	assign crc_next[9] = d[5] ^ d[4] ^ d[2] ^ d[1] ^ crc[1] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29];
	assign crc_next[10] = d[5] ^ d[3] ^ d[2] ^ d[0] ^ crc[2] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[29];
	assign crc_next[11] = d[4] ^ d[3] ^ d[1] ^ d[0] ^ crc[3] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28];
	assign crc_next[12] = d[6] ^ d[5] ^ d[4] ^ d[2] ^ d[1] ^ d[0] ^ crc[4] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30];
	assign crc_next[13] = d[7] ^ d[6] ^ d[5] ^ d[3] ^ d[2] ^ d[1] ^ crc[5] ^ crc[25] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[30] ^ crc[31];
	assign crc_next[14] = d[7] ^ d[6] ^ d[4] ^ d[3] ^ d[2] ^ crc[6] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30] ^ crc[31];
	assign crc_next[15] = d[7] ^ d[5] ^ d[4] ^ d[3] ^ crc[7] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[31];
	assign crc_next[16] = d[5] ^ d[4] ^ d[0] ^ crc[8] ^ crc[24] ^ crc[28] ^ crc[29];
	assign crc_next[17] = d[6] ^ d[5] ^ d[1] ^ crc[9] ^ crc[25] ^ crc[29] ^ crc[30];
	assign crc_next[18] = d[7] ^ d[6] ^ d[2] ^ crc[10] ^ crc[26] ^ crc[30] ^ crc[31];
	assign crc_next[19] = d[7] ^ d[3] ^ crc[11] ^ crc[27] ^ crc[31];
	assign crc_next[20] = d[4] ^ crc[12] ^ crc[28];
	assign crc_next[21] = d[5] ^ crc[13] ^ crc[29];
	assign crc_next[22] = d[0] ^ crc[14] ^ crc[24];
	assign crc_next[23] = d[6] ^ d[1] ^ d[0] ^ crc[15] ^ crc[24] ^ crc[25] ^ crc[30];
	assign crc_next[24] = d[7] ^ d[2] ^ d[1] ^ crc[16] ^ crc[25] ^ crc[26] ^ crc[31];
	assign crc_next[25] = d[3] ^ d[2] ^ crc[17] ^ crc[26] ^ crc[27];
	assign crc_next[26] = d[6] ^ d[4] ^ d[3] ^ d[0] ^ crc[18] ^ crc[24] ^ crc[27] ^ crc[28] ^ crc[30];
	assign crc_next[27] = d[7] ^ d[5] ^ d[4] ^ d[1] ^ crc[19] ^ crc[25] ^ crc[28] ^ crc[29] ^ crc[31];
	assign crc_next[28] = d[6] ^ d[5] ^ d[2] ^ crc[20] ^ crc[26] ^ crc[29] ^ crc[30];
	assign crc_next[29] = d[7] ^ d[6] ^ d[3] ^ crc[21] ^ crc[27] ^ crc[30] ^ crc[31];
	assign crc_next[30] = d[7] ^ d[4] ^ crc[22] ^ crc[28] ^ crc[31];
	assign crc_next[31] = d[5] ^ crc[23] ^ crc[29];
	
	always @ (posedge clk or posedge rst)
		crc <= (rst) ? 32'hffffffff : (en_in) ? crc_next : crc;
	
endmodule
