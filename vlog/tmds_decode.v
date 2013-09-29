// A decode module used for simulation to test the encoder
// By Liam Davey (3/3/2011)

`timescale 1ns / 1ps

module tmds_decode (
	input clk, input rst,
	input [9:0] q_in,
	output reg [7:0] d,
	output reg c0,
	output reg c1,
	output reg de,
	output reg signed [7:0] cnt);

	reg [9:0] s1_q_in;
	wire [7:0] d_q;
	reg c0_1, c1_1, de_1;
	genvar i;
	
	wire signed [7:0] n1_q_in = q_in[9] + q_in[8] + q_in[7] + q_in[6] + q_in[5] + q_in[4] + q_in[3] + q_in[2] + q_in[1] + q_in[0];
	reg signed [7:0] q_in_disparity;
	
	// decode stage 2, XNOR or XOR depending on bit 8
	assign d_q[0] = s1_q_in[0];
	for (i = 1; i < 8; i = i + 1) begin : decode_loop
		assign d_q[i] = (s1_q_in[8]) ? (s1_q_in[i] ^ s1_q_in[i - 1]) : ~(s1_q_in[i] ^ s1_q_in[i - 1]);
	end
	
	always @ (posedge clk) begin
		if (rst) begin
			cnt <= 0;
		end else begin
			case(q_in)
				10'b1101010100 : {de_1, c0_1, c1_1} <= 3'b000;
				10'b0010101011 : {de_1, c0_1, c1_1} <= 3'b001;
				10'b0101010100 : {de_1, c0_1, c1_1} <= 3'b010;
				10'b1010101011 : {de_1, c0_1, c1_1} <= 3'b011;
				default : {de_1, c0_1, c1_1} <= 3'b100;
			endcase
			
			// decode stage 1, invert data bits if bit 9 set
			s1_q_in[9:8] <= q_in[9:8];
			s1_q_in[7:0] <= (q_in[9]) ? (~q_in[7:0]) : (q_in[7:0]);
			
			// output results from stage 2
			d <= d_q;
			
			de <= de_1;
			c0 <= c0_1;
			c1 <= c1_1;
			
			// update cnt, the disparity count
			q_in_disparity = {n1_q_in, 1'b0} - 8'd10;
			cnt <= cnt + q_in_disparity;
		end
	end
endmodule
