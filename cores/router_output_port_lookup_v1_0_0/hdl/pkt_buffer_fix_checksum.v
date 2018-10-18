///////////////////////////////////////////////////////////////////////////////
//
// Module: pkt_buffer.v
// Description: pkt buffer for tcp checksum
//              
//              
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/100ps
module pkt_buffer_fix_checksum
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
   output reg                                       rd_fix,
   input [11:0]			                    fix_new_checksum,
   input			                    fix_checksum_vld,   
   input			                    is_fix,

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
   localparam PASS_PKT = 32;
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
	rd_fix ='b0;
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
		if(fix_checksum_vld) begin
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
		   
                    if(s_axis_tlast) begin
/*
                       if(s_axis_tuser[63:48]== 16'h27)begin //Test_req_Heartbeat
			   out_tdata_next = {s_axis_tdata[255:72]  ,{4'h3},fix_new_checksum[11:8],{4'h3},fix_new_checksum[7:4],{4'h3},fix_new_checksum[3:0],{8'h01},{40'h0}};
                       end
*/
		       if(s_axis_tuser[63:48]== 16'h05)begin
			   out_tdata_next = {s_axis_tdata[255:32],{4'h3},fix_new_checksum[11:8],{4'h3},fix_new_checksum[7:4],{4'h3},fix_new_checksum[3:0],{8'h01}};
		       end
                       else if(s_axis_tuser[63:48]== 16'h04)begin //Logon
		 	    out_tdata_next ={s_axis_tdata[255:40],{4'h3},fix_new_checksum[11:8],{4'h3},fix_new_checksum[7:4],{4'h3},fix_new_checksum[3:0],{8'h01},{8'h00}};
     		       end
                       else if(s_axis_tuser[63:48]== 16'h06||s_axis_tuser[63:48]==16'h07)begin //Heartbeat&Logout
                           out_tdata_next = {s_axis_tdata[255:104],{4'h3},fix_new_checksum[11:8],{4'h3},fix_new_checksum[7:4],{4'h3},fix_new_checksum[3:0],{8'h01},{8'h0},{64'h0}};
                       end
/*
		       else if(s_axis_tuser[63:48]==16'h08)begin //Order_cancel
			   out_tdata_next = {{4'h3},fix_new_checksum[11:8],{4'h3},fix_new_checksum[7:4],{4'h3},fix_new_checksum[3:0],{8'h01},s_axis_tdata[223:0]};
		       end
*/
                       else if(s_axis_tuser[63:48]==16'h08)begin //Order_cancel
                           //out_tdata_next = {s_axis_tdata[255:168],{4'h3},fix_new_checksum[11:8],{4'h3},fix_new_checksum[7:4],{4'h3},fix_new_checksum[3:0],{8'h01},{8'h00},128'h0}; 
                           out_tdata_next = {s_axis_tdata[255:112],{4'h3},fix_new_checksum[11:8],{4'h3},fix_new_checksum[7:4],{4'h3},fix_new_checksum[3:0],{8'h01},80'h0};
                       end

		       else begin
			   out_tdata_next = s_axis_tdata;	   
		       end

                       state_next = WORD_1;
                       rd_fix = 1;
                    end
                  end
            end

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
 
