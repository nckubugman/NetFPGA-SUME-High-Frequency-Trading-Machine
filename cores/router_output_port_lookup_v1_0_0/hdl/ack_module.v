///////////////////////////////////////////////////////////////////////////////
// $Id: ack_module.v $
//
// Module: ack_module.v
// Project: NF2.1
// Description: Build a tcp ack packet for reuse
//              
//
///////////////////////////////////////////////////////////////////////////////

  module ack_module
	#(
            parameter C_S_AXIS_DATA_WIDTH       = 256
	  )

	(
	  input		send_ack_sig,
	  output reg	out_rdy,
	  output reg	[C_S_AXIS_DATA_WIDTH-1:0]	out_tdata,
	  output reg	[C_S_AXIS_DATA_WIDTH/8-1:0]	out_tkeep,
	  
	  input		reset,
	  input		clk
	);

localparam WAIT = 4'h0;

localparam WORD_1 = 4'h1;
localparam WORD_2 = 4'h2;
localparam WORD_3 = 4'h3;
localparam WORD_4 = 4'h4;
localparam WORD_5 = 4'h6;
localparam WORD_6 = 4'h7;
localparam WORD_7 = 4'h8;
localparam WORD_8 = 4'h9;
localparam WORD_9 = 4'ha;

reg	[3:0]	state;


always @(posedge clk) begin
	if(reset) begin
		out_rdy  <= 1'b0;
		out_tdata <= 256'h0;
		out_tkeep <= 32'h0;
		state    <= 'b0;
	end
	else begin
		case(state)
			WAIT: begin
				if(send_ack_sig) begin
					state <= WORD_1;
					out_rdy <= 1'b0;
					//out_rdy <= 1'b1;
				end
			end
			WORD_1: begin
				//out_tdata <= {64'h1c6f65ac1d4fcafe,64'hf00d000108004500,64'h0034ae6a40004006,64'h00008c7452ba8c74};
		                out_rdy <= 1'b1;
				out_tdata <= {64'h1402ec6d90100253, 64'h554d450008004500, 64'h00347a2640004006, 64'h02378c7452bd8c74};
				out_tkeep <= 32'hffffffff;
				state <= WORD_2;
			end
			WORD_2: begin
				out_rdy <= 1'b1;
				out_tdata <= {64'h52b9e704138acf52,64'h54d40854033b8010,64'h0073b2d900000101,64'h080a020bfaba0584};
				out_tkeep <= 32'hffffffff;
				state <= WORD_3;
			end
			WORD_3: begin
				out_rdy <= 1'b1;
				out_tdata <= {64'h67d4000000000000,192'h0};
				out_tkeep <= 32'hc0000000;
				state <= WAIT;
			end
		endcase
	end

end


endmodule
