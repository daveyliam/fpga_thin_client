`timescale 1ns / 1ps
`include "tmds_encode.v"
`include "tmds_decode.v"

module tmds_encode_tb;

	// Inputs
	reg clk;
	reg rst;
	reg [7:0] d;
	reg de;
	reg c0;
	reg c1;

	// Outputs
	wire [9:0] q_out;
	
	wire [7:0] d_out;
	wire de_out, c0_out, c1_out;
	wire signed [7:0] count_out;

	// Instantiate the Unit Under Test (UUT)
	tmds_encode uut (
		.clk(clk), 
		.rst(rst), 
		.d(d), 
		.de(de), 
		.c0(c0), 
		.c1(c1), 
		.q_out(q_out)
	);
	
	// inputs of decode module
	tmds_decode u_tmds_decode (
		.clk(clk),
		.rst(rst),
		.q_in(q_out),
		.d(d_out),
		.de(de_out),
		.c0(c0_out),
		.c1(c1_out),
		.cnt(count_out));
	
	always begin
		#5 clk = ~clk;
	end
	
	reg rand_in_enable;
	reg [7:0] delay_count, delay_length, delayed_d_in;
	reg [7:0] d_delay [7:0];
	
	always @ (posedge clk) begin
		if (de) begin
			if (rand_in_enable) begin
				d <= $random % 256;
				case (delay_length)
					8'd2 : delayed_d_in = d_delay[0];
					8'd3 : delayed_d_in = d_delay[1];
					8'd4 : delayed_d_in = d_delay[2];
					8'd5 : delayed_d_in = d_delay[3];
					8'd6 : delayed_d_in = d_delay[4];
					8'd7 : delayed_d_in = d_delay[5];
					8'd8 : delayed_d_in = d_delay[6];
					8'd9 : delayed_d_in = d_delay[7];
					default : delayed_d_in = 8'hxx;
				endcase
				if (d_out != delayed_d_in) begin
					$display ("error: dout (%x) != din (%x)", d_out, delayed_d_in);
				end
			end else begin	
				d <= (delay_count == 8'd0) ? 8'h5a : 8'h00;
				delay_count <= delay_count + 1;
				if (d_out == 8'h5a) begin
					$display ("received sync byte after delay of %d", delay_count);
					delay_length <= delay_count;
					rand_in_enable <= 1'b1;
				end
			end
			d_delay[0] <= d;
			d_delay[1] <= d_delay[0];
			d_delay[2] <= d_delay[1];
			d_delay[3] <= d_delay[2];
			d_delay[4] <= d_delay[3];
			d_delay[5] <= d_delay[4];
			d_delay[6] <= d_delay[5];
			d_delay[7] <= d_delay[6];
			
			if (count_out < -10 || count_out > 10) begin
				$display("warning: large disparity on differential line detected (%d)", count_out);
			end
		end
	end
	
			

	initial begin
		$monitor ("d_in=%x, d_out=%x, q_out=%x, count_out=%d", d, d_out, q_out, count_out);
		$dumpfile("tmds_encode_tb.vcd");
		$dumpvars;
		// Initialize Inputs
		clk = 0;
		rst = 0;
		d = 0;
		de = 0;
		c0 = 0;
		c1 = 0;
		rand_in_enable = 1'b0;
		delay_count = 0;
		delay_length = 0;
		
		// reset pulse
		#40 rst = 1'b1;
		#80 rst = 1'b0;
        
		// Add stimulus here
		
		#120 de = 1'b1;
		
		#1000 $finish;

	end
      
endmodule
