module sramWriter(
	input i_clk,
	input i_rst,
	input i_enable, // From SW
	input i_pause,  // From KEY
	input i_stop,	// From KEY
	input i_ready,  // From I2C
	input [15:0] i_record_data,
	output [15:0] o_SRAM_DQ,
	output o_write_n,
	output [19:0] o_addr,
	output [19:0] o_end_addr,
	output o_LED
);

	enum {IDLE, WAIT, WRITE, PAUSE, STOP} state_w, state_r;

	logic [19:0] addr_w, addr_r;
	logic [19:0] end_addr_w, end_addr_r;
	logic new_w, new_r;
	logic write_w, write_r;
	logic [31:0] counter_w, counter_r;

	assign o_addr = addr_r;
	assign o_write_n = write_r? 0 : 1'bz;
	assign o_SRAM_DQ = i_enable? (i_record_data) : 16'bz;
	assign o_end_addr = end_addr_r;


	always_comb begin
		state_w = state_r;
		addr_w = addr_r;
		write_w = write_r;
		end_addr_w = end_addr_r;
		new_w = new_r;
		counter_w = counter_r;

		case (state_r)

			// When top is not in record mode
			IDLE: begin
					o_LED = 0;
					write_w = 0;
					new_w = 0;
					if (i_enable) begin
						state_w = STOP;
						addr_w = 0;
					end
			end

			// Wait for the data from I2C is ready
			WAIT: begin
					o_LED = 1;
					if (!i_enable) begin
						state_w = IDLE;
						if (new_r) begin
							end_addr_w = addr_r;
						end
					end else if (i_pause) begin
						state_w = PAUSE;
					end else if (i_ready) begin
						state_w = WRITE;
						write_w = 1;
					end
			end

			// Write the data into the sRAM 
			WRITE: begin
					o_LED = 1;
					write_w = 0;
					if (!i_enable) begin
						state_w = IDLE;
						if (new_r) begin
							end_addr_w = addr_r;
						end
					end else if (addr_r == 1048575) begin
						state_w = STOP;
					end else begin
						state_w = WAIT;
						addr_w = addr_r + 1;
					end

			end

			// Pause and do nothing
			PAUSE: begin
					if (counter_r == 12000000) begin
						counter_w = 0;
					end else begin
						counter_w = counter_r + 1;
					end
					o_LED = (counter_r > 6000000);	
					if (!i_enable) begin
						state_w = IDLE;
						if (new_r) begin
							end_addr_w = addr_r;
						end
					end else if (i_pause) begin
						state_w = WAIT;
					end else if (i_stop) begin 
						state_w = STOP;
					end
			end

			// When reach the end of sRAM or press STOP
			STOP: begin
					o_LED = 0;
					if (!i_enable) begin
						state_w = IDLE;
						if (new_r) begin
							end_addr_w = addr_r;
						end
					end else if (i_pause) begin
						state_w = WAIT;
						new_w = 1;
						addr_w = 0;
					end
			end

		endcase // state_r


	end

	always_ff @(posedge i_clk or posedge i_rst) begin
		if(i_rst) begin
			state_r <= IDLE;
			write_r <= 0;
			addr_r <= 0;
			end_addr_r <= 0;
			new_r <= 1;
			counter_r <= 0;
		end else begin
			state_r <= state_w;
			write_r <= write_w;
			addr_r <= addr_w;
			end_addr_r <= end_addr_w;
			new_r <= new_w;
			counter_r <= counter_w;
		end
	end



endmodule // sramWriter