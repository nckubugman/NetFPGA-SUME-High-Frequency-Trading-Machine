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


  module warrants_id_mapping
    #(parameter C_S_AXIS_DATA_WIDTH	= 256,
      parameter LUT_DEPTH		= 512,
      parameter LUT_DEPTH_BITS		= log2(LUT_DEPTH)
      )
   (

    // --- Interface to registers
    // --- Read port
    input [10:0]                                     warrants_id_mapping_rd_addr,
    input                                            warrants_id_mapping_rd_req,
    output reg [11:0]                                warrants_id_mapping_rd_data,
    output reg                                       warrants_id_mapping_rd_ack,

    // --- Write port
    input [10:0]		                     warrants_id_mapping_wr_addr,
    input                                            warrants_id_mapping_wr_req,
    input [11:0]                                     warrants_id_mapping_wr_data,
    output reg                                       warrants_id_mapping_wr_ack,

    input				parse_vld,
    output reg				warrants_fifo_rd,
    output 				parse_order_vld,
    output 				parse_order_rdy,
    input         in_fifo_rd,
    input [71:0] warrants_index_out,
    //output [216:0] order_index_out,
    output [240:0] order_index_out,

    // --- interface to order_id_mapping
    input [12:0]                                     order_id_mapping_rd_addr,
    input                                            order_id_mapping_rd_req,
    output [47:0]                                    order_id_mapping_rd_data,
    output                                           order_id_mapping_rd_ack,
    input [11:0]		                     order_id_mapping_wr_addr,
    input                                            order_id_mapping_wr_req,
    input [47:0]                                     order_id_mapping_wr_data,
    output                                           order_id_mapping_wr_ack,
    
    // --- order content
    output	  			order_rd,
//    input [215:0] 			order_out,
    input [239:0]			order_out,
    input        			order_vld,

    // counter wade
    output				cid_not_empty,    
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

   localparam	WAIT	= 1;
   localparam	READ_0	= 2;
   localparam	READ_1	= 4;
   localparam	WRITE_0	= 8;
   localparam	WRITE_1	= 16;
   localparam	DONE	= 32;

   //---------------------- Wires and regs----------------------------

   reg  [47:0] commodity_code_compare;
   reg  [47:0] commodity_code_compare_reg;
/*
   reg         in_fifo_wr_parse;
   reg         in_fifo_rd_parse;
   reg  [47:0] stock_code_in;
   wire [47:0] stock_code_out;
   wire        in_fifo_empty_parse;
   wire        in_fifo_nearly_full_parse;
   reg         write_en;
*/
   reg         in_fifo_wr;
   //reg         in_fifo_rd;
   //reg  [47:0] stock_code_in;
   //wire [47:0] stock_code_out;
   wire        in_fifo_empty;
   wire        in_fifo_nearly_full;

   reg  [11:0]				 din_data_a;
   reg  [10:0]				 addr_a;
   reg  [10:0]				 addr_a_reg;
   wire [11:0] 				 dout_a;
   wire        				 vld_a;
   reg					 we_a;
   
   wire			match_a;
   
   reg [5:0]                             state,state_next;

   reg [11:0]  warrants_id_mapping_rd_data_logic;
   reg         warrants_id_mapping_rd_ack_logic;
   reg [11:0]  warrants_id_mapping_wr_data_logic;
   reg         warrants_id_mapping_wr_ack_logic;


   reg         in_fifo_wr_ci;
   reg         in_fifo_rd_ci;
   reg  [71:0] commodity_index_in;
//   wire [21:0] commodity_index_out;
   wire        in_fifo_empty_ci;
   wire        in_fifo_nearly_full_ci;

   reg  [2:0]  current_owner;
   reg  [2:0]  current_owner_reg;

   wire [5:0]  total_warrants;

//   reg  [216:0] order_index_in;
   reg	[240:0] order_index_in;


   //wire [11:0] order_index_out;
   reg  [5:0]  counter;
   reg  [5:0]  counter_reg;

   reg  [199:0]	order_content_in;
   wire [199:0]	order_content_out;
   
   reg		order_match_req;
   reg		order_match_req_logic;
   wire		order_match_ack;
   reg  [13:0]	order_match_addr;
   reg  [13:0]  order_match_addr_reg;
   wire [47:0]  order_match_data;
//   wire [216:0]  order_content;
   wire [240:0] order_content;
 
   reg  [2:0]   wait_read; 
   reg  [2:0]   wait_read_reg; 
   //------------------------- Modules-------------------------------


   //-------------------------------------
   //     Small FIFO to store matched order
   //-------------------------------------
   //fallthrough_small_fifo #(.WIDTH(217), .MAX_DEPTH_BITS(16)) // 16
     fallthrough_small_fifo #(.WIDTH(241), .MAX_DEPTH_BITS(16))
      order_output_fifo
        (.din           (order_index_in),  // Data in
         .wr_en         (in_fifo_wr),             // Write enable
         .rd_en         (in_fifo_rd),    // Read the next word
         .dout          (order_index_out),
         .full          (),
         .nearly_full   (in_fifo_nearly_full),
         .prog_full     (),
         .empty         (in_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   order_id_mapping
	order_id_mapping
       ( 
         // --- Interface to registers
         // --- Read port
        .order_id_mapping_rd_addr       (order_id_mapping_rd_addr),  
        .order_id_mapping_rd_req        (order_id_mapping_rd_req),   
        .order_id_mapping_rd_data       (order_id_mapping_rd_data),    
        .order_id_mapping_rd_ack        (order_id_mapping_rd_ack),   
         // --- Write port
        .order_id_mapping_wr_addr       (order_id_mapping_wr_addr),  
        .order_id_mapping_wr_req        (order_id_mapping_wr_req),   
        .order_id_mapping_wr_data       (order_id_mapping_wr_data),    
        .order_id_mapping_wr_ack        (order_id_mapping_wr_ack),   

	.order_match_req		(order_match_req),
	.order_match_ack		(order_match_ack),
	.order_match_data		(order_match_data),
	.order_match_addr		(order_match_addr_reg),
	.order_content			(order_content),	

        .order_vld			(order_vld),
	.order_out			(order_out),
	.order_rd			(order_rd),
         // --- Misc
         .reset                    (reset),
         .clk                      (clk)
         );







   warrants_index_2048x12
      warrants_index_2048x12_0
      (.addr_a  (addr_a_reg),
       .din_a   (din_data_a),
       .dout_a  (dout_a),
       .clk_a   (clk),
       .we_a    (we_a)
      );

//------- Logic -------------------//
	assign parse_order_vld = !in_fifo_empty;
	assign total_warrants = warrants_index_out[12:2] - warrants_index_out[23:13] + 6'b1;
	assign parse_order_rdy = !in_fifo_nearly_full;	
	assign cid_not_empty = !in_fifo_empty;

    always @(*) begin
        
        state_next = state;
	we_a       = 'b0;
	din_data_a = 12'h0;
	addr_a     = addr_a_reg;
	warrants_id_mapping_rd_ack_logic  =  warrants_id_mapping_rd_ack;
        warrants_id_mapping_wr_ack_logic  =  warrants_id_mapping_wr_ack;
        warrants_id_mapping_rd_data_logic   =  warrants_id_mapping_rd_data;
	in_fifo_wr = 1'b0;
	order_index_in = 13'h0;
	warrants_fifo_rd = 'b0;				
        
        current_owner = 3'd1;
    	counter = counter_reg;    
	order_match_addr = order_match_addr_reg;
	order_match_req_logic = order_match_req;
	wait_read = wait_read_reg;

        case(state)
                WAIT: begin
                        if(warrants_id_mapping_wr_req && current_owner_reg != 3'd4) begin
                                addr_a = warrants_id_mapping_wr_addr;
                                state_next = WRITE_0;
				current_owner      =  3'd2;
                        end
                        else if(warrants_id_mapping_rd_req && current_owner_reg != 3'd4) begin
                                state_next = READ_0;
                                addr_a = warrants_id_mapping_rd_addr;
				current_owner      =  3'd2;
                        end
			else if(parse_vld && current_owner_reg != 3'd2) begin
				if(warrants_index_out[1:0] != 2'b0) begin
					if(counter_reg != total_warrants) begin
						addr_a = warrants_index_out[23:13] + counter_reg;	
						current_owner      =  3'd4;
						state_next = READ_0;
					end
					else begin
						warrants_fifo_rd = 'b1;				
						state_next = DONE;
						counter    = 'b0;
					end
				end
				else begin
					state_next = DONE;
					order_index_in = 'h0;
					in_fifo_wr = 1;
					warrants_fifo_rd = 'b1;				
				end
			end
                end
                WRITE_0: begin
                        state_next    =  WRITE_1;  
                end
                WRITE_1: begin
                	we_a       = 'b1;
                	din_data_a = warrants_id_mapping_wr_data;
	                warrants_id_mapping_wr_ack_logic = 'b1;
			state_next = DONE;
		end
		READ_0: begin
		            // wait one cycle to obtain result from BRAM
                        state_next    =  READ_1;  
			current_owner =  current_owner_reg;
		end
                READ_1: begin
		    if(current_owner_reg == 3'd4 && !in_fifo_nearly_full) begin
			   current_owner =  current_owner_reg;
			   order_match_addr = {warrants_index_out[1:0] ,dout_a};
			   order_match_req_logic = 'b1;
			   if(order_match_ack) begin
			   	counter			  = counter_reg + 6'd1; 
				order_index_in = order_content;
                           	in_fifo_wr                    =  (order_content[0] == 'b1)? 'b1: 'b0;
				order_match_req_logic		  = 'b0;
	                    	state_next                     =  DONE;
			   end
                    end
		    else if (current_owner_reg == 3'd2) begin
                	   warrants_id_mapping_rd_data_logic = dout_a;
			   warrants_id_mapping_rd_ack_logic = 'b1;
			   state_next = DONE;
		    end
		    
		end
		DONE: begin
			        warrants_id_mapping_wr_ack_logic = 'b0;
			        warrants_id_mapping_rd_ack_logic = 'b0;
			        state_next = WAIT;
				wait_read = 'b0;
		end
        endcase
     end
   

    always @(posedge clk) begin
        if(reset) begin
                state <= WAIT;
		addr_a_reg <= 'h0;
		warrants_id_mapping_rd_data        <=  'd0;
            	warrants_id_mapping_rd_ack       <=  1'b0;
            	warrants_id_mapping_wr_ack       <=  1'b0;
		current_owner_reg             <=  3'd1;
		counter_reg                   <=  6'h0;
		order_match_req		      <=  'b0;
		order_match_addr_reg	      <=  'h0;
		wait_read_reg		      <=  3'h0;
	    end
        else begin
		addr_a_reg <= addr_a;
                state <= state_next;
		warrants_id_mapping_rd_data        <=  warrants_id_mapping_rd_data_logic;
            	warrants_id_mapping_rd_ack       <=  warrants_id_mapping_rd_ack_logic;
            	warrants_id_mapping_wr_ack       <=   warrants_id_mapping_wr_ack_logic;
		current_owner_reg             <=  current_owner;
		counter_reg                   <=  counter;
		order_match_req		      <=  order_match_req_logic;
		order_match_addr_reg	      <=  order_match_addr;
		wait_read_reg		      <=  wait_read;
	    end
   end

endmodule // stock_id_mapping



