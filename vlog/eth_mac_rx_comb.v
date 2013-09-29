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
	
	input [7:0] eth_rx_d_in,
	input eth_rx_err_in,
	input eth_rx_dv_in,
	
	output reg wr_en_out,
	output reg wr_chk_out,
	output reg wr_clr_out,
	output reg [35:0] wr_d_out,
	input wr_full_in
);

	localparam STATE_IDLE = 2'd0;
	localparam STATE_PREAMBLE = 2'd1;
	localparam STATE_DATA = 2'd2;
	localparam STATE_ERR = 2'd3;
	
	wire full;
	reg [1:0] state;

	wire crc_ok;
	reg crc_ok_r;
	
	// data | ctl_sof | ctl_eof | ctl_err | d[7:0] | state[1:0]
	reg [13:0] tmp;
	
	wire data = tmp[13];
	wire ctl_sof = tmp[12];
	wire ctl_eof = tmp[11];
	wire ctl_err = tmp[10];
	wire [7:0] d = tmp[9:2];
	wire [1:0] state_next = tmp[1:0];
	
	// combinational logic block for eth rx state machine
	// gets the next state, the data to add to the shift registers,
	// and control signals
	//always @ (rst or state or eth_rx_dv_in or eth_rx_err_in or eth_rx_d_in or wr_full_in or crc_ok) begin
	always @ (posedge clk) begin
		if (rst) begin
			tmp = {12'h0, STATE_IDLE};
		end else begin
			case (state)
				// idle state
				// waits for the first byte of the preamble
				// enters the preamble state if a bram buffer is free,
				// otherwise go to the error state (drop frame)
				STATE_IDLE: begin
					if (eth_rx_dv_in && !eth_rx_err_in && (eth_rx_d_in == 8'haa))
						tmp = {12'h0, STATE_PREAMBLE};
					else
						tmp = {12'h0, STATE_IDLE};
				end
				
				// preamble state
				// reads the 7 bytes of preamble before going to the
				// next state when the start of frame byte is received
				STATE_PREAMBLE: begin
					if (eth_rx_err_in || !eth_rx_dv_in)
						// go to error state
						tmp = {12'h0, STATE_ERR};
					else if (eth_rx_d_in == 8'haa)
						// stay in preamble state as long as preamble received
						tmp = {12'h0, STATE_PREAMBLE};
					else if (eth_rx_d_in == 8'hab && !wr_full_in)
						// 0xAB is the start of frame field
						// when it is received go to the data state
						// and write a start of frame control byte
						tmp = {4'b0100, 8'h00, STATE_DATA};
					else
						// go to error state
						tmp = {12'h0, STATE_ERR};
				end
				
				// data state
				STATE_DATA: begin
					if (eth_rx_err_in || wr_full_in)
						// go to error state
						tmp = {12'h0, STATE_ERR};
					else if (!eth_rx_dv_in)
						// end of frame
						if (crc_ok_r)
							tmp = {4'b0010, 8'h00, STATE_IDLE};
						else
							tmp = {12'h0, STATE_ERR};
					else
						// data received
						tmp = {4'b1000, eth_rx_d_in, STATE_DATA};
				end
				
				// error state
				default: begin
					// wait for dv and err to go low before returning
					// to idle state.
					// also wait for space in fifo so that an error
					// control byte can be written
					if (!eth_rx_dv_in && !eth_rx_err_in && !wr_full_in)
						// add error byte and go to idle state
						tmp = {4'b0001, 8'h00, STATE_IDLE};
					else
						tmp = {12'h0, STATE_ERR};
				end
			endcase
		end
	end

	reg [1:0] count;
	
	// when the data and control shift registers are full or are
	// flushed write the data to bram
	wire wr_en = (count == 2'd3);
	
	// add data read from gmii interface to the fifo
	always @ (posedge clk or posedge rst) begin
		if (rst) begin
			state <= STATE_IDLE;
			count <= 0;
			wr_d_out <= 0;
			wr_en_out <= 0;
			wr_chk_out <= 0;
			wr_clr_out <= 0;
			
		end else begin
			state <= state_next;
			
			// add data to the shift register.
			// if chk or clr are set then dummy bytes are
			// added until the shift register is full.
			if (data || wr_chk_out || wr_clr_out) begin
				wr_d_out[31:0] <= (data) ? {wr_d_out[23:0], d} : {wr_d_out[23:0], 8'h00};
				count <= count + 1'd1;
			end
			
			// control flags set until the shift reg is written to the fifo
			wr_chk_out <=   (ctl_eof) ? 1'b1 : (wr_en_out) ? 1'b0 : wr_chk_out;
			wr_d_out[32] <= (ctl_eof) ? 1'b1 : (wr_en_out) ? 1'b0 : wr_chk_out;
			wr_clr_out <=   (ctl_err) ? 1'b1 : (wr_en_out) ? 1'b0 : wr_clr_out;
			
			wr_en_out <= wr_en;
			crc_ok_r <= (data) ? crc_ok : crc_ok_r;
		end
	end
	
	wire crc_rst = ctl_eof || ctl_err;
	wire crc_en = data;
	wire [7:0] crc_d = d;
	
	eth_crc rx_crc (
		.clk(clk),
		.rst(crc_rst),
		.en_in(crc_en),
		.d_in(crc_d),
		.crc_ok(crc_ok),
		.crc_out()
	);
	
endmodule
