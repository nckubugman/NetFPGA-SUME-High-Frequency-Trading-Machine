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


  module stock_id_mapping
    #(parameter C_S_AXIS_DATA_WIDTH	= 256,
      parameter LUT_DEPTH		= 512,
      parameter LUT_DEPTH_BITS		= log2(LUT_DEPTH)
      )
   (// --- Interface to the previous stage
    input  [C_S_AXIS_DATA_WIDTH-1:0]   tdata,
    input  [C_S_AXIS_DATA_WIDTH/8-1:0] tkeep, //in_ctrl
    input  [127:0]		       tuser,
    input                              valid, //in_wr
    input			       tlast,

    input                              word_IP_DST_LO,

    // --- Interface to registers
    // --- Read port
    input [9:0]                                      stock_id_mapping_rd_addr,
    input                                            stock_id_mapping_rd_req,
    output reg [69:0]                                     stock_id_mapping_rd_data,
    output reg                                           stock_id_mapping_rd_ack,

    // --- Write port
    input [9:0]		                          stock_id_mapping_wr_addr,
    input                                            stock_id_mapping_wr_req,
    input [69:0]                                     stock_id_mapping_wr_data,
    output reg                                           stock_id_mapping_wr_ack,

    output				parse_vld,
    input         in_fifo_rd_ci,
    output [71:0] warrants_index_out,
    output        parse_rdy,

    input	  in_fifo_rd_order,

   // output [215:0] order_out,
    output [239:0] order_out,   

    output        order_vld,
    
    // counter wade
    output        sid_not_empty,


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
   wire [8:0]				 hash_addr_a;
   wire [8:0]				 hash_addr_b;

   reg  [47:0] stock_code_hash;
   reg  [47:0] stock_code_hash_reg;
   reg  [47:0] stock_code_compare;
   reg  [47:0] stock_code_compare_reg;


   reg         in_fifo_wr;
   reg         in_fifo_rd;
   reg  [47:0] stock_code_in;
   wire [47:0] stock_code_out;
   reg  [23:0] buy_in;
   reg  [23:0] sell_in;
   wire  [23:0] buy_out;
   wire  [23:0] sell_out;

   wire        in_fifo_empty;
   wire        in_fifo_nearly_full;
   reg         write_en;

   reg  [69:0]				 din_data_a;
   reg  [8:0]				 addr_a;
   reg  [8:0]				 addr_a_reg;
   wire [69:0] 				 dout_a;
   wire        				 vld_a;
   reg					 we_a;
   
   reg  [69:0]				 din_data_b;
   reg  [8:0]                 addr_b;
   reg  [8:0]                 addr_b_reg;
   wire [69:0]                  dout_b;
   wire                         vld_b;
   reg                     we_b;
   wire			match_a;
   wire			match_b;

   reg  [48:0]				din_data_price_a;
   reg  [8:0]				addr_price_a;
   reg  [8:0]				addr_price_a_reg;
   wire [48:0]				dout_price_a;
   reg					we_price_a;

   reg  [48:0]				din_data_price_b;
   reg  [8:0]				addr_price_b;
   reg  [8:0]				addr_price_b_reg;
   wire [48:0]				dout_price_b;
   reg					we_price_b;
   
   reg [5:0]                             state,state_next;

   reg [69:0]  stock_id_mapping_rd_data_logic;
   reg         stock_id_mapping_rd_ack_logic;
   reg [69:0]  stock_id_mapping_wr_data_logic;
   reg         stock_id_mapping_wr_ack_logic;

   reg [3:0]   wait_hash_reg;
   reg [3:0]   wait_hash;

   reg         in_fifo_wr_ci;
//   reg         in_fifo_rd_ci;
   reg  [71:0] warrants_index_in;
//   wire [21:0] commodity_index_out;
   wire        in_fifo_empty_ci;
   wire        in_fifo_nearly_full_ci;

   reg  [2:0]  current_owner;
   reg  [2:0]  current_owner_reg;
   

   reg         in_fifo_wr_order;

   //reg  [215:0] order_in;
   reg	 [239:0] order_in;   

   wire        in_fifo_empty_order;
   wire        in_fifo_nearly_full_order;
   reg         order_write_en;
   
   reg [7:0]			   counter;
   reg [7:0]			   counter_ip_feed;

   reg [3:0]			   reveal_flag;

   reg [23:0]			   buy_reg;
   reg [23:0]			   sell_reg;
//------------------------- Modules-------------------------------


   //-------------------------------------
   //     Small FIFO to store stock code
   //-------------------------------------
   fallthrough_small_fifo #(.WIDTH(96), .MAX_DEPTH_BITS(4)) // 4   48bits_stockID + 24bits_buyprice + 24bits_sellprice
      input_fifo
        (.din           ({stock_code_in, buy_in, sell_in}),  // Data in
         .wr_en         (in_fifo_wr),             // Write enable
         .rd_en         (in_fifo_rd),    // Read the next word
         .dout          ({stock_code_out, buy_out, sell_out}),
         .full          (),
         .nearly_full   (in_fifo_nearly_full),
         .prog_full     (),
         .empty         (in_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   //-------------------------------------
   //     Small FIFO to store comoddity index
   //-------------------------------------
   fallthrough_small_fifo #(.WIDTH(72), .MAX_DEPTH_BITS(4))  // 4
      input_fifo_ci
        (.din           (warrants_index_in),  // Data in
         .wr_en         (in_fifo_wr_ci),             // Write enable
         .rd_en         (in_fifo_rd_ci),    // Read the next word
         .dout          (warrants_index_out),
         .full          (),
         .nearly_full   (in_fifo_nearly_full_ci),
         .prog_full     (),
         .empty         (in_fifo_empty_ci),
         .reset         (reset),
         .clk           (clk)
         );

   //-------------------------------------
   //     Small FIFO to store order content
   //-------------------------------------
   //fallthrough_small_fifo #(.WIDTH(216), .MAX_DEPTH_BITS(4)) // 4
     fallthrough_small_fifo #(.WIDTH(240), .MAX_DEPTH_BITS(4)) 
      parse_input_fifo
        (.din           (order_in),  // Data in
         .wr_en         (in_fifo_wr_order),             // Write enable
         .rd_en         (in_fifo_rd_order),    // Read the next word
         .dout          (order_out),
         .full          (),
         .nearly_full   (in_fifo_nearly_full_order),
         .prog_full     (),
         .empty         (in_fifo_empty_order),
         .reset         (reset),
         .clk           (clk)
         );


   //----------------------------
   //     2 HASH UNITS
   //----------------------------
   one_at_a_time0
      one_at_a_time0
          (.clk(clk),
           .reset(reset),
           .in_data(stock_code_hash_reg),
           .out_data(hash_addr_a)
          );

   one_at_a_time1
      one_at_a_time1
          (.clk(clk),
           .reset(reset),
           .in_data(stock_code_hash_reg),
           .out_data(hash_addr_b)
          );


   stock_code_512x70
      stock_code_512x70_0
      (.addr_a  (addr_a_reg),
       .din_a   (din_data_a),
       .dout_a  (dout_a),
       .clk_a   (clk),
       .we_a    (we_a)
      );
      
     stock_code_512x70
       stock_code_512x70_1
         (.addr_a  (addr_b_reg),
          .din_a   (din_data_b),
          .dout_a  (dout_b),
          .clk_a   (clk),
          .we_a    (we_b)
         );  

     stock_price_512x49
       stock_price_512x49_0
         (.addr_a  (addr_price_a_reg),
          .din_a   (din_data_price_a),
          .dout_a  (dout_price_a),
          .clk_a   (clk),
          .we_a    (we_price_a)
         );  
     
     stock_price_512x49
       stock_price_512x49_1
         (.addr_a  (addr_price_b_reg),
          .din_a   (din_data_price_b),
          .dout_a  (dout_price_b),
          .clk_a   (clk),
          .we_a    (we_price_b)
         );  

//------- Logic -------------------//

	assign parse_vld = !in_fifo_empty_ci;
	assign match_a          =   dout_a[69:22] == stock_code_compare_reg;
        assign match_b          =   dout_b[69:22] == stock_code_compare_reg;
	assign parse_rdy	=   !in_fifo_nearly_full & !in_fifo_nearly_full_ci & !in_fifo_nearly_full_order;
	assign order_vld = !in_fifo_empty_order;
	assign sid_not_empty = (!in_fifo_empty || !in_fifo_empty_ci || !in_fifo_empty_order);
//------- stock code parser -------// only parse ip_feed
    always @(posedge clk) begin
        if(reset) begin
		stock_code_in <= 48'h0;
		in_fifo_wr    <= 'b0;
		counter_ip_feed <= 8'b0;
		buy_in        <= 24'h0;
		sell_in        <= 24'h0;
		reveal_flag   <= 4'b0;
	end
	else begin
		if(valid) begin
			counter_ip_feed <= counter_ip_feed + 1'b1;
		end
		if(counter_ip_feed == 8'd1) begin
			stock_code_in <= tdata[95:48];
		end
		if(counter_ip_feed == 8'd2) begin     // 8bits represent [7] = 'b1 => deal price & quan, [6:4] => 001~101 best five buy, [3:1] => 001~101 best five sell
			reveal_flag <= tdata[255:252];
			if(tdata[255] == 'b1) begin
				buy_in <= tdata[143:120];
			end
			else begin
				buy_in <= tdata[199:176];
			end
			if(tdata[255:252] == 4'b1010) begin
				sell_in <= tdata[31:8];
			end
			else if(tdata[255:252] == 4'b1001) begin
				sell_in <= tdata[87:64];
			end
			else if(tdata[255:252] == 4'b0011) begin
				sell_in <= tdata[31:8];
			end
			else if(tdata[255:252] == 4'b0010) begin
				sell_in <= tdata[87:64];
			end
			else if(tdata[255:252] == 4'b0001) begin
				sell_in <= tdata[143:120];
			end			
		end
		if(counter_ip_feed == 8'd3) begin
			if(reveal_flag == 4'b1101) begin
				sell_in <= tdata[119:96];
			end
			else if(reveal_flag == 4'b1100) begin
				sell_in <= tdata[175:152];
			end
			else if(reveal_flag == 4'b1011) begin
				sell_in <= tdata[231:208];
			end	
			else if(reveal_flag == 4'b0101) begin
				sell_in <= tdata[175:152];
			end
			else if(reveal_flag == 4'b0100) begin
				sell_in <= tdata[231:208];
			end
		end
		if(tlast && valid) begin
			in_fifo_wr <= (tuser[23:16] == 8'h01)? 1'b1: 1'b0;
			counter_ip_feed	   <= 8'd0;
			reveal_flag <= 4'b0;
		end
		else begin
			in_fifo_wr <= 1'b0;
		end
	end
    end

//------- order parser -------//
// [215:120] => OrigClOrdID, [119:80] => OrderID, [79:32] => Symbol, [31:24] => Side, [23:0] => Twsefields
//New [239:144] => OrigClOrdID, [143:104] => OrderID,[103:56]=> Symbol,[55:32]=>Qty,  [31:24] => Side, [23:0] => Twsefields
    always @(posedge clk) begin
        if(reset) begin
		counter <= 8'b0;
		//order_in <= 216'h0;
		order_in <= 240'h0;
		in_fifo_wr_order <= 'b0;
	end
	else begin
		if(valid) begin
			counter <= counter + 1'b1;
		end
		if(counter == 8'd4) begin
			//order_in[215:120] <= tdata[95:0];	
			order_in[239:144] <= tdata[95:0];
		end
		if(counter == 8'd5) begin
			//order_in[119:32] <= {tdata[223:184], tdata[71:24]};	
			order_in[143:56] <= {tdata[223:184], tdata[71:24]};
		end
		if(counter == 8'd6) begin //Side &  Qty
			//order_in[31:24] <= tdata[151:144];	
			order_in[55:32] <= tdata[207:184]; //Qty
			order_in[31:24]	<= tdata[151:144];
		end
		if(counter == 8'd7) begin
			order_in[23:16] <= tdata[31:24];	
		end
		if(counter == 8'd8) begin
			order_in[15:0] <= {tdata[159:152], tdata[95:88]};	
		end
		if(tlast && valid) begin
			in_fifo_wr_order <=(tuser[23:16] == 8'h04)? 1'b1: 1'b0;
			counter	   <= 8'b0;
		end
		else begin
			in_fifo_wr_order <= 1'b0;
		end
	end
    end


    always @(*) begin
        
        state_next = state;
	we_a       = 'b0;
	din_data_a = 70'h0;
	addr_a     = addr_a_reg;
	we_b       = 'b0;
        din_data_b = 70'h0;
        addr_b     = addr_b_reg;
	stock_id_mapping_rd_ack_logic  =  stock_id_mapping_rd_ack;
        stock_id_mapping_wr_ack_logic  =  stock_id_mapping_wr_ack;
        stock_id_mapping_rd_data_logic   =  stock_id_mapping_rd_data;
        stock_code_hash = stock_code_hash_reg;
        stock_code_compare = stock_code_compare_reg;
	in_fifo_rd = 1'b0;
	in_fifo_wr_ci = 1'b0;
	// hash counter
        wait_hash                      =  4'd0;
	warrants_index_in = 72'h0;
        
        current_owner = 3'd1;
	
	addr_price_a = addr_price_a_reg;        
	we_price_a = 'b0;
	addr_price_b = addr_price_b_reg;        
	we_price_b = 'b0;

        case(state)
                WAIT: begin
                        if(stock_id_mapping_wr_req && current_owner_reg != 3'd4) begin
                                addr_a = stock_id_mapping_wr_addr[8:0];
                                addr_b = stock_id_mapping_wr_addr[8:0];
                                state_next = WRITE_0;
				current_owner      =  3'd2;
                        end
                        else if(stock_id_mapping_rd_req && current_owner_reg != 3'd4) begin
                                state_next = READ_0;
                                addr_a = stock_id_mapping_rd_addr[8:0];
                                addr_b = stock_id_mapping_rd_addr[8:0];
                                addr_price_a = stock_id_mapping_rd_addr[8:0];
                                addr_price_b = stock_id_mapping_rd_addr[8:0];
				current_owner      =  3'd2;
                        end
			else if(!in_fifo_empty && current_owner_reg != 3'd2) begin
				stock_code_compare = stock_code_out;
				stock_code_hash    = stock_code_out;
				addr_a = hash_addr_a;
				addr_b = hash_addr_b;
				addr_price_a = hash_addr_a;
				addr_price_b = hash_addr_b;
				wait_hash          =  wait_hash_reg + 4'd1;
				current_owner      =  3'd4;
				if(wait_hash_reg == 4'd8) begin
					state_next = READ_0;
					din_data_price_a = {buy_out, sell_out, {1'b1}};
					din_data_price_b = {buy_out, sell_out, {1'b1}};
					buy_reg = buy_out;
					sell_reg = sell_out;
					// enable read signal to move one entry
		                        in_fifo_rd     =  1'b1;
				end
			end
                end
                WRITE_0: begin
                        state_next    =  WRITE_1;  
                end
                WRITE_1: begin
                    if(stock_id_mapping_wr_addr[9] == 'b0) begin
                	 we_a       = 'b1;
                	 din_data_a = stock_id_mapping_wr_data;
                    end
                    else if(stock_id_mapping_wr_addr[9] == 'b1) begin
                        we_b       = 'b1;
                        din_data_b = stock_id_mapping_wr_data;
                    end
	                stock_id_mapping_wr_ack_logic = 'b1;
			state_next = DONE;
		end
		READ_0: begin
		            // wait one cycle to obtain result from BRAM
                        state_next    =  READ_1;  
			current_owner =  current_owner_reg;
		end
                READ_1: begin
		    if(current_owner_reg == 3'd4 && !in_fifo_nearly_full_ci) begin
			   if(match_a) begin
				  if(dout_price_a[0] == 'b1) begin // if dout_price_a[0] == 'b1 means the stock has stored sell/buy price
				 	if((buy_reg[23:8] < dout_price_a[48:33]) || (buy_reg[23:8] == dout_price_a[48:33] && buy_reg[7:0] < dout_price_a[32:25])) begin
						warrants_index_in = {dout_a, 2'b01};
				  	end
				 	else if((sell_reg[23:8] > dout_price_a[24:8]) || (sell_reg[23:8] == dout_price_a[24:8] && sell_reg[7:0] > dout_price_a[7:0])) begin
						warrants_index_in = {dout_a, 2'b10};
				  	end
					else begin
						warrants_index_in = 72'h0;
					end
				  end
				  else begin
					warrants_index_in = 72'h0;
				  end
				  //warrants_index_in = {dout_a, 2'b01};
				  we_price_a = 'b1;
		           end
			   else if(match_b) begin
				  if(dout_price_b[0] == 'b1) begin
				  	if((buy_reg[23:8] < dout_price_b[48:33]) || (buy_reg[23:8] == dout_price_b[48:33] && buy_reg[7:0] < dout_price_b[32:25])) begin
						warrants_index_in = {dout_b, 2'b01};
				  	end
				  	else if((sell_reg[23:8] > dout_price_b[24:8]) || (sell_reg[23:8] == dout_price_b[24:8] && sell_reg[7:0] > dout_price_b[7:0])) begin
						warrants_index_in = {dout_b, 2'b10};
				  	end
				  	else begin
						warrants_index_in = 72'h0;
				  	end
					warrants_index_in = {dout_b, 2'b10};
					
				  end
				  else begin
					warrants_index_in = 72'h0;
				  end
				  //warrants_index_in = {dout_b, 2'b01};
				  we_price_b = 'b1;
			   end
			   else begin
				  warrants_index_in = 72'h0;
			   end
			   //commodity_index_in = dout_a;
                           in_fifo_wr_ci                    =  1'b1;
                    	   state_next                     =  DONE;
                    end
		    else if (current_owner_reg == 3'd2) begin
                    	   if(stock_id_mapping_rd_addr[9] == 'b0) begin
                	 	  //stock_id_mapping_rd_data_logic = dout_a;
                	 	  stock_id_mapping_rd_data_logic = {dout_price_a[48:1], 22'h0};
                	   end
                	   else if(stock_id_mapping_rd_addr[9] == 'b1) begin
                	 	  stock_id_mapping_rd_data_logic = {dout_price_b[48:1], 22'h0};
                           	  //stock_id_mapping_rd_data_logic = dout_b;
                    	   end
			   stock_id_mapping_rd_ack_logic = 'b1;
			   state_next = DONE;
		    end
		    
		end
		DONE: begin
			        stock_id_mapping_wr_ack_logic = 'b0;
			        stock_id_mapping_rd_ack_logic = 'b0;
				din_data_price_a = 49'h0;
				din_data_price_b = 49'h0;
				buy_reg = 'h0;
				sell_reg = 'h0;
			        state_next = WAIT;
		end
        endcase
     end
   

    always @(posedge clk) begin
        if(reset) begin
                state <= WAIT;
		addr_a_reg <= 'h0;
		addr_b_reg <= 'h0;
		stock_id_mapping_rd_data        <=  'd0;
            	stock_id_mapping_rd_ack       <=  1'b0;
            	stock_id_mapping_wr_ack       <=  1'b0;
                stock_code_hash_reg           <=  48'd0;
                stock_code_compare_reg        <=  48'd0;
		wait_hash_reg                 <=  4'd0;
		current_owner_reg             <=  3'd1;
		addr_price_a_reg		      <=  'h0;
		addr_price_b_reg		      <=  'h0;
	    end
        else begin
		addr_a_reg <= addr_a;
		addr_b_reg <= addr_b;
                state <= state_next;
		stock_id_mapping_rd_data        <=  stock_id_mapping_rd_data_logic;
            	stock_id_mapping_rd_ack       <=  stock_id_mapping_rd_ack_logic;
            	stock_id_mapping_wr_ack       <=   stock_id_mapping_wr_ack_logic;
            	stock_code_hash_reg           <=  stock_code_hash;
                stock_code_compare_reg        <=  stock_code_compare;
		wait_hash_reg                 <=  wait_hash;
		current_owner_reg             <=  current_owner;
		addr_price_a_reg		      <=  addr_price_a;
		addr_price_b_reg		      <=  addr_price_b;
	    end
   end

endmodule // stock_id_mapping



