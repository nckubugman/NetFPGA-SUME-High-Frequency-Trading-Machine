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
********************************************************************************/


module check_pkt_sm
  #(parameter C_S_AXIS_DATA_WIDTH	= 256,
    parameter C_S_AXIS_TUSER_WIDTH	= 128,
    parameter NUM_QUEUES		= 8,
    parameter NUM_QUEUES_WIDTH		= log2(NUM_QUEUES)
  )
  (// --- interface to input fifo - fallthrough
   input                              in_fifo_vld,
   input [C_S_AXIS_DATA_WIDTH-1:0]    in_fifo_tdata,
   input			      in_fifo_tlast,
   input [C_S_AXIS_TUSER_WIDTH-1:0]   in_fifo_tuser,
   input [C_S_AXIS_DATA_WIDTH/8-1:0]  in_fifo_tkeep,
//   output reg                         in_fifo_rd_en,
   output			      in_fifo_rd_en,
   output			     fix_queue_empty,

   // --- interface to next module
   output reg                         		out_tvalid,
   output reg [C_S_AXIS_DATA_WIDTH-1:0]		out_tdata,
   output reg [C_S_AXIS_TUSER_WIDTH-1:0]	out_tuser,     // new checksum assuming decremented TTL
   input                              		out_tready,
   output reg [C_S_AXIS_DATA_WIDTH/8-1:0]  	out_keep,
   output reg					out_tlast,


   // --- interface to stock id module
   output reg                                   out_stock_id_tvalid,
   output reg [C_S_AXIS_DATA_WIDTH-1:0]         out_stock_id_tdata,
   output reg [C_S_AXIS_TUSER_WIDTH-1:0]        out_stock_id_tuser,     // new checksum assuming decremented TTL
   input                                        out_stock_id_tready,
   output reg [C_S_AXIS_DATA_WIDTH/8-1:0]       out_stock_id_keep,
   output reg                                   out_stock_id_tlast,

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

   //------------------- Internal parameters -----------------------
   localparam NUM_STATES          = 16;
   localparam WAIT_PREPROCESS_RDY = 1;
   localparam HEADER_0		  = 32;
   localparam HEADER_1		  = 64;
   localparam PAYLOAD_0  	  = 128;
   localparam PAYLOAD_1		  = 256;
   localparam PAYLOAD_2		  = 512;
   localparam PAYLOAD_3		  = 1024;
   localparam PAYLOAD_4		  = 2048;
   localparam PAYLOAD_5		  = 4096;
   localparam PAYLOAD_6		  = 8192;

   localparam PASS_CONNECT_PKT	  = 13102;
   localparam DONE		  = 13103;
   localparam WORD_1		  = 13104;
   localparam WORD_2		  = 13105;
   localparam WORD_3		  = 13106;
   localparam PASS_STOCK_ID_PKT	  = 13107;
   localparam PASS_UDP_FORMAT_6_PKT = 13108;
   localparam PASS_REPORT_PKT     = 13109;

   
   localparam C_AXIS_SRC_PORT_POS = 16;
   localparam C_AXIS_DST_PORT_POS = 24;
   //---------------------- Wires and regs -------------------------
   
   reg [NUM_STATES-1:0]		state;
   reg [NUM_STATES-1:0]		state_next;
   reg				out_tvalid_next;
   reg				out_tlast_next;
   reg [C_S_AXIS_DATA_WIDTH-1:0]	out_tdata_next;
   reg [C_S_AXIS_TUSER_WIDTH-1:0]	out_tuser_next;
   reg [C_S_AXIS_DATA_WIDTH/8-1:0]	out_keep_next;



   reg                          out_stock_id_tvalid_next;
   reg                          out_stock_id_tlast_next;
   reg [C_S_AXIS_DATA_WIDTH-1:0]        out_stock_id_tdata_next;
   reg [C_S_AXIS_TUSER_WIDTH-1:0]       out_stock_id_tuser_next;
   reg [C_S_AXIS_DATA_WIDTH/8-1:0]      out_stock_id_keep_next;

   reg [47:0]           src_mac_sel;

   reg [NUM_QUEUES-1:0] dst_port;
   reg [NUM_QUEUES-1:0] dst_port_next;

   reg                  to_from_cpu;
   reg                  to_from_cpu_next;



   wire	[NUM_QUEUES-1:0] output_port;		
  
   //---------- fifo wires ----------
   reg                   		in_fifo_rd;
 
   wire                  		in_fifo_nearly_full;
   wire                   		in_fifo_empty;


 
   wire [C_S_AXIS_DATA_WIDTH/8-1:0]     in_fifo_out_tkeep;
   wire [C_S_AXIS_DATA_WIDTH-1:0]     in_fifo_out_tdata;
   wire 			      in_fifo_out_tlast;
   wire [C_S_AXIS_TUSER_WIDTH-1:0]    in_fifo_out_tuser;
	

   wire           fix_order_word_OPT_PAYLOAD;
   wire           fix_order_word_IP_DST_LO;
   wire           fix_order_word_IP_DST_HI;




   
   // --- wade connect state machine
   reg			  send_order_over;

  reg  		tlast_reg;
 

  reg [3:0]      counter_next;
  reg [3:0]	 counter;

 

   reg                     flag;
   reg			   flag_next;



   reg[31:0]    send_fix_pkt_counter;
   reg[31:0]    send_fix_pkt_counter_next;





   assign fix_queue_empty = in_fifo_empty;
   assign order_sended = send_order_over;

//   assign in_fifo_rd_en = parse_rdy&parse_order_rdy&!in_fifo_nearly_full;
   assign in_fifo_rd_en = !in_fifo_nearly_full;
//--new---





fallthrough_small_fifo #(.WIDTH(1+C_S_AXIS_TUSER_WIDTH+(C_S_AXIS_DATA_WIDTH/8)+C_S_AXIS_DATA_WIDTH), .MAX_DEPTH_BITS(15))
      input_fifo
        (.din           ({in_fifo_tlast,in_fifo_tuser, in_fifo_tkeep, in_fifo_tdata}),  // Data in
         .wr_en         (in_fifo_vld),             // Write enable
         .rd_en         (in_fifo_rd),    // Read the next word
         .dout          ({in_fifo_out_tlast, in_fifo_out_tuser,in_fifo_out_tkeep, in_fifo_out_tdata}),
         .full          (),
         .nearly_full   (in_fifo_nearly_full),
         .prog_full     (),
         .empty         (in_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );



/*
preprocess_control
#(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH)
       ) preprocess_control
       ( // --- Interface to the previous stage
         // --- Input
          .tdata                    (in_fifo_tdata),
          .valid                    (in_fifo_vld & ~in_fifo_nearly_full),
          .tlast                    (in_fifo_tlast),

         // --- Interface to other preprocess blocks
         // --- Output
         .word_IP_DST_HI            (fix_order_word_IP_DST_HI),
         .word_IP_DST_LO            (fix_order_word_IP_DST_LO),
         .word_OPT_PAYLOAD          (fix_order_word_OPT_PAYLOAD),

         // --- Misc
         // --- Input
         .reset                     (reset),
         .clk                       (clk)
);



*/

//binary_to_bcd  fix_seq_number(.binary(checksum_final), .thousand(thousand), .hundred(hundred), .ten(ten), .one(one));



   always @(*) begin
/*
      out_tlast_next                = in_fifo_out_tlast;
      out_tdata_next                = in_fifo_out_tdata;
      out_tuser_next                = in_fifo_out_tuser;
      out_keep_next                = in_fifo_out_tkeep;
      out_tvalid_next               = 0;

      out_stock_id_tlast_next	    = in_fifo_out_tlast;
      out_stock_id_tdata_next	    = in_fifo_out_tdata;
      out_stock_id_tuser_next	    = in_fifo_out_tuser;
      out_stock_id_keep_next	    = in_fifo_out_tkeep;
      out_stock_id_tvalid_next      = 0;
*/

      out_tlast_next                = 'h0;
      out_tdata_next		    = 256'h0;
      out_tuser_next		    = 128'h0;
      out_keep_next		    = 32'h0;
      out_tvalid_next               = 0;
      out_stock_id_tlast_next	    = 'h0;
      out_stock_id_tdata_next	    = 256'h0;
      out_stock_id_tuser_next	    = 128'h0;
      out_stock_id_keep_next	    = 32'h0;
      out_stock_id_tvalid_next	    = 0;

      state_next                    = state;
      
       
      in_fifo_rd 		   = 0;

      case(state)
/*
       WAIT_PREPROCESS_RDY: begin
	           in_fifo_rd   =  1'b0;
                   out_tvalid_next   =  1'b0;
                   
		    if(!in_fifo_empty && in_fifo_out_tuser[31:24]==8'h01)begin
                        state_next   =  PASS_PKT;  
		//	state_next = WORD_1;
                       
		       counter_next =  counter + 1'b1;
                   end

	           if(parse_order_vld && out_tready) begin
        	        if(order_index_out[0] == 1'b1) begin
        	                state_next = HEADER_0;
        	        end
		   end
                   else begin
                        rd_preprocess_info          = 1;
            	   end

		   
      end     
*/

       WAIT_PREPROCESS_RDY: begin


		   in_fifo_rd = 1'b0;
		   out_tvalid_next = 1'b0;   
		   out_stock_id_tvalid_next = 1'b0;
	
		   //src port = mac0 output port = nf0
		   if(!in_fifo_empty && in_fifo_out_tuser[23:16]==8'h01)begin 
			//state_next = PASS_STOCK_ID_PKT;
			state_next = PASS_UDP_FORMAT_6_PKT;
		   end
		   //src port = nf1  output port = mac3
		   else if(!in_fifo_empty && in_fifo_out_tuser[23:16]==8'h08)begin
			state_next = PASS_CONNECT_PKT;
		   end	 
		   //src port = mac1 or nf3 output port = nf0
		   else if(!in_fifo_empty && in_fifo_out_tuser[23:16]==8'h04)begin
			state_next = PASS_STOCK_ID_PKT;
	           end
		   //src port = mac3 output port = mac 2
            else if(!in_fifo_empty && in_fifo_out_tuser[23:16]==8'h40)begin
                state_next = PASS_REPORT_PKT;
            end
		   else begin
			state_next = WAIT_PREPROCESS_RDY;
		   end	   
		  
        end


        PASS_UDP_FORMAT_6_PKT: begin

                    if(out_stock_id_tready&& !in_fifo_empty) begin
                            in_fifo_rd     = 1'b1;
                            out_stock_id_tdata_next  = in_fifo_out_tdata;
                            out_stock_id_tvalid_next = 1;
                            out_stock_id_tuser_next  = in_fifo_out_tuser;
                            out_stock_id_tlast_next  = in_fifo_out_tlast;
                            out_stock_id_keep_next   =  in_fifo_out_tkeep;


                            //if(in_fifo_out_tlast && in_fifo_vld ) begin
                            if(in_fifo_out_tlast)begin
                                state_next       = WAIT_PREPROCESS_RDY;
                                //in_fifo_rd  = 1'b0;
                            end

                   end

        end




        PASS_STOCK_ID_PKT: begin

                    if(out_stock_id_tready&& !in_fifo_empty) begin
                            in_fifo_rd     = 1'b1;
                            out_stock_id_tdata_next  = in_fifo_out_tdata;
                            out_stock_id_tvalid_next = 1;
                            out_stock_id_tuser_next  = in_fifo_out_tuser;
                            out_stock_id_tlast_next  = in_fifo_out_tlast;
                            out_stock_id_keep_next   =  in_fifo_out_tkeep;
     

                            //if(in_fifo_out_tlast && in_fifo_vld ) begin
			    if(in_fifo_out_tlast)begin
                                state_next       = WAIT_PREPROCESS_RDY;
                                //in_fifo_rd  = 1'b0;
                            end

                   end

        end






        PASS_CONNECT_PKT: begin

                    if(out_tready&& !in_fifo_empty) begin
		    //if(out_tready)begin
                            in_fifo_rd     = 1'b1;
                            out_tdata_next = in_fifo_out_tdata;
                            out_tvalid_next = 1;
                            out_tuser_next = in_fifo_out_tuser;
                            out_tlast_next  = in_fifo_out_tlast;
                            out_keep_next  =  in_fifo_out_tkeep;			    
  
                        //if(in_fifo_out_tlast && in_fifo_vld ) begin
			if(in_fifo_out_tlast)begin
                                state_next       = WAIT_PREPROCESS_RDY;
				//in_fifo_rd  = 1'b0;
                        end
		
                   end
           
        end
        PASS_REPORT_PKT: begin

                    if(out_tready&& !in_fifo_empty) begin
                    //if(out_tready)begin
                            in_fifo_rd     = 1'b1;
                            out_tdata_next = in_fifo_out_tdata;
                            out_tvalid_next = 1;
                            out_tuser_next = in_fifo_out_tuser;
                            out_tlast_next  = in_fifo_out_tlast;
                            out_keep_next  =  in_fifo_out_tkeep;

                        //if(in_fifo_out_tlast && in_fifo_vld ) begin
                        if(in_fifo_out_tlast)begin
                                state_next       = WAIT_PREPROCESS_RDY;
                                //in_fifo_rd  = 1'b0;
                        end

                   end

        end


      endcase // case(state)
   end // always @ (*)








   always @(posedge clk) begin
      if(reset) begin
         state             <= WAIT_PREPROCESS_RDY;
	 out_tvalid        <= 0;
         out_tdata         <= 0;
         out_tuser         <= 0;
         out_keep	   <= 0;
         out_tlast	   <= 0;
       
	 out_stock_id_tvalid <= 0;
	 out_stock_id_tdata  <= 0;
	 out_stock_id_tuser  <= 0;
	 out_stock_id_keep   <= 0;
	 out_stock_id_tlast  <= 0;
      end
      else begin
         state             <= state_next;
	 out_tvalid	   <= out_tvalid_next;
         out_tlast         <= out_tlast_next;
         out_tdata	   <= out_tdata_next;
         out_tuser         <= out_tuser_next;
         out_keep         <= out_keep_next;
        
	 out_stock_id_tvalid <= out_stock_id_tvalid_next;
         out_stock_id_tdata  <= out_stock_id_tdata_next;
	 out_stock_id_tuser  <= out_stock_id_tuser_next;
	 out_stock_id_keep   <= out_stock_id_keep_next;
	 out_stock_id_tlast  <= out_stock_id_tlast_next;

	// flag		 <= flag_next;
	// in_fifo_rd	 <= in_fifo_rd_next;
      end // else: !if(reset)
   end // always @ (posedge clk)




endmodule // op_lut_process_sm

