//
// Copyright (c) 2015 University of Cambridge 
// All rights reserved.
//
// This software was developed by
// Stanford University and the University of Cambridge Computer Laboratory
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
// as part of the DARPA MRC research programme.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more
// contributor license agreements.  See the NOTICE file distributed with this
// work for additional information regarding copyright ownership.  NetFPGA
// licenses this file to you under the NetFPGA Hardware-Software License,
// Version 1.0 (the "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//
//
`timescale 1ns / 1ps
//`default_nettype none  

module tx_riffa_axi #(
    parameter C_PCI_DATA_WIDTH  = 128,
    parameter C_PREAM_VALUE 	= 16'hCAFE 	
)(
    // RIFFA inputs
    input wire                          CLK,
    input wire                          RST,

    input                          CHNL_RX,
    input [(C_PCI_DATA_WIDTH-1):0]   CHNL_RX_DATA,           
    input                           CHNL_RX_DATA_VALID,     
    input                           CHNL_RX_LAST,           
	input  [31:0]                   CHNL_RX_LEN,
    input  [30:0]                   CHNL_RX_OFF,                
	output                          CHNL_RX_DATA_REN,
    output                          CHNL_RX_ACK,

    // AXI-Master outputs
    output reg [(C_PCI_DATA_WIDTH-1):0]   tdata,
    output reg [((C_PCI_DATA_WIDTH/8)-1):0] tkeep,
    output reg [127:0]         			tuser,
    output reg                          tvalid,
    output reg                          tlast,
    input wire                          tready      

);

