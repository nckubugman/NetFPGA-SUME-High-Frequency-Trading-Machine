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


  module order_id_mapping
    #(parameter C_S_AXIS_DATA_WIDTH	= 256,
      parameter LUT_DEPTH		= 512,
      parameter LUT_DEPTH_BITS		= log2(LUT_DEPTH)
      )
   (
    // --- Interface to registers
    // --- Read port
    input [12:0]                                     order_id_mapping_rd_addr,
    input                                            order_id_mapping_rd_req,
    output reg [47:0]                                order_id_mapping_rd_data,
    output reg                                       order_id_mapping_rd_ack,

    // --- Write port
    input [11:0]		                     order_id_mapping_wr_addr,
    input                                            order_id_mapping_wr_req,
    input [47:0]                                     order_id_mapping_wr_data,
    output reg                                       order_id_mapping_wr_ack,

    input 					     order_match_req,
    output reg					     order_match_ack,
    input [13:0]				     order_match_addr,
    output reg [47:0]				     order_match_data,
//    output reg [216:0]				     order_content,
    output reg [240:0]				     order_content,

    // --- order content
    output reg	  			order_rd,
//    input [215:0] 			order_out,
    input [239:0]			order_out,

    input        			order_vld,
    
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
   localparam   WRITE_2 = 32;
   localparam	DONE	= 64;

   //---------------------- Wires and regs----------------------------

   reg  [47:0] commodity_code_compare;
   reg  [47:0] commodity_code_compare_reg;


   reg         in_fifo_wr;
   //reg         in_fifo_rd;
   reg  [47:0] stock_code_in;
   wire [47:0] stock_code_out;
   wire        in_fifo_empty;
   wire        in_fifo_nearly_full;
   reg         write_en;

   reg  [47:0]				 din_data_a;
   reg  [9:0]				 addr_a;
   reg  [9:0]				 addr_a_reg;
   wire [47:0] 				 dout_a;
   wire        				 vld_a;
   reg					 we_a;
   
   reg  [47:0]				 din_data_b;
   reg  [9:0]				 addr_b;
   reg  [9:0]				 addr_b_reg;
   wire [47:0] 				 dout_b;
   wire        				 vld_b;
   reg					 we_b;
   
   reg  [47:0]				 din_data_c;
   reg  [9:0]				 addr_c;
   reg  [9:0]				 addr_c_reg;
   wire [47:0] 				 dout_c;
   wire        				 vld_c;
   reg					 we_c;
   
   reg  [47:0]				 din_data_d;
   reg  [9:0]				 addr_d;
   reg  [9:0]				 addr_d_reg;
   wire [47:0] 				 dout_d;
   wire        				 vld_d;
   reg					 we_d;
   
   wire			match_a;
   wire			match_b;
   wire			match_c;
   wire			match_d;
   
   reg [6:0]                             state,state_next;

   reg [47:0]  order_id_mapping_rd_data_logic;
   reg         order_id_mapping_rd_ack_logic;
   reg [47:0]  order_id_mapping_wr_data_logic;
   reg         order_id_mapping_wr_ack_logic;

   reg [47:0]  order_match_data_logic;
   reg	       order_match_ack_logic;

   reg         in_fifo_wr_ci;
   reg         in_fifo_rd_ci;
   reg  [71:0] commodity_index_in;
//   wire [21:0] commodity_index_out;
   wire        in_fifo_empty_ci;
   wire        in_fifo_nearly_full_ci;

   reg  [3:0]  current_owner;
   reg  [3:0]  current_owner_reg;

   wire [5:0]  total_commodity;
   reg  [60:0] order_index_in;
   //wire [11:0] order_index_out;
   reg  [5:0]  counter;
   reg  [5:0]  counter_reg;


   reg  [47:0] order_code_hash;
   reg  [47:0] order_code_hash_reg;
   reg  [47:0] order_code_compare;
   reg  [47:0] order_code_compare_reg;
   wire [9:0]  hash_addr_a;
   wire [9:0]  hash_addr_b;
   wire [9:0]  hash_addr_c;
   wire [9:0]  hash_addr_d;
   reg [3:0]   wait_hash_reg;
   reg [3:0]   wait_hash;
//   reg [216:0]  order_content_logic;
   reg	[240:0] order_content_logic;

//   reg  [216:0]				 order_din_data_a;
   reg  [240:0]				order_din_data_a;
   reg  [11:0]				 order_addr_a;
   reg  [11:0]				 order_addr_a_reg;
//   wire [216:0] 				 order_dout_a;
   wire [240:0]				 order_dout_a;
   wire        				 order_vld_a;
   reg					 order_we_a;
   
//   reg  [216:0]				 order_din_data_b;
   reg  [240:0]				 order_din_data_b;
   reg  [11:0]				 order_addr_b;
   reg  [11:0]				 order_addr_b_reg;
//   wire [216:0] 				 order_dout_b;
   wire [240:0]				 order_dout_b;
   wire        				 order_vld_b;
   reg					 order_we_b;
   //------------------------- Modules-------------------------------




   //----------------------------
   //     4 HASH UNITS
   //----------------------------
   one_at_a_time0
      one_at_a_time0
          (.clk(clk),
           .reset(reset),
           .in_data(order_code_hash_reg),
           .out_data(hash_addr_a)
          );

   one_at_a_time1
      one_at_a_time1
          (.clk(clk),
           .reset(reset),
           .in_data(order_code_hash_reg),
           .out_data(hash_addr_b)
          );
   one_at_a_time2
      one_at_a_time2
          (.clk(clk),
           .reset(reset),
           .in_data(order_code_hash_reg),
           .out_data(hash_addr_c)
          );

   one_at_a_time3
      one_at_a_time3
          (.clk(clk),
           .reset(reset),
           .in_data(order_code_hash_reg),
           .out_data(hash_addr_d)
          );





   warrants_code_1024x48   // --- order table
      warrants_code_1024x48_0
      (.addr_a  (addr_a_reg),
       .din_a   (din_data_a),
       .dout_a  (dout_a),
       .clk_a   (clk),
       .we_a    (we_a)
      );
      
   warrants_code_1024x48  // --- order table
      warrants_code_1024x48_1
      (.addr_a  (addr_b_reg),
       .din_a   (din_data_b),
       .dout_a  (dout_b),
       .clk_a   (clk),
       .we_a    (we_b)
      );
   warrants_code_1024x48  // --- order table
      warrants_code_1024x48_2
      (.addr_a  (addr_c_reg),
       .din_a   (din_data_c),
       .dout_a  (dout_c),
       .clk_a   (clk),
       .we_a    (we_c)
      );
   warrants_code_1024x48  // --- order table 
      warrants_code_1024x48_3
      (.addr_a  (addr_d_reg),
       .din_a   (din_data_d),
       .dout_a  (dout_d),
       .clk_a   (clk),
       .we_a    (we_d)
      );

/*
   order_content_4096x217
      order_content_4096x217_0 // buy table
      (.addr_a  (order_addr_a_reg),
       .din_a   (order_din_data_a),
       .dout_a  (order_dout_a),
       .clk_a   (clk),
       .we_a    (order_we_a)
      );
   
   order_content_4096x217
      order_content_4096x217_1 // sell table
      (.addr_a  (order_addr_b_reg),
       .din_a   (order_din_data_b),
       .dout_a  (order_dout_b),
       .clk_a   (clk),
       .we_a    (order_we_b)
      );
*/

   order_content_4096x241
      order_content_4096x241_0 // buy table
      (.addr_a  (order_addr_a_reg),
       .din_a   (order_din_data_a),
       .dout_a  (order_dout_a),
       .clk_a   (clk),
       .we_a    (order_we_a)
      );

   order_content_4096x241
      order_content_4096x241_1 // sell table
      (.addr_a  (order_addr_b_reg),
       .din_a   (order_din_data_b),
       .dout_a  (order_dout_b),
       .clk_a   (clk),
       .we_a    (order_we_b)
      );

//------- Logic -------------------//
	assign match_a          =   dout_a == order_code_compare_reg;
        assign match_b          =   dout_b == order_code_compare_reg;
	assign match_c          =   dout_c == order_code_compare_reg;
        assign match_d          =   dout_d == order_code_compare_reg;

    always @(*) begin
        
        state_next = state;
	din_data_a = 48'h0;
	addr_a     = addr_a_reg;
	we_a       = 'b0;
	din_data_b = 48'h0;
	addr_b     = addr_b_reg;
	we_b       = 'b0;
	din_data_c = 48'h0;
	addr_c     = addr_c_reg;
	we_c       = 'b0;
	din_data_d = 48'h0;
	addr_d     = addr_d_reg;
	we_d       = 'b0;
	order_id_mapping_rd_ack_logic  =  order_id_mapping_rd_ack;
        order_id_mapping_wr_ack_logic  =  order_id_mapping_wr_ack;
        order_id_mapping_rd_data_logic   =  order_id_mapping_rd_data;
	order_match_data_logic		 =  order_match_data;
	order_match_ack_logic		 =  order_match_ack;
	order_content_logic              =  order_content;
	in_fifo_wr = 1'b0;
	// hash counter
        wait_hash                      =  4'd0;
	order_code_hash = order_code_hash_reg;
	order_code_compare = order_code_compare_reg;
	order_addr_a = order_addr_a_reg;
//	order_din_data_a = 217'h0;
        order_din_data_a = 241'h0;
        order_we_a = 'b0; 
	order_addr_b = order_addr_b_reg;
//	order_din_data_b = 217'h0;
	order_din_data_b = 241'h0;
        order_we_b = 'b0; 
        current_owner = 4'd1;
    	counter = counter_reg;    
	order_rd = 'b0;
        case(state)
                WAIT: begin
                        if(order_id_mapping_wr_req && current_owner_reg != 4'd4 && current_owner_reg != 4'd8) begin
                                addr_a = order_id_mapping_wr_addr[9:0];
                                addr_b = order_id_mapping_wr_addr[9:0];
                                addr_c = order_id_mapping_wr_addr[9:0];
                                addr_d = order_id_mapping_wr_addr[9:0];
                                state_next = WRITE_0;
				current_owner      =  4'd2;
                        end
                        else if(order_id_mapping_rd_req && current_owner_reg != 4'd4 && current_owner_reg != 4'd8) begin
                                state_next = READ_0;
                                addr_a = order_id_mapping_rd_addr[9:0];
                                addr_b = order_id_mapping_rd_addr[9:0];
                                addr_c = order_id_mapping_rd_addr[9:0];
                                addr_d = order_id_mapping_rd_addr[9:0];
				order_addr_a = order_id_mapping_rd_addr;
				order_addr_b = order_id_mapping_rd_addr;
				current_owner      =  4'd2;
                        end
			else if(order_match_req && current_owner_reg != 4'd2 && current_owner_reg != 4'd8) begin // warrants
                                state_next = READ_0;
                                addr_a = order_match_addr[9:0];
                                addr_b = order_match_addr[9:0];
                                addr_c = order_match_addr[9:0];
                                addr_d = order_match_addr[9:0];
				order_addr_a = order_match_addr;
				order_addr_b = order_match_addr;
				current_owner      =  4'd4;
			end
			else if(order_vld && current_owner_reg != 4'd2 && current_owner_reg != 4'd4) begin  // store order
/*
                                order_code_hash = order_out[79:32];
                                order_code_compare = order_out[79:32];
*/
                                order_code_hash = order_out[103:56];
                                order_code_compare = order_out[103:56];
				addr_a = hash_addr_a;
				addr_b = hash_addr_b;
				addr_c = hash_addr_c;
				addr_d = hash_addr_d;
				wait_hash          =  wait_hash_reg + 4'd1;
				current_owner      =  4'd8;
				if(wait_hash_reg == 4'd8) begin
					state_next = WRITE_0;
				end
			end
                end
                WRITE_0: begin
			current_owner =  current_owner_reg;
                        state_next    =  WRITE_1;  
                end
                WRITE_1: begin 
		    if(current_owner_reg == 4'd2) begin // load order_id_mapping table
                    	if(order_id_mapping_wr_addr[11:10] == 2'b00) begin
                		we_a       = 'b1;
                		din_data_a = order_id_mapping_wr_data;
                   	end
                    	else if(order_id_mapping_wr_addr[11:10] == 2'b01) begin
                		we_b       = 'b1;
                		din_data_b = order_id_mapping_wr_data;
                    	end
                    	else if(order_id_mapping_wr_addr[11:10] == 2'b10) begin
                		we_c       = 'b1;
                		din_data_c = order_id_mapping_wr_data;
                    	end
                    	else if(order_id_mapping_wr_addr[11:10] == 2'b11) begin
                		we_d       = 'b1;
                		din_data_d = order_id_mapping_wr_data;
                    	end
	                order_id_mapping_wr_ack_logic = 'b1;
		    	state_next = DONE;
		    end
		    else if(current_owner_reg == 4'd8) begin // write order content into order content table
			if(match_a) begin
				order_addr_a     = {2'b00, addr_a_reg};
				order_addr_b     = {2'b00, addr_a_reg};
			end
			else if(match_b) begin
				order_addr_a     = {2'b01, addr_b_reg};
				order_addr_b     = {2'b01, addr_b_reg};
			end
			else if(match_c) begin
				order_addr_a     = {2'b10, addr_c_reg};
				order_addr_b     = {2'b10, addr_c_reg};
			end
			else if(match_d) begin
				order_addr_a     = {2'b11, addr_d_reg};
				order_addr_b     = {2'b11, addr_d_reg};
			end
		    	state_next = WRITE_2;
		    end
		end
		WRITE_2: begin
                    //order_we_a       = 'b1;
		    order_we_a = (order_out[31:24] == 8'h31)? 'b1: 'b0;
		    order_we_b = (order_out[31:24] == 8'h32)? 'b1: 'b0;
                    order_din_data_a = {order_out, 1'b1};
                    order_din_data_b = {order_out, 1'b1};
		    state_next = DONE;
		    order_rd = 1'b1;

		end
		READ_0: begin
		            // wait one cycle to obtain result from BRAM
                        state_next    =  READ_1;  
			current_owner =  current_owner_reg;
		end
                READ_1: begin
		    if(current_owner_reg == 4'd4) begin
			   if(order_match_addr[11:10] == 2'b00) begin
			   	order_match_data_logic = dout_a;
			   end
			   else if(order_match_addr[11:10] == 2'b01) begin
			   	order_match_data_logic = dout_b;
			   end
			   else if(order_match_addr[11:10] == 2'b10) begin
			   	order_match_data_logic = dout_c;
			   end
			   else if(order_match_addr[11:10] == 2'b11) begin
			   	order_match_data_logic = dout_d;
			   end
			   // after sending cancel, clear the entry
                    	   //order_we_a       = 'b1;
                    	   //order_din_data_a = 217'h0;
			   

			   if(order_match_addr[13:12] == 2'b01) begin // buy
				   order_content_logic = order_dout_a;
                    	   	   order_we_a       = 'b1;
                    	           //order_din_data_a = 217'h0;
				   order_din_data_a = 241'h0;
			   end
			   else if(order_match_addr[13:12] == 2'b10) begin // sell
				   order_content_logic = order_dout_b;
                    	   	   order_we_b       = 'b1;
                    	           //order_din_data_b = 217'h0;
				   order_din_data_b = 241'h0;
			   end
			   else begin
				   order_content_logic = 'h0;
			   end
                           order_match_ack_logic = 'b1;
                    end
		    else if (current_owner_reg == 4'd2) begin
			if(order_id_mapping_rd_addr[12] == 'b0) begin
			    order_id_mapping_rd_data_logic = order_dout_a[80:33];
			    order_id_mapping_rd_ack_logic = 'b1;
			end
			else begin
			    order_id_mapping_rd_data_logic = order_dout_b[80:33];
			    order_id_mapping_rd_ack_logic = 'b1;
			end
		    end
		    state_next = DONE;
		end
		DONE: begin
			        order_id_mapping_wr_ack_logic = 'b0;
			        order_id_mapping_rd_ack_logic = 'b0;
				order_match_ack_logic         = 'b0;
			        state_next = WAIT;
		end
        endcase
     end
   

    always @(posedge clk) begin
        if(reset) begin
                state <= WAIT;
		addr_a_reg <= 'h0;
		addr_b_reg <= 'h0;
		addr_c_reg <= 'h0;
		addr_d_reg <= 'h0;
		order_id_mapping_rd_data        <=  'd0;
            	order_id_mapping_rd_ack       <=  1'b0;
            	order_id_mapping_wr_ack       <=  1'b0;
		current_owner_reg             <=  4'd1;
		counter_reg                   <=  6'h0;
		order_match_data              <=  48'h0;
		order_match_ack		      <=  1'b0;
		wait_hash_reg                 <=  4'd0;
		order_code_hash_reg           <=  48'h0;
		order_code_compare_reg	      <=  48'h0;
		order_addr_a_reg <= 'h0;
		order_addr_b_reg <= 'h0;
		order_content    <= 'h0;
	    end
        else begin
		addr_a_reg <= addr_a;
		addr_b_reg <= addr_b;
		addr_c_reg <= addr_c;
		addr_d_reg <= addr_d;
                state <= state_next;
		order_id_mapping_rd_data        <=  order_id_mapping_rd_data_logic;
            	order_id_mapping_rd_ack       <=  order_id_mapping_rd_ack_logic;
            	order_id_mapping_wr_ack       <=  order_id_mapping_wr_ack_logic;
		current_owner_reg             <=  current_owner;
		order_match_data              <=  order_match_data_logic;
		order_match_ack		      <=  order_match_ack_logic;
		wait_hash_reg                 <=  wait_hash;
		counter_reg                   <=  counter;
		order_code_hash_reg           <=  order_code_hash;
		order_code_compare_reg	      <=  order_code_compare;
		order_addr_a_reg <= order_addr_a;
		order_addr_b_reg <= order_addr_b;
		order_content    <= order_content_logic;
	    end
   end

endmodule // stock_id_mapping



