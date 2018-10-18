///////////////////////////////////////////////////////////////////////////////
//
// Module: pkt_buffer.v
// Description: pkt buffer for tcp checksum
//              
//              
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/100ps
module pkt_buffer_fix_seq_num
  #(//Master AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH = 256,
    parameter C_S_AXIS_DATA_WIDTH = 256,
    parameter C_M_AXIS_TUSER_WIDTH  = 128,
    parameter C_S_AXIS_TUSER_WIDTH  = 128 )
  (// --- interface to input fifo - fallthrough

    // Global Ports
    input clk,
    input reset,

    // Master Stream Ports (interface to data path)
    output reg[C_M_AXIS_DATA_WIDTH - 1:0]          m_axis_tdata,
    output reg[((C_M_AXIS_DATA_WIDTH / 8)) - 1:0]  m_axis_tkeep,
    output reg                                     m_axis_tvalid,
    input                                          m_axis_tready,
    output reg                                     m_axis_tlast,
    output reg[C_M_AXIS_TUSER_WIDTH -1 :0]	   m_axis_tuser,

    // Slave Stream Ports (interface to RX queues)
    input [C_S_AXIS_DATA_WIDTH - 1:0]              s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0]      s_axis_tkeep,
    input                                          s_axis_tvalid,
   // output reg                                     s_axis_tready,
    input                                          s_axis_tlast,
    input[C_S_AXIS_TUSER_WIDTH-1:0]	  	   s_axis_tuser,
  

   //output reg 			                        in_rdy_buff,
   output reg                                       rd_fix_seq_num,
   input [23:0]			                    fix_new_seq_num,
   input			                    fix_seq_num_vld,   
   output reg                                       out_fifo_rd_en

   
  );

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2
   
   //---------------------- Internal parameters -------------------------
   localparam WAIT = 1;
   localparam WORD_1 = 2;
   localparam WORD_2 = 4;
   localparam WORD_3 = 8;
   localparam WORD_4 = 16;
   localparam MOVE_PKT = 32;
   localparam END = 64;
   localparam NUM_STATES = 10;
   //---------------------- Wires and regs -------------------------
   reg [NUM_STATES-1:0] state;
   reg [NUM_STATES-1:0] state_next;

   reg [C_M_AXIS_DATA_WIDTH-1:0]     out_tdata_next;
   reg [(C_M_AXIS_DATA_WIDTH/8)-1:0] out_tkeep_next;
   reg                               out_tvalid_next;
   reg [C_M_AXIS_TUSER_WIDTH-1:0]   out_tuser_next;
   reg				     out_tlast_next;
   reg				     out_fifo_rd_en_next;

   reg counter;
   reg counter_next;

   //-------------------------- Logic ------------------------------

     
   always @(*) begin
        out_tkeep_next  = 32'h0;
        out_tdata_next  = 256'h0;
	out_tuser_next  = 128'h0;
	out_tlast_next  = 0;
        out_tvalid_next = 0;
	rd_fix_seq_num ='b0;
        out_fifo_rd_en = 'b0;
	state_next = state;
	counter_next = counter;
        case(state)
//            WAIT: begin
/*
		if(fix_checksum_vld)begin
			if(s_axis_tuser[47:32]==16'h01)begin //TCP packet
				state_next = PASS_PKT;
			end
			if(s_axis_tuser[47:32]==16'h02)begin //FIX packet
				state_next = WORD_1;
			end
		end
*/
		/*
                if(s_axis_tvalid && m_axis_tready) begin
                                out_fifo_rd_en = 1;
                                m_axis_tdata_next = s_axis_tdata;
                                m_axis_tuser_next = s_axis_tuser;
                                m_axis_tlast_next = s_axis_tlast;
                                m_axis_tkeep_next = s_axis_tkeep;
                                m_axis_tvalid_next = 1;
				
                                
                end
		*/