//////////////////////////////////////////////////////////////////////
// functions
//////////////////////////////////////////////////////////////////////
// last tkeep calculation
function [15:0] last_tkeep_conv; 
  input  [4:0] last_tkeep_value;
  begin : func_last_tstrb
  	integer i;
    last_tkeep_conv = 0;	 
	 if (!last_tkeep_value) begin
	 	last_tkeep_conv = {2{8'hFF}};
	 end	
	 else begin
		for (i=0; i < last_tkeep_value; i = i+1)
				last_tkeep_conv[i] = 1'b1;
	 end			
  end			
endfunction


//////////////////////////////////////////////////////////////////////
// localparams
//////////////////////////////////////////////////////////////////////
localparam max_dws_trans_lp    = (C_PCI_DATA_WIDTH/32);

// FSM1
localparam fsm_width_lp    	    = 3;
localparam DELAY            	= 3'd0,
           WAIT_RIFFA_ACTIVE    = 3'd1,
           GENERATE_RIFFA_ACK   = 3'd2,
  	       METADATA_DETECTED    = 3'd3,			
           AXI_TRANSACTION      = 3'd4,
           TRANSACTION_ERROR    = 3'd5;


//////////////////////////////////////////////////////////////////////
// signals
//////////////////////////////////////////////////////////////////////
reg [fsm_width_lp-1:0] 	 fsm_state, fsm_state_next;

reg                    	     riffa_rack;
reg                    	     riffa_rren;
wire                         riffa_word_valid;

reg [29:0]                   mt_num_words;
reg [63:0]                   mt_tstamp;
reg [15:0]                   mt_len_B;
reg [7:0]                    mt_src_port;
reg [7:0]                    mt_des_port;
reg [15:0]                   mt_last_tkeep;
reg [15:0]		             mt_pream;
wire 			             pream_detected;

reg [29:0]      	         words2send;
reg [29:0]                   words_sent;

wire 			             words_sent_max;
reg 			             word_cntr_enbl;

reg [127:0]		 	         tuser_next;
reg [C_PCI_DATA_WIDTH/8-1:0] last_tkeep; 

/////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////
// assignments
assign CHNL_RX_ACK      = riffa_rack;
assign CHNL_RX_DATA_REN = riffa_rren;

// FSM comb
always @ (*) begin : riffa_axi_comb_l
	fsm_state_next       = fsm_state;
	
	// ctrl
	word_cntr_enbl       = 1'b0;

	// RIFFA
	riffa_rren           = 1'b0;
	riffa_rack           = 1'b0;

	// AXIS control
	tuser_next	         = tuser;
	tvalid		         = 1'b0;	
    tlast		         = 1'b0;	

	case (fsm_state)

        DELAY : begin
		    fsm_state_next  = WAIT_RIFFA_ACTIVE; 
	    end

        WAIT_RIFFA_ACTIVE : begin
		    // wait for RIFFA CHNL to be ready.
            // if CHNL is high, handshake process starts.
            // LAST, LEN, OFF signals are valid as well.
		    if (CHNL_RX) begin			
			    fsm_state_next  = GENERATE_RIFFA_ACK;
		    end
	    end	 

	    GENERATE_RIFFA_ACK: begin
		    if (CHNL_RX) begin
			    riffa_rack      = 1'b1;
			    fsm_state_next  = METADATA_DETECTED;
			    
			    // if valid immediately, consume now.
			    // first should be metadata, go to axis after.
			    if (CHNL_RX_DATA_VALID) begin
                        riffa_rren      = 1'b1;
                        tuser_next      = {mt_tstamp, 32'h0, mt_des_port, mt_src_port, mt_len_B};
                                        
                        fsm_state_next  = (pream_detected) ? AXI_TRANSACTION : TRANSACTION_ERROR;
                end
		    end
	    end	
	
	    METADATA_DETECTED : begin
	    	if (CHNL_RX && CHNL_RX_DATA_VALID) begin
                // RIffa Words are consumed in the same clk cycle as
                // AXIS words. By asserting rren now, we consume
                // metadata but it is not send by AXIS.
			    // Check preamble is detected to keep correct 
			    // frame/metadata alignment.
			    riffa_rren      = 1'b1;
	    		tuser_next	    = {mt_tstamp, 32'h0, mt_des_port, mt_src_port, mt_len_B};
						
	    		fsm_state_next  = (pream_detected) ? AXI_TRANSACTION : TRANSACTION_ERROR;
		    end		
	    end  

	    AXI_TRANSACTION : begin			
		    // send AXIS data now.
		    // allow continuous or transmission with backpressure.
		    if (CHNL_RX && CHNL_RX_DATA_VALID && tready) begin
		        // assert valid & ren only when 
		        // fresh data is available    
		        tvalid 	         = 1'b1; 			   	
        	    riffa_rren       = 1'b1;
			    word_cntr_enbl   = 1'b1; // inc next clk
				
			    if (words_sent_max) begin
				    tlast           = 1'b1;
				    fsm_state_next  = DELAY;
			    end			
		    end	
	     end
	
	     TRANSACTION_ERROR : begin
		    // send interrupt to reset the system
		    // or do whatever is required to get the lock back.
		    // For now just stay in this state forever.	
            // TODO: trigger soft reset through AXI-Lite interface.
    		fsm_state_next  = TRANSACTION_ERROR;
	     end	
 		
	     default : begin
		    fsm_state_next  = DELAY;	
	     end	
	endcase
end

// FSM seq
always @ (posedge CLK) begin : riffa_axi_seq_l
	if (RST) begin
		fsm_state       <= DELAY;
		tuser	        <= 'b0;			
	end
	else begin
	 	fsm_state       <= fsm_state_next;
		tuser	        <= tuser_next;		
	end
end

// AXIS tdata & tkeep 
always @ (*) begin : axis_data_keep_l
	tdata  = 'b0;
	tkeep  = {2{8'hFF}};
	
	if (fsm_state == AXI_TRANSACTION) begin
		tdata  = CHNL_RX_DATA;
		tkeep  = (tlast) ? last_tkeep : {2{8'hFF}};	
	end
end

// metadata extraction
assign pream_detected = (mt_pream == C_PREAM_VALUE);
always @ (*) begin : metadata_comb_l
	mt_tstamp 		= 'b0;
	mt_len_B	 	= 'b0;
	mt_des_port		= 'b0;
	mt_src_port		= 'b0;
	mt_last_tkeep	= 'b0;
	mt_pream		= 'b0;
			
	mt_num_words    = 'b0;
		
	if ((fsm_state == GENERATE_RIFFA_ACK) || (fsm_state == METADATA_DETECTED)) begin
		mt_tstamp 	  = CHNL_RX_DATA[127:64];
	 	mt_pream	  = CHNL_RX_DATA[63:48];
		mt_len_B	  = CHNL_RX_DATA[47:32];
		mt_des_port	  = CHNL_RX_DATA[23:16];
		mt_src_port	  = CHNL_RX_DATA[7:0];  
 		
		// derived from above					
		mt_last_tkeep = last_tkeep_conv(CHNL_RX_DATA[35:32]);

		mt_num_words  = (CHNL_RX_LEN[1:0]) ? CHNL_RX_LEN[31:2] + 1'b1 : CHNL_RX_LEN[31:2];	// len with metadata 		
	end
end

// word counters && last tkeep
assign words_sent_max = ((words2send - 1'b1) == words_sent);
always @ (posedge CLK) begin : wcount_seq_l
	if (RST) begin
		words2send  <= 'b0;
		words_sent	<= 'b0;
		last_tkeep	<= 'b0;
	end
	else begin
	    words_sent	<= 'b0;   
	    //inc only in this state
	    if (fsm_state == AXI_TRANSACTION) begin
		  words_sent <= (word_cntr_enbl) ? (words_sent + 1'b1) : words_sent;
		end
		     

		if((fsm_state == GENERATE_RIFFA_ACK) || (fsm_state == METADATA_DETECTED)) begin
			last_tkeep  <= mt_last_tkeep;
			words2send  <= mt_num_words - 1'b1; //len without metadata
		end
	end		
end

endmodule
