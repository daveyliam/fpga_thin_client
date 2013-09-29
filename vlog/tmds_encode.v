////////////////////////////////////////////////////////////////////////
// DVI encoder module
// ==================
//
// By Liam Davey (03/03/11)
//
// Encodes either the 8 bit pixel data 'd' or control signals 'c0' and
// 'c1', depending on the value of 'de' (data enable), to a 10 bit value
// q_out. The 10-bit 'q_out' value is suitable for serialization to send
// over the DVI cable (using Transition Minimized Differential
// Signalling (TMDS)).
//
// Created based on Figure 3-5 of the DVI Specification 1.0, available
// from http://www.ddwg.org/lib/dvi_10.pdf
//
////////////////////////////////////////////////////////////////////////

/*

the encoding algorithm tries to on average send the same number of
ones as zeroes so no DC shift occurs on the differential pair.
it achieves this by selectively inverting the 9 bit output of the
previous stage (q_m). the tenth bit is used to signal whether or
not this inversion occurred.

if the current disparity is 0 (same number of total ones and zeroes
sent so far) then it does not really matter whether we invert
q_m[7:0] or not, as either way the disparity will not improve.
likewise if q_m[7:0] has an equal number of ones and zeroes then
whether we invert or not does not affect the disparity.

in either case the algorithm in the specification inverts the lower
8 bits if the 9th bit (XOR/XNOR flag) is 0, so that the top two
will be '10' - not affecting the disparity.
alternatively if the 9th bit is 1 no inversion will take place so
that the top two bits are '01' - again not affecting disparity.

i think there is room for improvement in the specified algorithm 
here. it would be possible (without modifying the decode algorithm)
to make the 9th and 10th bits '11' or '00' based on the number of
ones in the lower 8 bits to improve the disparity (and
inadvertently reduce the number of transitions).

if however the disparity is not 0 and there is not an equal number
of ones and zeroes in q_m[7:0], then we should decide whether or
not to invert the bits.
if we have more total ones sent and there are more ones in q_m[7:0]
than zeroes, q_m[7:0] should be inverted.
likewise if more total zeroes have been sent and there are more
zeroes than ones in q_m[7:0], we should also invert.
in all other cases, do not invert.

*/

module tmds_encode (
	input clk,				// clock signal
	input rst,				// reset signal
	input [7:0] d,			// input 8 bit pixel data
	input de,				// data enable (1 = data, 0 = control)
	input c0,				// control signal 0
	input c1,				// control signal 1
	output reg [9:0] q_out	// the encoded 10 bit value to output LSB first
									// on the differential channel
	);
	
	// copies of data for stage 1 so that the data is aligned
	// for the pipeline stage
	// i.e. so that 'd' is available next clock cycle even though
	// the input 'd' has changed
	reg [7:0] s1_d;
	reg s1_de, s1_c0, s1_c1;
	
	// copies of data for stage 2
	reg s2_de, s2_c0, s2_c1;
	reg [8:0] s2_q;
	
	// the transition minimized 9-bit output of stage 1
	wire [8:0] s1_q;
	
	// count of ones in data for stage 1
	reg [3:0] s1_n1;
	
	// count of ones in data for stage 2 (not a copy of s1_n1)
	reg [3:0] s2_n1;
	
	// disparity count (difference between total number of ones sent and
	// total number of zeroes sent). will be negative (MSB set) if more
	// zeroes than ones have been sent.
	reg signed [4:0] s2_cnt;// s2_cnt_prev;
	reg signed [4:0] s2_flag_bits_disparity, s2_q_disparity;

	// 8b -> 9b encoding
	// creates a transition minimized version of the input data.
	// asynchronous, the output q_m changes as soon as inputs s1_n1 or
	// s1_d1 from stage 1 change.
	// if this proves to be too slow could implement as another pipeline
	// stage instead (q_m as a register).

	wire use_xnor = (s1_n1 > 4'h4) || ((s1_n1 == 4'h4) && (s1_d[0] == 1'b0));
	assign s1_q[0] = s1_d[0];
	
	genvar i;
	for (i = 1; i < 8; i = i + 1) begin : xnor_loop
		assign s1_q[i] = (use_xnor) ? (~(s1_q[i - 1] ^ s1_d[i])) : (s1_q[i - 1] ^ s1_d[i]);
	end
	assign s1_q[8] = ~use_xnor;	// bit 9 indicates whether XNOR or XOR was used


	// decide whether we need to invert the lower 8 bits or not
	wire data_balanced = (s2_n1 == 4);			// true if data has 4 ones and 4 zeroes
	wire data_has_more_zeroes = (s2_n1 < 4);	// true if data has more zeroes than ones
	wire data_has_more_ones = (s2_n1 > 4);		// true if data has more ones than zeroes
	wire disparity_zero = (s2_cnt == 0);			// true if we have sent the same number of ones as zeroes
	wire need_more_ones = s2_cnt[4];					// true if we need to send more ones to balance disparity
	
	// check if inverting the lower 8 bits would improve disparity
	// (this neglects the case where disparity is already 0, in which case
	// whether to invert or not is decided differently)
	assign inversion_needed = (need_more_ones && data_has_more_zeroes) | 
		((~need_more_ones) && data_has_more_ones);

	// if disparity is zero or the data has equal number of ones and zeroes
	// then invert based on s2_q_m[8], otherwise based on the above decision
	assign invert_data = (disparity_zero | data_balanced) ? 
		(~s2_q[8]) : (inversion_needed);
	
	// how many more ones than zeroes are in the 8 data bits
	wire signed [4:0] s2_data_disparity = {s2_n1, 1'b0} - 8;
	
	// check if DE is low, signalling that we are sending control data
	// rather than pixel data
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			s2_cnt <= 0;
		end else begin
			// pipeline stage 1
			// count the number of one bits in d[7:0]
			s1_n1 <= d[7] + d[6] + d[5] + d[4] + d[3] + d[2] + d[1] + d[0];
			s1_d <= d;	// copy registers for use with later stages
			s1_de <= de;
			s1_c0 <= c0;
			s1_c1 <= c1;
			
			// find the number of ones in s1_q[7:0]
			s2_n1 <= 
				s1_q[7] + s1_q[6] + s1_q[5] + s1_q[4] + 
				s1_q[3] + s1_q[2] + s1_q[1] + s1_q[0];
			s2_de <= s1_de;
			s2_c0 <= s1_c0;
			s2_c1 <= s1_c1;
			s2_q <= s1_q;
			
			if (s2_de == 1'b0) begin
				// use a simple lookup table to create the 10-bit code to output
				// note that these are reversed compared to the specification
				// document as it used q_out[0:9] rather than q_out[9:0]
				case ({s2_c1, s2_c0})
					2'b00   : q_out <= 10'b1101010100;
					2'b01   : q_out <= 10'b0010101011;
					2'b10   : q_out <= 10'b0101010100;
					default : q_out <= 10'b1010101011;
				endcase
				s2_cnt <= 0;

			end else begin
				q_out[9] <= invert_data;
				q_out[8] <= s2_q[8];
				q_out[7:0] <= (invert_data) ? (~s2_q[7:0]) : (s2_q[7:0]);
				s2_flag_bits_disparity = {invert_data && s2_q[8], 1'b0} - {~(invert_data || s2_q[8]), 1'b0};
				s2_q_disparity = (invert_data) ? (s2_flag_bits_disparity - s2_data_disparity) : (s2_flag_bits_disparity + s2_data_disparity);
				//s2_cnt_prev <= s2_cnt;
				s2_cnt <= s2_cnt + s2_q_disparity;
			end
		end
	end
endmodule
