///////////////////////////////////////////////////////////////////////////////
//
// Module: pkt_buffer.v
// Description: pkt buffer for tcp checksum
//              
//              
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/100ps
module pkt_buffer_ip_tcp_checksum
  #(//Master AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH = 256,
    parameter C_S_AXIS_DATA_WIDTH = 256,
    parameter C_M_AXIS_TUSER_WIDTH  = 128,
    parameter C_S_AXIS_TUSER_WIDTH  = 128
   )
  (// --- interface to input fifo - fallthrough

    // Master Stream Ports (interface to data path)
    output reg[C_M_AXIS_DATA_WIDTH - 1:0]          m_axis_tdata,
    output reg[((C_M_AXIS_DATA_WIDTH / 8)) - 1:0]  m_axis_tkeep,
    output reg                                     m_axis_tvalid,
    output reg[C_M_AXIS_TUSER_WIDTH-1:0]    	   m_axis_tuser,
    input                                          m_axis_tready,
    output reg                                     m_axis_tlast,

    // Slave Stream Ports (interface to RX queues)
    input [C_S_AXIS_DATA_WIDTH - 1:0]              s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0]      s_axis_tkeep,
    input                                          s_axis_tvalid,
    input                                          s_axis_tlast,
    input [C_S_AXIS_TUSER_WIDTH-1:0]   		   s_axis_tuser,

   output reg			                   rd_ip_tcp,
   input [15:0]			                   tcp_new_checksum,
   input			                   tcp_checksum_vld,   
   output reg                                      out_fifo_rd_en,

   input 					   ip_checksum_vld,
   input [15:0]					   ip_new_checksum,   
	

   input reset,
   input clk
   
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
   localparam WAIT   =   1;
   localparam WORD_1 =   2;
   localparam WORD_2 =   4;
   localparam MOVE_PKT = 8;
   localparam NUM_STATES = 10;



   localparam C_AXIS_SRC_PORT_POS = 16;
   localparam C_AXIS_DST_PORT_POS = 24;

   //---------------------- Wires and regs -------------------------
   reg [NUM_STATES-1:0] state;
   reg [NUM_STATES-1:0] state_next;
   reg [C_M_AXIS_DATA_WIDTH-1:0]   m_axis_tdata_next;
   reg [C_M_AXIS_DATA_WIDTH/8-1:0] m_axis_tkeep_next;
   reg                  	   m_axis_tvalid_next;
   reg [C_M_AXIS_TUSER_WIDTH-1:0]  m_axis_tuser_next;
   reg				   m_axis_tlast_next;
   reg 				   out_fifo_rd_en_next;
   

   //-------------------------- Logic ------------------------------

   always @(*) begin
        m_axis_tkeep_next  = 32'h0;
        m_axis_tdata_next  = 256'h0;
	m_axis_tvalid_next = 0;
	m_axis_tlast_next  = 'h0;
	m_axis_tuser_next  = 128'h0;
        rd_ip_tcp = 'b0;
        out_fifo_rd_en = 'b0;
        state_next = state;
        case(state) 
/*
            WAIT: begin
		if(tcp_checksum_vld) begin
                  	if(s_axis_tvalid && m_axis_tready) begin
				
        	    	        out_fifo_rd_en = 1;
		          	m_axis_tdata_next = s_axis_tdata;
				m_axis_tuser_next = s_axis_tuser;
				m_axis_tlast_next = s_axis_tlast;
				m_axis_tkeep_next = s_axis_tkeep;
				m_axis_tvalid_next = 1;
				
				state_next = WORD_1;
                	end
		end
            end
*/
            WORD_1: begin
	       if(ip_checksum_vld&&tcp_checksum_vld)begin
                	if(s_axis_tvalid && m_axis_tready) begin
        	               out_fifo_rd_en = 1;
		               m_axis_tvalid_next = 1;
                   	       state_next = WORD_2;
                               m_axis_tdata_next = {s_axis_tdata[255:64],ip_new_checksum,s_axis_tdata[47:0]};
                               m_axis_tuser_next = s_axis_tuser;
                               m_axis_tlast_next = s_axis_tlast;
                               m_axis_tkeep_next = s_axis_tkeep;

                	end
		end
            end
	     WORD_2: begin
		//if(tcp_checksum_vld)begin
                	if(s_axis_tvalid && m_axis_tready) begin
        	    		out_fifo_rd_en = 1;
                    		state_next = MOVE_PKT;
				//if(s_axis_tuser[47:32]==16'h01)begin
                    		m_axis_tdata_next = {s_axis_tdata[255:112],{tcp_new_checksum},s_axis_tdata[95:0]};
				//end
/*
				else begin
					m_axis_tdata_next = {s_axis_tdata[255:112],{tcp_new_checksum-16'h5d},s_axis_tdata[95:0]};
				end
*/
                    		//m_axis_tdata_next = {s_axis_tdata[255:112],16'hffff,s_axis_tdata[95:0]};
                    		m_axis_tuser_next = s_axis_tuser;
                    		m_axis_tlast_next = s_axis_tlast;
                    		m_axis_tkeep_next = s_axis_tkeep;
                    		m_axis_tvalid_next = 1; 
				/*
		    		if(s_axis_tlast&& s_axis_tvalid) begin
                	 		state_next = WORD_1;
                	 		rd_ip_tcp = 1;
				end
				*/
                    	end
                //end
            end
            MOVE_PKT: begin
                if(s_axis_tvalid && m_axis_tready) begin
		     out_fifo_rd_en = 1;
                     m_axis_tvalid_next = 1; 		
		     m_axis_tdata_next = s_axis_tdata;
                     m_axis_tuser_next = s_axis_tuser;
                     m_axis_tlast_next = s_axis_tlast;
                     m_axis_tkeep_next = s_axis_tkeep;

		     if(s_axis_tlast&& s_axis_tvalid) begin
                	 state_next = WORD_1;
                	 rd_ip_tcp = 1;
                     end
                end
            end

        endcase
    end

   always @(posedge clk) begin
      	if(reset) begin
//      		state         <= WAIT;
		state 		      <= WORD_1;
               	m_axis_tdata          <= 'h0;
               	m_axis_tkeep          <= 'hFFFFFFFF;
               	m_axis_tvalid         <= 'b0;
		m_axis_tlast	      <= 'b0;
		m_axis_tuser	      <= 'b0;
      	end
      	else begin
      		state <= state_next;
      		m_axis_tdata <= m_axis_tdata_next;
      		m_axis_tkeep <= m_axis_tkeep_next;
               	m_axis_tvalid <= m_axis_tvalid_next;
		m_axis_tuser  <= m_axis_tuser_next;
		m_axis_tlast  <= m_axis_tlast_next;
		
		
      	end
   end



endmodule
 
