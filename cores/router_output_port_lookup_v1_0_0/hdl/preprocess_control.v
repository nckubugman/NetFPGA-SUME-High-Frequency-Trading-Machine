/*******************************************************************************
*
* Copyright (C) 2010, 2011 The Board of Trustees of The Leland Stanford
*                          Junior University
* Copyright (C) grg, Gianni Antichi
* All rights reserved.
*
* This software was developed by
* Stanford University and the University of Cambridge Computer Laboratory
* under National Science Foundation under Grant No. CNS-0855268,
* the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
* by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
* as part of the DARPA MRC research programme.
*
* @NETFPGA_LICENSE_HEADER_START@
*
* Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
* license agreements. See the NOTICE file distributed with this work for
* additional information regarding copyright ownership. NetFPGA licenses this
* file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
* "License"); you may not use this file except in compliance with the
* License. You may obtain a copy of the License at:
*
* http://www.netfpga-cic.org
*
* Unless required by applicable law or agreed to in writing, Work distributed
* under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
* CONDITIONS OF ANY KIND, either express or implied. See the License for the
* specific language governing permissions and limitations under the License.
*
* @NETFPGA_LICENSE_HEADER_END@
*
*******************************************************************************/


  module preprocess_control
    #(parameter C_S_AXIS_DATA_WIDTH=256
      )
   (// --- Interface to the previous stage
    
    input [C_S_AXIS_DATA_WIDTH-1:0]    tdata,
    input			       valid,
    input			       tlast,

    // --- Interface to other preprocess blocks
    output reg                         word_IP_DST_HI,
    output reg                         word_IP_DST_LO,
    output reg			       word_OPT_PAYLOAD,

    output reg			       word_OPT_PAYLOAD_2,
    output reg			       word_OPT_PAYLOAD_3,
    output reg			       word_OPT_PAYLOAD_4,


    // --- Misc

    input                              reset,
    input                              clk
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

   //------------------ Internal Parameter ---------------------------

   localparam WORD_1           = 1;
   localparam WORD_2           = 2;
   localparam WORD_3	       = 4;
   localparam WORD_4	       = 8;
   localparam WORD_5	       = 16;
   localparam WORD_6	       = 32;
   localparam WAIT_EOP         = 64;

   //---------------------- Wires/Regs -------------------------------
   reg [10:0]                            state, state_next;

   //------------------------ Logic ----------------------------------

   always @(*) begin
      state_next = state;
      word_IP_DST_HI = 0;
      word_IP_DST_LO = 0;
      word_OPT_PAYLOAD = 0;

      case(state)
        WORD_1: begin
           if(valid) begin
              word_IP_DST_HI = 1;
              state_next     = WORD_2;
           end
        end

        WORD_2: begin
           if(valid) begin
              word_IP_DST_LO = 1;
	      if(tlast)
		state_next = WORD_1;
	      else
              	state_next = WORD_3;
           end
        end

        WORD_3: begin
           if(valid) begin
              word_OPT_PAYLOAD = 1;
	      if(tlast)
		state_next = WORD_1;
	      else
		state_next = WORD_4;
           end
        end

	WORD_4: begin
	   if(valid)begin
		word_OPT_PAYLOAD_2 = 1;
		if(tlast)
		  state_next = WORD_1;
		else
		  state_next = WORD_5;
	   end
	end


        WORD_5: begin
           if(valid)begin
                word_OPT_PAYLOAD_3 = 1;
                if(tlast)
                  state_next = WORD_1;
                else
                  state_next = WORD_6;
           end
        end

        WORD_6: begin
           if(valid) begin
              word_OPT_PAYLOAD_4 = 1;
              if(tlast)
                state_next = WORD_1;
              else
                state_next = WAIT_EOP;
           end
        end



        WAIT_EOP: begin
           if(valid && tlast) begin
              state_next = WORD_1;
           end
        end
      endcase // case(state)
   end // always @ (*)

   always@(posedge clk) begin
      if(reset) begin
         state <= WORD_1;
      end
      else begin
         state <= state_next;
      end
   end

endmodule // op_lut_hdr_parser