//            end
/*
	    PASS_PKT: begin
		if(s_axis_tvalid && m_axis_tready)begin
			   out_fifo_rd_en = 1;
                           out_tkeep_next = s_axis_tkeep;
                           out_tlast_next = s_axis_tlast;
                           out_tuser_next = s_axis_tuser;
                           out_tdata_next = s_axis_tdata;
                           out_tvalid_next = 1;
			   counter_next = counter_next + 1;
			   if(s_axis_tlast && s_axis_tvalid)begin
				state_next = WAIT;
				rd_fix = 1;
			   end		
		end
	    end
*/ 
            WORD_1: begin
		if(fix_seq_num_vld) begin
                	if(s_axis_tvalid && m_axis_tready) begin
        	    	   out_fifo_rd_en = 1;
			   out_tkeep_next = s_axis_tkeep;
			   out_tlast_next = s_axis_tlast;
			   out_tuser_next = s_axis_tuser;
                           out_tdata_next = s_axis_tdata;
                           out_tvalid_next = 1;
                    	   state_next = WORD_2;
               		end
		end
            end


            WORD_2: begin
                  if(s_axis_tvalid && m_axis_tready) begin
        	    out_fifo_rd_en = 1;
		    out_tvalid_next = 1;
                    out_tdata_next = s_axis_tdata;
                    out_tkeep_next = s_axis_tkeep;
                    out_tlast_next = s_axis_tlast;
                    out_tuser_next = s_axis_tuser;
		    state_next = WORD_3; 
                  end
            end
	
	    WORD_3:begin
		if(s_axis_tvalid && m_axis_tready)begin
                    out_fifo_rd_en = 1;
                    out_tvalid_next = 1;
                    out_tdata_next = s_axis_tdata;
                    out_tkeep_next = s_axis_tkeep;
                    out_tlast_next = s_axis_tlast;
                    out_tuser_next = s_axis_tuser;
		    if(s_axis_tuser[63:48]==16'h05||s_axis_tuser[63:48]==16'h06||s_axis_tuser[63:48]==16'h07)begin // is fix pkt
		    //if(s_axis_tuser[47:32]==16'h02)begin 
				//out_tdata_next={in_fifo_out_tdata[255:56],{4'd3,msg_seq_num_reg_5},{4'd3,msg_seq_num_reg_4},{4'd3,msg_seq_num_reg_3},{4'd3,msg_seq_num_reg_2},{4'd3,msg_seq_num_reg_1},{4'd3,msg_seq_num_reg_0},8'h01}; 
			out_tdata_next={s_axis_tdata[255:56],{4'd3,fix_new_seq_num[23:20]},{4'd3,fix_new_seq_num[19:16]},
				       {4'd3,fix_new_seq_num[15:12]},{4'd3,fix_new_seq_num[11:8]},{4'd3,fix_new_seq_num[7:4]},
				       {4'd3,fix_new_seq_num[3:0]},8'h01};
		    end
		    else if(s_axis_tuser[63:48]==16'h08)begin
                        out_tdata_next={s_axis_tdata[255:48],{4'd3,fix_new_seq_num[23:20]},{4'd3,fix_new_seq_num[19:16]},
                                       {4'd3,fix_new_seq_num[15:12]},{4'd3,fix_new_seq_num[11:8]},{4'd3,fix_new_seq_num[7:4]},
                                       {4'd3,fix_new_seq_num[3:0]}};
		    end
		    if(s_axis_tlast)begin
			state_next = WORD_1;
			rd_fix_seq_num = 1;
		    end
		    else begin
		    	state_next = WORD_4;
		    end
		end
	    end

            WORD_4: begin
                  if(s_axis_tvalid && m_axis_tready) begin
                    out_fifo_rd_en = 1;
                    out_tvalid_next = 1;
                    out_tdata_next = s_axis_tdata;
                    out_tkeep_next = s_axis_tkeep;
                    out_tlast_next = s_axis_tlast;
                    out_tuser_next = s_axis_tuser;
		    if(s_axis_tuser[63:48]==16'h08)begin
		    	out_tdata_next = {8'h01,s_axis_tdata[247:0]};
		    end
                    if(s_axis_tlast)begin
                        state_next = WORD_1;
                    end
                    else begin
                        state_next = MOVE_PKT;
                    end
                  end
            end
            MOVE_PKT: begin
                  if(s_axis_tvalid && m_axis_tready) begin
                    out_fifo_rd_en = 1;
                    out_tvalid_next = 1;
                    out_tdata_next = s_axis_tdata;
                    out_tkeep_next = s_axis_tkeep;
                    out_tlast_next = s_axis_tlast;
                    out_tuser_next = s_axis_tuser;

                    if(s_axis_tlast) begin
                       state_next = WORD_1;
		       rd_fix_seq_num = 1;
		    end
		   
                  end
            end
/*
	    default :begin
		state_next = WORD_1;
	    end
*/
        endcase
   end
   always @(posedge clk) begin
	   if(reset) begin
		state <= WORD_1;
          	m_axis_tdata      <= 0;
          	m_axis_tkeep      <= 'hFFFFFFFF;
          	m_axis_tvalid     <= 0;
		m_axis_tuser      <= 0;
		m_axis_tlast      <= 0;
          	counter 	  <= 0;
          end
	   else begin
          	m_axis_tdata      <= out_tdata_next;
          	m_axis_tkeep      <= out_tkeep_next;
          	m_axis_tvalid     <= out_tvalid_next;
		m_axis_tuser	  <= out_tuser_next;
		m_axis_tlast      <= out_tlast_next;
	  	state 	    	  <= state_next;
          	counter 	  <= counter_next;

	   end
   end




endmodule
 
