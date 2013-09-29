`timescale 1ns / 1ps
// ethernet mac receiver module
// by liam davey (7/4/11)
//

module eth_mac_rx (
	input clk,
	input rst,
	input rd_clk,
	input rd_rst,
	
	input eth_mode_100_in,
	output reg [7:0] debug_out,
	
	input [7:0] eth_rx_d_in,
	input eth_rx_err_in,
	input eth_rx_dv_in,
	
	input ctl_rd_en_in,
	output [15:0] ctl_rd_d_out,
	output ctl_rd_empty_out,
	
	input data_rd_en_in,
	output [63:0] data_rd_d_out,
	output data_rd_empty_out
);

	localparam STATE_IDLE = 2'd0;
	localparam STATE_PREAMBLE = 2'd1;
	localparam STATE_DATA = 2'd2;
	localparam STATE_ERR = 2'd3;
	
	reg [1:0] state;
	
	reg toggle;
	reg [7:0] eth_rx_d;
	reg eth_rx_dv, eth_rx_err;
	
	// generate a toggle for 100 mbit mode
	
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
		  eth_rx_d <= 0;
		  eth_rx_dv <= 0;
		  eth_rx_err <= 0;
		  toggle <= 0;
		  
		 end else begin
			if (eth_mode_100_in) begin
			   // eth_rx_d needs to be ready when !toggle
				// so shift in high byte on !toggle
				// and low byte on toggle
				eth_rx_d <= (!toggle) ? {eth_rx_d[7:4], eth_rx_d_in[3:0]} : {eth_rx_d_in[3:0], eth_rx_d[3:0]};
				toggle <= !toggle;
			end else begin
				eth_rx_d <= eth_rx_d_in;
				toggle <= 0;
			end
			
			eth_rx_dv <= eth_rx_dv_in;
			eth_rx_err <= eth_rx_err_in;
		end
	end
	
	wire crc_ok;
	
	wire toggle_rdy = !toggle;
	
	// the crc check module
	// calculates the crc of incoming data.
	// the crc_ok signal goes high after the last byte
	// of the frame crc is shifted in if the crc is ok.
	//
	
	eth_crc rx_crc (
		.clk(clk),
		.rst(state == STATE_IDLE),
		.en_in((state == STATE_DATA) && !eth_rx_err && eth_rx_dv && toggle_rdy),
		.d_in(eth_rx_d),
		.crc_ok(crc_ok),
		.crc_out()
	);
	
	reg ctl_wr_en, data_wr_en;
	reg [15:0] ctl_wr_d;
	reg [63:0] data_wr_d;
	wire ctl_wr_full, data_wr_full;
	
	wire [17:0] ctl_rd_d;
	wire [71:0] data_rd_d;
	assign ctl_rd_d_out = ctl_rd_d[15:0];
	assign data_rd_d_out = data_rd_d[63:0];
	
	afifo_18_18_1k fifo_rx_ctl (
		.rst(rst),
		
		.wr_clk(clk),
		.wr_en(ctl_wr_en && toggle_rdy),
		.din({2'h0, ctl_wr_d}),
		.full(ctl_wr_full),
		
		.rd_clk(rd_clk),
		.rd_en(ctl_rd_en_in),
		.dout(ctl_rd_d),
		.empty(ctl_rd_empty_out)
	);
	
	afifo_72_72_8k fifo_rx_data (
		.rst(rst),
		
		.wr_clk(clk),
		.wr_en(data_wr_en && toggle_rdy),
		.din({8'h0, data_wr_d}),
		.full(data_wr_full),
		
		.rd_clk(rd_clk),
		.rd_en(data_rd_en_in),
		.dout(data_rd_d),
		.empty(data_rd_empty_out)
	);
	
	
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			state <= STATE_IDLE;
			ctl_wr_en <= 0;
			ctl_wr_d <= 0;
			data_wr_d <= 0;
			data_wr_en <= 0;
			debug_out <= 0;
			
		end else begin
			
			if (toggle_rdy) begin
			
				case (state)
					// idle state
					// waits for the first byte of the preamble
					// enters the preamble state if a bram buffer is free,
					// otherwise go to the error state (drop frame)
					STATE_IDLE: begin
						if (eth_rx_dv && !eth_rx_err && (eth_rx_d == 8'h55)) begin
							state <= STATE_PREAMBLE;
						end else
							state <= STATE_IDLE;
						ctl_wr_d <= 0;
						ctl_wr_en <= 0;
						data_wr_d <= 0;
						data_wr_en <= 0;
					end
					
					// preamble state
					// reads the 7 bytes of preamble before going to the
					// next state when the start of frame byte is received
					STATE_PREAMBLE: begin
						if (eth_rx_err || !eth_rx_dv)
							// go to error state
							state <= STATE_ERR;
						else if (eth_rx_d == 8'h55)
							// stay in preamble state as long as preamble received
							state <= STATE_PREAMBLE;
						else if (eth_rx_d == 8'hd5) begin
							// 0xAB is the start of frame field
							// when it is received go to the data state
							// and write a start of frame control byte
							state <= STATE_DATA;
						end else begin
							// go to error state
							state <= STATE_ERR;
						end
						
						ctl_wr_en <= 0;
						ctl_wr_d <= 0;
						data_wr_d <= 0;
						data_wr_en <= 0;
					end
					
					// data state
					STATE_DATA: begin
						if (eth_rx_err) begin
							// error
							state <= STATE_ERR;
							ctl_wr_en <= 1;
							ctl_wr_d[15] <= 1;
							data_wr_d <= 0;
							data_wr_en <= 0;
							
						end else if (!eth_rx_dv) begin
							// end of frame
							// make sure crc is ok and that the length is greater
							// than the minimum
							// x[14:0] > 15'd64 is the same as x[14:6] != 9'h0
							if (crc_ok && (ctl_wr_d[14:6] != 9'h0)) begin
								state <= STATE_IDLE;
								ctl_wr_d[15] <= 0;
								debug_out <= debug_out + 1'd1;
							end else begin
								state <= STATE_ERR;
								ctl_wr_d[15] <= 1;
							end
							ctl_wr_en <= 1;
							data_wr_d <= 0;
							data_wr_en <= 0;
							
						end else begin
							// valid data
							if (data_wr_full) begin
								state <= STATE_ERR;
								ctl_wr_d[15] <= 1;
								ctl_wr_en <= 1;
								data_wr_en <= 0;
								data_wr_d <= 0;
							end else begin
								// make sure count will not overflow
								if ((ctl_wr_d[14:0] + 1'd1) == 15'h7fff)
									state <= STATE_ERR;
								else
									state <= STATE_DATA;
								ctl_wr_en <= 0;
								ctl_wr_d[15] <= 0;
								ctl_wr_d[14:0] <= ctl_wr_d[14:0] + 1'd1;
								data_wr_d <= {data_wr_d[55:0], eth_rx_d};
								data_wr_en <= (ctl_wr_d[2:0] == 3'd7);
							end
						end
					end
					
					// error state
					default: begin
						// wait for dv and err to go low before returning
						// to idle state.
						if (!eth_rx_dv && !eth_rx_err)
							// add error byte and go to idle state
							state <= STATE_IDLE;
						
						ctl_wr_en <= 0;
						ctl_wr_d <= 0;
						data_wr_d <= 0;
						data_wr_en <= 0;
					end
				endcase
			
			end
		end
	end
	
endmodule
