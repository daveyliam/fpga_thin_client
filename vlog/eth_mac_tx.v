`timescale 1ns / 1ps

// ethernet mac transmit module
// by liam davey (7/4/11)
//
// the eth_tx_d and eth_rx_d 8 bit ports are in little endian bit order
// (bit/pin 7 is msb, bit/pin 0 is lsb) so will need to be assigned in
// reverse to the external ethernet pins.
// this is because the ethernet phy expects to receive octets in big
// endian order (bit 7 lsb, bit 0 msb).
// 

module eth_mac_tx (
	input clk,
	input rst,
	input wr_clk,
	input wr_rst,
	
	input eth_mode_100_in,
	output reg [7:0] debug_out,
	
	output reg [7:0] eth_tx_d_out,
	output reg eth_tx_en_out,
	output reg eth_tx_err_out,
	
	// fifo interface
	input data_wr_en_in,
	input [63:0] data_wr_d_in,
	output data_wr_full_out,
	
	input ctl_wr_en_in,
	input [15:0] ctl_wr_d_in,
	output ctl_wr_full_out
);

	reg [14:0] count;
	reg [2:0] state;
	reg error, dv;
	reg [55:0] sr;
	reg toggle;
	
	wire [31:0] crc;
	
	reg [11:0] frame_length;
	
	localparam STATE_IDLE = 3'd0;
	localparam STATE_PREAMBLE = 3'd1;
	localparam STATE_DATA = 3'd2;
	localparam STATE_FCS = 3'd3;
	localparam STATE_IFG = 3'd4;
	
	reg ctl_rd_en, data_rd_en;
	wire ctl_rd_empty, data_rd_empty;
	
	wire [17:0] ctl_rd_d_18;
	wire [15:0] ctl_rd_d = ctl_rd_d_18[15:0];
	
	wire [71:0] data_rd_d_72;
	wire [63:0] data_rd_d = data_rd_d_72[63:0];
	
	afifo_18_18_1k fifo_tx_ctl (
		.rst(wr_rst),
		
		.wr_clk(wr_clk),
		.wr_en(ctl_wr_en_in),
		.din({2'h0, ctl_wr_d_in}),
		.full(ctl_wr_full_out),
		
		.rd_clk(clk),
		.rd_en(ctl_rd_en && !toggle),
		.dout(ctl_rd_d_18),
		.empty(ctl_rd_empty)
	);
	
	afifo_72_72_8k fifo_tx_data (
		.rst(wr_rst),
		
		.wr_clk(wr_clk),
		.wr_en(data_wr_en_in),
		.din({8'h0, data_wr_d_in}),
		.full(data_wr_full_out),
		
		.rd_clk(clk),
		.rd_en(data_rd_en && !toggle),
		.dout(data_rd_d_72),
		.empty(data_rd_empty)
	);
	
	wire frame_is_valid = !ctl_rd_d[15];
	
	
	reg [7:0] eth_tx_d;
	reg eth_tx_en, eth_tx_err;
	
	// generate a toggle for 100 mbit mode
	
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
		  eth_tx_d_out <= 0;
		  eth_tx_en_out <= 0;
		  eth_tx_err_out <= 0;
		  toggle <= 0;
		  
		 end else begin
			if (eth_mode_100_in) begin
				eth_tx_d_out <= (!toggle) ? {4'h0, eth_tx_d[7:4]} : {4'h0, eth_tx_d[3:0]};
				if (toggle) begin
					eth_tx_en_out <= eth_tx_en;
					eth_tx_err_out <= eth_tx_err;
				end
				toggle <= !toggle;
			end else begin
				eth_tx_d_out <= eth_tx_d;
				eth_tx_en_out <= eth_tx_en;
				eth_tx_err_out <= eth_tx_err;
				toggle <= 0;
			end
		end
	end
	
	
	// the transmitter state machine.
	// reads data from the tx_bram, calculating the CRC32 checksum and
	// outputting the data on the eth_tx_d pins.
	
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			count <= 0;
			state <= STATE_IDLE;
			eth_tx_d <= 0;
			eth_tx_en <= 0;
			eth_tx_err <= 0;
			error <= 0;
			dv <= 0;
			ctl_rd_en <= 0;
			data_rd_en <= 0;
			sr <= 0;
			debug_out <= 0;
			
		end else begin
			
			if (!toggle) begin
			
				case (state)
					// idle state
					STATE_IDLE: begin
						if (!ctl_rd_empty && ctl_rd_en) begin
							if (frame_is_valid) begin
								state <= STATE_PREAMBLE;
								error <= 0;
							end else begin
								state <= STATE_DATA;
								error <= 1;
							end
							frame_length <= ctl_rd_d[11:0];
							ctl_rd_en <= 0;
						end else begin
							ctl_rd_en <= !ctl_rd_empty;
							error <= 0;
						end
						count <= 0;
						dv <= 0;
						data_rd_en <= 0;
						eth_tx_en <= 0;
						eth_tx_err <= 0;
					end
					
					STATE_PREAMBLE: begin
						if (count[2:0] == 3'd7) begin
							eth_tx_d <= 8'hd5;
							state <= STATE_DATA;
							count <= 0;
						end else if (count[2:0] == 3'd6) begin
							eth_tx_d <= 8'h55;
							count <= count + 1'd1;
						end else begin
							eth_tx_d <= 8'h55;
							count <= count + 1'd1;
						end
						eth_tx_en <= 1;
					end
					
					STATE_DATA: begin
						// this state needs to read 'frame_length' bytes from the
						// fifo and write them out on the gmii interface.
						// if the fifo becomes empty at any point the tx_err signal is
						// asserted for one cycle and the remaining bytes are read from
						// the fifo but not written.
						// when all bytes are written from the fifo the crc must be
						// shifted out.
						if (count[2:0] == 3'd0) begin
							if (!data_rd_empty)
								{eth_tx_d, sr} <= data_rd_d;
							else begin
								{eth_tx_d, sr} <= 64'h0;
								error <= 1;
							end
							
							data_rd_en <= !data_rd_empty;
							
						end else begin
							{eth_tx_d, sr} <= {sr, 8'h00};
							data_rd_en <= 0;
						end
						
						dv <= !error;
						eth_tx_en <= !error;
						eth_tx_err <= error && eth_tx_en;
						
						// end of frame data
						// will occur when count[2:0] == 7, so one cycle before
						// more data is read from the fifo
						if ((count + 1'd1) == {frame_length, 3'h0}) begin
							if (!error) begin
								state <= STATE_FCS;
								debug_out <= debug_out + 1'd1;
							end else begin
								state <= STATE_IFG;
							end
							count <= 0;
						end else if (!((count[2:0] == 3'd0) && data_rd_empty)) begin
							count <= count + 1'd1;
						end
					end
					
					STATE_FCS: begin
						if (count[1:0] == 2'd3) begin
							count <= 0;
							{eth_tx_d, sr} <= {sr, 8'h00};
							state <= STATE_IFG;
						end else if (count[1:0] == 2'd0) begin
							count <= count + 1'd1;
							{eth_tx_d, sr} <= {crc[7:0], crc[15:8], crc[23:16], crc[31:24], 32'h0};
						end else begin
							count <= count + 1'd1;
							{eth_tx_d, sr} <= {sr, 8'h00};
						end
						eth_tx_en <= 1;
					end
					
					// STATE_IFG
					default: begin
						eth_tx_en <= 0;
						eth_tx_d <= 0;
						if (count[3:0] == 4'd11)
							state <= STATE_IDLE;
						count <= count + 1'd1;
						dv <= 0;
					end
				endcase
			end
		end
	end
	
	eth_crc tx_crc (
		.clk(clk),
		.rst(state == STATE_IDLE),
		.en_in(dv && !toggle),
		.d_in(eth_tx_d),
		.crc_ok(),
		.crc_out(crc)
	);

endmodule
