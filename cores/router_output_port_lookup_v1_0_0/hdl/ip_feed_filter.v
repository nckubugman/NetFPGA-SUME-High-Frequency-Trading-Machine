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
Modified : Yi-Fang Huang
Date :  2018/3/3
*******************************************************************************/


  module ip_feed_filter
    #(parameter C_S_AXIS_DATA_WIDTH	= 256,
      parameter LUT_DEPTH		= 32,
      parameter LUT_DEPTH_BITS		= log2(LUT_DEPTH),
      //new
      parameter IO_QUEUE_STAGE_NUM	= 8'hff
      )
   (// --- Interface to the previous stage
    input  [C_S_AXIS_DATA_WIDTH-1:0]   tdata,
    input  [C_S_AXIS_DATA_WIDTH/8-1:0] tkeep, //in_ctrl
    input                              valid, //in_wr
    input			       tlast,

    // --- Interface to process block
    output                             ip_feed_filter_vld,
    output                             is_ip_feed,
    input                              rd_ip_feed_filter_result,

    // --- Interface to preprocess block
    input                              word_IP_DST_HI,
    input                              word_IP_DST_LO,
    input                              word_OPT_PAYLOAD,
 
    /*output             is_udp_wire,
    output             esccode_is_1b_wire,
    output             is_format_six_wire,
    output             with_terminal_code_wire,*/
    // --- Interface to registers
    
    /*
      // --- read port
     input [4:0]            listed_stock_format_type_stats_rd_addr,   // address in array to read
     input                  listed_stock_format_type_stats_rd_req, 
     output reg [15:0]      listed_stock_format_type_stats_rd_value, 
     output reg             listed_stock_format_type_stats_rd_ack, 
	 
	  // --- read port
     input [4:0]            OTC_stock_format_type_stats_rd_addr,   // address in array to read
     input                  OTC_stock_format_type_stats_rd_req, 
     output reg [15:0]      OTC_stock_format_type_stats_rd_value, 
     output reg             OTC_stock_format_type_stats_rd_ack, 
	 
	  // --- read port
     input [4:0]            listed_warrant_format_type_stats_rd_addr,   // address in array to read
     input                  listed_warrant_format_type_stats_rd_req, 
     output reg [15:0]      listed_warrant_format_type_stats_rd_value, 
     output reg             listed_warrant_format_type_stats_rd_ack,
	 
	  // --- read port
     input [4:0]            OTC_warrant_format_type_stats_rd_addr,   // address in array to read
     input                  OTC_warrant_format_type_stats_rd_req, 
     output reg [15:0]      OTC_warrant_format_type_stats_rd_value, 
     output reg             OTC_warrant_format_type_stats_rd_ack,
     */
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
   localparam	PROCESS	= 2;

   //---------------------- Wires and regs----------------------------

// --- 19 types of listed stock 
reg    [15:0]         listed_stock_format_type_stats_reg         [18:0];
reg    [15:0]         listed_stock_format_type_stats_reg_nxt     [18:0];
// --- 19 types of OTC stock 
reg    [15:0]         OTC_stock_format_type_stats_reg            [18:0];
reg    [15:0]         OTC_stock_format_type_stats_reg_nxt        [18:0];
// --- 19 types of listed warrant
reg    [15:0]         listed_warrant_format_type_stats_reg       [18:0];
reg    [15:0]         listed_warrant_format_type_stats_reg_nxt   [18:0];
// --- 19 types of OTC warrant
reg    [15:0]         OTC_warrant_format_type_stats_reg          [18:0];
reg    [15:0]         OTC_warrant_format_type_stats_reg_nxt      [18:0];


// --- increment logic variable
reg    [15:0]   listed_stock_selected_reg;
reg    [15:0]   OTC_stock_selected_reg;
reg    [15:0]   listed_warrant_selected_reg;
reg    [15:0]   OTC_warrant_selected_reg;
wire   [15:0]   listed_stock_increment_reg;
wire   [15:0]   OTC_stock_increment_reg;
wire   [15:0]   listed_warrant_increment_reg;
wire   [15:0]   OTC_warrant_increment_reg;

// --- register for data bus 
reg    [7:0]    format_type_reg;
reg    [255:0]  tdata_reg;


// --- flag wires & registers
reg             is_udp;
reg             esccode_is_1b;
reg             is_format_six;
reg             with_terminal_code;
reg             is_eop_delay;
reg             ctrl_prev_is_0;
reg             is_listed_stock_dst_ip;
reg             is_listed_stock_dst_port;
reg             is_OTC_stock_dst_ip;
reg             is_OTC_stock_dst_port;
reg             is_listed_warrant_dst_ip;
reg             is_listed_warrant_dst_port;
reg             is_OTC_warrant_dst_ip;
reg             is_OTC_warrant_dst_port;
wire            ip_feed_check;
wire            is_eop;
reg             wr_en;


// --- fifo signal
wire            empty;



// --- for variable
integer         i;


// --- for DEBUG
reg    [15:0]   counter1;
reg    [15:0]   counter2;
reg    [15:0]   counter3;
reg    [15:0]   counter4;


// --------------------------  Parameter for now --------------------------------//
parameter [31:0]  listed_stock_dst_ip     = 32'hEF130233, OTC_stock_dst_ip      = 32'hEF130234, 
                  listed_warrant_dst_ip   = 32'hEF130235, OTC_warrant_dst_ip    = 32'hEF130236;
				 
parameter [15:0]  listed_stock_dst_port   = 16'h2423,     OTC_stock_dst_port    = 16'h2424,
                  listed_warrant_dst_port = 16'h0000,     OTC_warrant_dst_port  = 16'h0000;

  

   //------------------------- Modules-------------------------------

   // 1 cycle read latency, 16 cycles write latency
   // priority encoded for the smallest address. 
   // Single match unencoded match addresses
 
   fallthrough_small_fifo #(.WIDTH(1), .MAX_DEPTH_BITS(2))
      ip_feed_filter_fifo
        (.din           (ip_feed_check),			// Data in
         .wr_en         (is_eop_delay),            	// Write enable
         .rd_en         (rd_ip_feed_filter_result),     // Read the next word
         .dout          (is_ip_feed),
         .full          (),
         .nearly_full   (),
         .prog_full     (),
         .empty         (empty),
         .reset         (reset),
         .clk           (clk)
         );



   //------------------------- Logic --------------------------------

assign          ip_feed_filter_vld  = !empty;

assign          ip_feed_check       = is_udp & esccode_is_1b & with_terminal_code & is_format_six;
//assign          ip_feed_check       = is_udp & esccode_is_1b & is_format_six;

assign          is_eop              = (ctrl_prev_is_0 && tkeep!=0); ; //&& in_ctrl !=0

/* increment selected register */
assign          listed_stock_increment_reg    = listed_stock_selected_reg   + 1'd1;
assign          OTC_stock_increment_reg       = OTC_stock_selected_reg      + 1'd1;
assign          listed_warrant_increment_reg  = listed_warrant_selected_reg + 1'd1;
assign          OTC_warrant_increment_reg     = OTC_warrant_selected_reg    + 1'd1;


/* select register relate to format_type if ip & port found */
/*always @(format_type_reg                        or listed_stock_format_type_stats_reg[0]  or listed_stock_format_type_stats_reg[1]  or listed_stock_format_type_stats_reg[2]  or 
         listed_stock_format_type_stats_reg[3]  or listed_stock_format_type_stats_reg[4]  or listed_stock_format_type_stats_reg[5]  or listed_stock_format_type_stats_reg[6]  or 
		 listed_stock_format_type_stats_reg[7]  or listed_stock_format_type_stats_reg[8]  or listed_stock_format_type_stats_reg[9]  or listed_stock_format_type_stats_reg[10] or 
		 listed_stock_format_type_stats_reg[11] or listed_stock_format_type_stats_reg[12] or listed_stock_format_type_stats_reg[13] or listed_stock_format_type_stats_reg[14] or 
		 listed_stock_format_type_stats_reg[15] or listed_stock_format_type_stats_reg[16] or listed_stock_format_type_stats_reg[17] or listed_stock_format_type_stats_reg[18] or
		 is_listed_stock_dst_ip                 or is_listed_stock_dst_port)
begin
    listed_stock_selected_reg = 16'd0;
    if(is_listed_stock_dst_ip && is_listed_stock_dst_port) begin
        case(format_type_reg)
        8'h01   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[0];
        8'h02   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[1];
        8'h03   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[2];
        8'h04   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[3];
        8'h05   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[4];
        8'h06   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[5];
        8'h07   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[6];
        8'h08   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[7];
        8'h09   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[8];
        8'h10   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[9];
        8'h11   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[10];
        8'h12   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[11];
        8'h13   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[12];
        8'h14   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[13];
        8'h15   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[14];
        8'h16   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[15];
        8'h17   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[16];
        8'h18   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[17];
        8'h19   :   listed_stock_selected_reg = listed_stock_format_type_stats_reg[18];
        endcase
	end
end
*/

/* select register relate to format_type if ip & port found */
/*always @(format_type_reg                     or OTC_stock_format_type_stats_reg[0]  or OTC_stock_format_type_stats_reg[1]  or OTC_stock_format_type_stats_reg[2]  or 
         OTC_stock_format_type_stats_reg[3]  or OTC_stock_format_type_stats_reg[4]  or OTC_stock_format_type_stats_reg[5]  or OTC_stock_format_type_stats_reg[6]  or 
		 OTC_stock_format_type_stats_reg[7]  or OTC_stock_format_type_stats_reg[8]  or OTC_stock_format_type_stats_reg[9]  or OTC_stock_format_type_stats_reg[10] or 
		 OTC_stock_format_type_stats_reg[11] or OTC_stock_format_type_stats_reg[12] or OTC_stock_format_type_stats_reg[13] or OTC_stock_format_type_stats_reg[14] or 
		 OTC_stock_format_type_stats_reg[15] or OTC_stock_format_type_stats_reg[16] or OTC_stock_format_type_stats_reg[17] or OTC_stock_format_type_stats_reg[18] or
		 is_OTC_stock_dst_ip    or is_OTC_stock_dst_port)
begin
    OTC_stock_selected_reg = 16'd0;
    if(is_OTC_stock_dst_ip && is_OTC_stock_dst_port) begin
        case(format_type_reg)
        8'h01   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[0];
        8'h02   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[1];
        8'h03   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[2];
        8'h04   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[3];
        8'h05   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[4];
        8'h06   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[5];
        8'h07   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[6];
        8'h08   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[7];
        8'h09   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[8];
        8'h10   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[9];
        8'h11   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[10];
        8'h12   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[11];
        8'h13   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[12];
        8'h14   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[13];
        8'h15   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[14];
        8'h16   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[15];
        8'h17   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[16];
        8'h18   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[17];
        8'h19   :   OTC_stock_selected_reg = OTC_stock_format_type_stats_reg[18];
        endcase
	end
end
*/
/* select register relate to format_type if ip & port found */
/*always @(format_type_reg                          or listed_warrant_format_type_stats_reg[0]  or listed_warrant_format_type_stats_reg[1]  or listed_warrant_format_type_stats_reg[2]  or 
         listed_warrant_format_type_stats_reg[3]  or listed_warrant_format_type_stats_reg[4]  or listed_warrant_format_type_stats_reg[5]  or listed_warrant_format_type_stats_reg[6]  or 
		 listed_warrant_format_type_stats_reg[7]  or listed_warrant_format_type_stats_reg[8]  or listed_warrant_format_type_stats_reg[9]  or listed_warrant_format_type_stats_reg[10] or 
		 listed_warrant_format_type_stats_reg[11] or listed_warrant_format_type_stats_reg[12] or listed_warrant_format_type_stats_reg[13] or listed_warrant_format_type_stats_reg[14] or 
		 listed_warrant_format_type_stats_reg[15] or listed_warrant_format_type_stats_reg[16] or listed_warrant_format_type_stats_reg[17] or listed_warrant_format_type_stats_reg[18] or
		 is_listed_warrant_dst_ip    or is_listed_warrant_dst_port)
begin
    listed_warrant_selected_reg = 16'd0;
    if(is_listed_warrant_dst_ip && is_listed_warrant_dst_port) begin
        case(format_type_reg)
        8'h01   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[0];
        8'h02   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[1];
        8'h03   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[2];
        8'h04   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[3];
        8'h05   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[4];
        8'h06   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[5];
        8'h07   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[6];
        8'h08   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[7];
        8'h09   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[8];
        8'h10   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[9];
        8'h11   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[10];
        8'h12   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[11];
        8'h13   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[12];
        8'h14   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[13];
        8'h15   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[14];
        8'h16   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[15];
        8'h17   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[16];
        8'h18   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[17];
        8'h19   :   listed_warrant_selected_reg = listed_warrant_format_type_stats_reg[18];
        endcase
	end
end
*/
/* select register relate to format_type if ip & port found */
/*always @(format_type_reg                       or OTC_warrant_format_type_stats_reg[0]  or OTC_warrant_format_type_stats_reg[1]  or OTC_warrant_format_type_stats_reg[2]  or 
         OTC_warrant_format_type_stats_reg[3]  or OTC_warrant_format_type_stats_reg[4]  or OTC_warrant_format_type_stats_reg[5]  or OTC_warrant_format_type_stats_reg[6]  or 
		 OTC_warrant_format_type_stats_reg[7]  or OTC_warrant_format_type_stats_reg[8]  or OTC_warrant_format_type_stats_reg[9]  or OTC_warrant_format_type_stats_reg[10] or 
		 OTC_warrant_format_type_stats_reg[11] or OTC_warrant_format_type_stats_reg[12] or OTC_warrant_format_type_stats_reg[13] or OTC_warrant_format_type_stats_reg[14] or 
		 OTC_warrant_format_type_stats_reg[15] or OTC_warrant_format_type_stats_reg[16] or OTC_warrant_format_type_stats_reg[17] or OTC_warrant_format_type_stats_reg[18] or
		 is_OTC_warrant_dst_ip                 or is_OTC_warrant_dst_port)
begin
    OTC_warrant_selected_reg = 16'd0;
    if(is_OTC_warrant_dst_ip && is_OTC_warrant_dst_port) begin
        case(format_type_reg)
        8'h01   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[0];
        8'h02   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[1];
        8'h03   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[2];
        8'h04   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[3];
        8'h05   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[4];
        8'h06   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[5];
        8'h07   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[6];
        8'h08   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[7];
        8'h09   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[8];
        8'h10   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[9];
        8'h11   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[10];
        8'h12   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[11];
        8'h13   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[12];
        8'h14   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[13];
        8'h15   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[14];
        8'h16   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[15];
        8'h17   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[16];
        8'h18   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[17];
        8'h19   :   OTC_warrant_selected_reg = OTC_warrant_format_type_stats_reg[18];
        endcase
	end
end

// determine next register value
always @(format_type_reg                        or listed_stock_format_type_stats_reg[0]  or listed_stock_format_type_stats_reg[1]  or listed_stock_format_type_stats_reg[2]  or 
         listed_stock_format_type_stats_reg[3]  or listed_stock_format_type_stats_reg[4]  or listed_stock_format_type_stats_reg[5]  or listed_stock_format_type_stats_reg[6]  or 
		 listed_stock_format_type_stats_reg[7]  or listed_stock_format_type_stats_reg[8]  or listed_stock_format_type_stats_reg[9]  or listed_stock_format_type_stats_reg[10] or 
		 listed_stock_format_type_stats_reg[11] or listed_stock_format_type_stats_reg[12] or listed_stock_format_type_stats_reg[13] or listed_stock_format_type_stats_reg[14] or 
		 listed_stock_format_type_stats_reg[15] or listed_stock_format_type_stats_reg[16] or listed_stock_format_type_stats_reg[17] or listed_stock_format_type_stats_reg[18] or
         is_udp                                 or esccode_is_1b                          or with_terminal_code                     or listed_stock_increment_reg             or
		 is_listed_stock_dst_ip                 or is_listed_stock_dst_port) 
begin
    for(i=0;i<19;i=i+1)
        listed_stock_format_type_stats_reg_nxt[i] = listed_stock_format_type_stats_reg[i];
		
    if(is_udp && esccode_is_1b && with_terminal_code && is_listed_stock_dst_ip && is_listed_stock_dst_port) begin
		case(format_type_reg)
		8'h01   :  listed_stock_format_type_stats_reg_nxt[0]   =  listed_stock_increment_reg;
		8'h02   :  listed_stock_format_type_stats_reg_nxt[1]   =  listed_stock_increment_reg;
		8'h03   :  listed_stock_format_type_stats_reg_nxt[2]   =  listed_stock_increment_reg;
		8'h04   :  listed_stock_format_type_stats_reg_nxt[3]   =  listed_stock_increment_reg;
		8'h05   :  listed_stock_format_type_stats_reg_nxt[4]   =  listed_stock_increment_reg;
		8'h06   :  listed_stock_format_type_stats_reg_nxt[5]   =  listed_stock_increment_reg;
		8'h07   :  listed_stock_format_type_stats_reg_nxt[6]   =  listed_stock_increment_reg;
		8'h08   :  listed_stock_format_type_stats_reg_nxt[7]   =  listed_stock_increment_reg;
		8'h09   :  listed_stock_format_type_stats_reg_nxt[8]   =  listed_stock_increment_reg;
		8'h10   :  listed_stock_format_type_stats_reg_nxt[9]   =  listed_stock_increment_reg;
		8'h11   :  listed_stock_format_type_stats_reg_nxt[10]  =  listed_stock_increment_reg;
		8'h12   :  listed_stock_format_type_stats_reg_nxt[11]  =  listed_stock_increment_reg;
		8'h13   :  listed_stock_format_type_stats_reg_nxt[12]  =  listed_stock_increment_reg;
		8'h14   :  listed_stock_format_type_stats_reg_nxt[13]  =  listed_stock_increment_reg;
		8'h15   :  listed_stock_format_type_stats_reg_nxt[14]  =  listed_stock_increment_reg;
		8'h16   :  listed_stock_format_type_stats_reg_nxt[15]  =  listed_stock_increment_reg;
		8'h17   :  listed_stock_format_type_stats_reg_nxt[16]  =  listed_stock_increment_reg;
		8'h18   :  listed_stock_format_type_stats_reg_nxt[17]  =  listed_stock_increment_reg;
		8'h19   :  listed_stock_format_type_stats_reg_nxt[18]  =  listed_stock_increment_reg;
        endcase
	end
end

// determine next register value
always @(format_type_reg                     or OTC_stock_format_type_stats_reg[0]  or OTC_stock_format_type_stats_reg[1]  or OTC_stock_format_type_stats_reg[2]  or 
         OTC_stock_format_type_stats_reg[3]  or OTC_stock_format_type_stats_reg[4]  or OTC_stock_format_type_stats_reg[5]  or OTC_stock_format_type_stats_reg[6]  or 
		 OTC_stock_format_type_stats_reg[7]  or OTC_stock_format_type_stats_reg[8]  or OTC_stock_format_type_stats_reg[9]  or OTC_stock_format_type_stats_reg[10] or 
		 OTC_stock_format_type_stats_reg[11] or OTC_stock_format_type_stats_reg[12] or OTC_stock_format_type_stats_reg[13] or OTC_stock_format_type_stats_reg[14] or 
		 OTC_stock_format_type_stats_reg[15] or OTC_stock_format_type_stats_reg[16] or OTC_stock_format_type_stats_reg[17] or OTC_stock_format_type_stats_reg[18] or
         is_udp                              or esccode_is_1b                       or with_terminal_code                  or OTC_stock_increment_reg             or
		 is_OTC_stock_dst_ip                 or is_OTC_stock_dst_port) 
begin
    for(i=0;i<19;i=i+1)
        OTC_stock_format_type_stats_reg_nxt[i] = OTC_stock_format_type_stats_reg[i];
		
    if(is_udp && esccode_is_1b && with_terminal_code && is_OTC_stock_dst_ip && is_OTC_stock_dst_port) begin
		case(format_type_reg)
		8'h01   :  OTC_stock_format_type_stats_reg_nxt[0]   =  OTC_stock_increment_reg;
		8'h02   :  OTC_stock_format_type_stats_reg_nxt[1]   =  OTC_stock_increment_reg;
		8'h03   :  OTC_stock_format_type_stats_reg_nxt[2]   =  OTC_stock_increment_reg;
		8'h04   :  OTC_stock_format_type_stats_reg_nxt[3]   =  OTC_stock_increment_reg;
		8'h05   :  OTC_stock_format_type_stats_reg_nxt[4]   =  OTC_stock_increment_reg;
		8'h06   :  OTC_stock_format_type_stats_reg_nxt[5]   =  OTC_stock_increment_reg;
		8'h07   :  OTC_stock_format_type_stats_reg_nxt[6]   =  OTC_stock_increment_reg;
		8'h08   :  OTC_stock_format_type_stats_reg_nxt[7]   =  OTC_stock_increment_reg;
		8'h09   :  OTC_stock_format_type_stats_reg_nxt[8]   =  OTC_stock_increment_reg;
		8'h10   :  OTC_stock_format_type_stats_reg_nxt[9]   =  OTC_stock_increment_reg;
		8'h11   :  OTC_stock_format_type_stats_reg_nxt[10]  =  OTC_stock_increment_reg;
		8'h12   :  OTC_stock_format_type_stats_reg_nxt[11]  =  OTC_stock_increment_reg;
		8'h13   :  OTC_stock_format_type_stats_reg_nxt[12]  =  OTC_stock_increment_reg;
		8'h14   :  OTC_stock_format_type_stats_reg_nxt[13]  =  OTC_stock_increment_reg;
		8'h15   :  OTC_stock_format_type_stats_reg_nxt[14]  =  OTC_stock_increment_reg;
		8'h16   :  OTC_stock_format_type_stats_reg_nxt[15]  =  OTC_stock_increment_reg;
		8'h17   :  OTC_stock_format_type_stats_reg_nxt[16]  =  OTC_stock_increment_reg;
		8'h18   :  OTC_stock_format_type_stats_reg_nxt[17]  =  OTC_stock_increment_reg;
		8'h19   :  OTC_stock_format_type_stats_reg_nxt[18]  =  OTC_stock_increment_reg;
        endcase
	end
end

// determine next register value
always @(format_type_reg                          or listed_warrant_format_type_stats_reg[0]  or listed_warrant_format_type_stats_reg[1]  or listed_warrant_format_type_stats_reg[2]  or 
         listed_warrant_format_type_stats_reg[3]  or listed_warrant_format_type_stats_reg[4]  or listed_warrant_format_type_stats_reg[5]  or listed_warrant_format_type_stats_reg[6]  or 
		 listed_warrant_format_type_stats_reg[7]  or listed_warrant_format_type_stats_reg[8]  or listed_warrant_format_type_stats_reg[9]  or listed_warrant_format_type_stats_reg[10] or 
		 listed_warrant_format_type_stats_reg[11] or listed_warrant_format_type_stats_reg[12] or listed_warrant_format_type_stats_reg[13] or listed_warrant_format_type_stats_reg[14] or 
		 listed_warrant_format_type_stats_reg[15] or listed_warrant_format_type_stats_reg[16] or listed_warrant_format_type_stats_reg[17] or listed_warrant_format_type_stats_reg[18] or
         is_udp                                   or esccode_is_1b                            or with_terminal_code                       or listed_warrant_increment_reg             or
		 is_listed_warrant_dst_ip                 or is_listed_warrant_dst_port) 
begin
    for(i=0;i<19;i=i+1)
        listed_warrant_format_type_stats_reg_nxt[i] = listed_warrant_format_type_stats_reg[i];
		
    if(is_udp && esccode_is_1b && with_terminal_code && is_listed_warrant_dst_ip && is_listed_warrant_dst_port) begin
		case(format_type_reg)
		8'h01   :  listed_warrant_format_type_stats_reg_nxt[0]   =  listed_warrant_increment_reg;
		8'h02   :  listed_warrant_format_type_stats_reg_nxt[1]   =  listed_warrant_increment_reg;
		8'h03   :  listed_warrant_format_type_stats_reg_nxt[2]   =  listed_warrant_increment_reg;
		8'h04   :  listed_warrant_format_type_stats_reg_nxt[3]   =  listed_warrant_increment_reg;
		8'h05   :  listed_warrant_format_type_stats_reg_nxt[4]   =  listed_warrant_increment_reg;
		8'h06   :  listed_warrant_format_type_stats_reg_nxt[5]   =  listed_warrant_increment_reg;
		8'h07   :  listed_warrant_format_type_stats_reg_nxt[6]   =  listed_warrant_increment_reg;
		8'h08   :  listed_warrant_format_type_stats_reg_nxt[7]   =  listed_warrant_increment_reg;
		8'h09   :  listed_warrant_format_type_stats_reg_nxt[8]   =  listed_warrant_increment_reg;
		8'h10   :  listed_warrant_format_type_stats_reg_nxt[9]   =  listed_warrant_increment_reg;
		8'h11   :  listed_warrant_format_type_stats_reg_nxt[10]  =  listed_warrant_increment_reg;
		8'h12   :  listed_warrant_format_type_stats_reg_nxt[11]  =  listed_warrant_increment_reg;
		8'h13   :  listed_warrant_format_type_stats_reg_nxt[12]  =  listed_warrant_increment_reg;
		8'h14   :  listed_warrant_format_type_stats_reg_nxt[13]  =  listed_warrant_increment_reg;
		8'h15   :  listed_warrant_format_type_stats_reg_nxt[14]  =  listed_warrant_increment_reg;
		8'h16   :  listed_warrant_format_type_stats_reg_nxt[15]  =  listed_warrant_increment_reg;
		8'h17   :  listed_warrant_format_type_stats_reg_nxt[16]  =  listed_warrant_increment_reg;
		8'h18   :  listed_warrant_format_type_stats_reg_nxt[17]  =  listed_warrant_increment_reg;
		8'h19   :  listed_warrant_format_type_stats_reg_nxt[18]  =  listed_warrant_increment_reg;
        endcase
	end
end

// determine next register value
always @(format_type_reg                        or OTC_warrant_format_type_stats_reg[0]  or OTC_warrant_format_type_stats_reg[1]  or OTC_warrant_format_type_stats_reg[2]  or 
         OTC_warrant_format_type_stats_reg[3]   or OTC_warrant_format_type_stats_reg[4]  or OTC_warrant_format_type_stats_reg[5]  or OTC_warrant_format_type_stats_reg[6]  or 
		 OTC_warrant_format_type_stats_reg[7]   or OTC_warrant_format_type_stats_reg[8]  or OTC_warrant_format_type_stats_reg[9]  or OTC_warrant_format_type_stats_reg[10] or 
		 OTC_warrant_format_type_stats_reg[11]  or OTC_warrant_format_type_stats_reg[12] or OTC_warrant_format_type_stats_reg[13] or OTC_warrant_format_type_stats_reg[14] or 
		 OTC_warrant_format_type_stats_reg[15]  or OTC_warrant_format_type_stats_reg[16] or OTC_warrant_format_type_stats_reg[17] or OTC_warrant_format_type_stats_reg[18] or
         is_udp                                 or esccode_is_1b                         or with_terminal_code                    or OTC_warrant_increment_reg             or
		 is_OTC_warrant_dst_ip                  or is_OTC_warrant_dst_port) 
begin
    for(i=0;i<19;i=i+1)
        OTC_warrant_format_type_stats_reg_nxt[i] = OTC_warrant_format_type_stats_reg[i];
		
    if(is_udp && esccode_is_1b && with_terminal_code && is_OTC_warrant_dst_ip && is_OTC_warrant_dst_port) begin
		case(format_type_reg)
		8'h01   :  OTC_warrant_format_type_stats_reg_nxt[0]   =  OTC_warrant_increment_reg;
		8'h02   :  OTC_warrant_format_type_stats_reg_nxt[1]   =  OTC_warrant_increment_reg;
		8'h03   :  OTC_warrant_format_type_stats_reg_nxt[2]   =  OTC_warrant_increment_reg;
		8'h04   :  OTC_warrant_format_type_stats_reg_nxt[3]   =  OTC_warrant_increment_reg;
		8'h05   :  OTC_warrant_format_type_stats_reg_nxt[4]   =  OTC_warrant_increment_reg;
		8'h06   :  OTC_warrant_format_type_stats_reg_nxt[5]   =  OTC_warrant_increment_reg;
		8'h07   :  OTC_warrant_format_type_stats_reg_nxt[6]   =  OTC_warrant_increment_reg;
		8'h08   :  OTC_warrant_format_type_stats_reg_nxt[7]   =  OTC_warrant_increment_reg;
		8'h09   :  OTC_warrant_format_type_stats_reg_nxt[8]   =  OTC_warrant_increment_reg;
		8'h10   :  OTC_warrant_format_type_stats_reg_nxt[9]   =  OTC_warrant_increment_reg;
		8'h11   :  OTC_warrant_format_type_stats_reg_nxt[10]  =  OTC_warrant_increment_reg;
		8'h12   :  OTC_warrant_format_type_stats_reg_nxt[11]  =  OTC_warrant_increment_reg;
		8'h13   :  OTC_warrant_format_type_stats_reg_nxt[12]  =  OTC_warrant_increment_reg;
		8'h14   :  OTC_warrant_format_type_stats_reg_nxt[13]  =  OTC_warrant_increment_reg;
		8'h15   :  OTC_warrant_format_type_stats_reg_nxt[14]  =  OTC_warrant_increment_reg;
		8'h16   :  OTC_warrant_format_type_stats_reg_nxt[15]  =  OTC_warrant_increment_reg;
		8'h17   :  OTC_warrant_format_type_stats_reg_nxt[16]  =  OTC_warrant_increment_reg;
		8'h18   :  OTC_warrant_format_type_stats_reg_nxt[17]  =  OTC_warrant_increment_reg;
		8'h19   :  OTC_warrant_format_type_stats_reg_nxt[18]  =  OTC_warrant_increment_reg;
        endcase
	end
end

// assign registers value after determine & increment 
always @(posedge clk) begin
    if(reset) begin
        for(i=0;i<19;i=i+1)
            listed_stock_format_type_stats_reg[i] <= 16'd0;
    end
    else begin
        for(i=0;i<19;i=i+1) begin
            listed_stock_format_type_stats_reg[i] <= listed_stock_format_type_stats_reg_nxt[i];
        end
    end
end

//assign registers value after determine & increment 
always @(posedge clk) begin
    if(reset) begin
        for(i=0;i<19;i=i+1)
            OTC_stock_format_type_stats_reg[i] <= 16'd0;
    end
    else begin
        for(i=0;i<19;i=i+1) begin
            OTC_stock_format_type_stats_reg[i] <= OTC_stock_format_type_stats_reg_nxt[i];
        end
    end
end

// assign registers value after determine & increment 
always @(posedge clk) begin
    if(reset) begin
        for(i=0;i<19;i=i+1)
            listed_warrant_format_type_stats_reg[i] <= 16'd0;
    end
    else begin
        for(i=0;i<19;i=i+1) begin
            listed_warrant_format_type_stats_reg[i] <= listed_warrant_format_type_stats_reg_nxt[i];
        end
    end
end

// assign registers value after determine & increment 
always @(posedge clk) begin
    if(reset) begin
        for(i=0;i<19;i=i+1)
            OTC_warrant_format_type_stats_reg[i] <= 16'd0;
    end
    else begin
        for(i=0;i<19;i=i+1) begin
            OTC_warrant_format_type_stats_reg[i] <= OTC_warrant_format_type_stats_reg_nxt[i];
        end
    end
end


// store format-type into register 
always @(posedge clk) begin
    if(reset) begin
	    format_type_reg <= 8'h0;
	end
	
	else begin
	    if( word_IP_DST_LO )
	        format_type_reg <= tdata[175:168];
	end
end
*/
// check flags in proper timing - ip & port & udp & ECS-CODE 
always @(posedge clk) begin
    if(reset) begin
	    is_udp                      <=  1'b0;
	    esccode_is_1b               <=  1'b0;
        is_format_six               <=  1'b0;
/*		is_listed_stock_dst_ip      <=  1'b0;
		is_OTC_stock_dst_ip         <=  1'b0;
		is_listed_warrant_dst_ip    <=  1'b0;
		is_OTC_warrant_dst_ip       <=  1'b0;
		is_listed_stock_dst_port    <=  1'b0;
		is_OTC_stock_dst_port       <=  1'b0;
		is_listed_warrant_dst_port  <=  1'b0;
		is_OTC_warrant_dst_port     <=  1'b0;
*/
		    wr_en <= 'b0;
	end
	
	else begin
    //New

    
	    if(word_IP_DST_HI) begin
		    wr_en <= (tlast)? 'b1: 'b0;
	            is_udp                     <= (tdata[71:64]    ==  8'h11) ? 1'b1 : 1'b0;
	    end
	    else if(word_IP_DST_LO) begin
/*		    is_listed_stock_dst_ip     <= ({tdata_reg[15:0], tdata[255:240]}  ==  listed_stock_dst_ip)     ? 1'b1 : 1'b0;
		    is_OTC_stock_dst_ip        <= ({tdata_reg[15:0], tdata[255:240]}  ==  OTC_stock_dst_ip)        ? 1'b1 : 1'b0;
		    is_listed_warrant_dst_ip   <= ({tdata_reg[15:0], tdata[255:240]}  ==  listed_warrant_dst_ip)   ? 1'b1 : 1'b0;
		    is_OTC_warrant_dst_ip      <= ({tdata_reg[15:0], tdata[255:240]}  ==  OTC_warrant_dst_ip)      ? 1'b1 : 1'b0;
		    is_listed_stock_dst_port   <= (tdata[223:208]  ==  listed_stock_dst_port)   ? 1'b1 : 1'b0;
		    is_OTC_stock_dst_port      <= (tdata[223:208]  ==  OTC_stock_dst_port)      ? 1'b1 : 1'b0;
		    is_listed_warrant_dst_port <= (tdata[223:208]  ==  listed_warrant_dst_port) ? 1'b1 : 1'b0;
		    is_OTC_warrant_dst_port    <= (tdata[223:208]  ==  OTC_warrant_dst_port)    ? 1'b1 : 1'b0;
*/            // could be eop for minimum frame size
                    esccode_is_1b              <= (tdata[175:168] ==  8'h1b) ? 1'b1 : 1'b0;
                    is_format_six              <= (tdata[143:136]  ==  8'h06) ? 1'b1 : 1'b0;
//	            is_udp                     <= (tdata_reg[71:64]    ==  8'h11) ? 1'b1 : 1'b0;
		    wr_en <= (tlast)? 'b1: 'b0;
	    end
	    else if(word_OPT_PAYLOAD)begin
		    wr_en <= 'b1;
	    end
	    else begin
		    wr_en <= 'b0;
	    end
/*
	    else if(is_eop_delay) begin
	            is_udp                     <=  1'b0;
	            esccode_is_1b              <=  1'b0;
                    is_format_six              <=  1'b0;
		    is_listed_stock_dst_ip     <=  1'b0;
		    is_OTC_stock_dst_ip        <=  1'b0;
		    is_listed_warrant_dst_ip   <=  1'b0;
		    is_OTC_warrant_dst_ip      <=  1'b0;
		    is_listed_stock_dst_port   <=  1'b0;
		    is_OTC_stock_dst_port      <=  1'b0;
		    is_listed_warrant_dst_port <=  1'b0;
		    is_OTC_warrant_dst_port    <=  1'b0;
            end
*/    
	end
end

// check flags in proper timing - in_ctrl is 0 or not 
always @(posedge clk) begin
    if(reset) begin
       ctrl_prev_is_0  <=  1'b0;
    end

    else begin
        if(valid)
            ctrl_prev_is_0  <=  (tkeep == 32'd0);
    end
end

// check flags in proper timing - eop delay 
always @(posedge clk) begin
    if(reset) begin
       is_eop_delay          <=  1'b0;
       counter1              <=  16'd0;
       counter2              <=  16'd0;
       counter3              <=  16'd0;
       counter4              <=  16'd0;
    end

    else begin
  /*    if(tkeep != IO_QUEUE_STAGE_NUM && tkeep !=0 && vaild) begin
            is_eop_delay   <=  1'b1;
        end
        else begin
            is_eop_delay   <=  1'b0;
        end*/
        is_eop_delay       <=  tlast & valid;
        if(is_listed_stock_dst_ip)
            counter1 <= counter1 + 1'd1;
        if(ip_feed_check)
            counter2 <= counter2 + 1'd1;
        if(is_listed_stock_dst_port)
            counter3 <= counter3 + 1'd1;
        if(!empty)
            counter4 <= counter4 + 1'd1;
    end
end

// store t_data every time 
always @(posedge clk) begin
    if(reset) begin
	       tdata_reg        <= 256'h0;
	end
	
	else begin
           tdata_reg        <= tdata;
	end
end


//new 
// check flags in proper timing - TERMINAL-CODE 
always @(posedge clk) begin
    if(reset) begin
	    with_terminal_code    <=  1'b0;
    end
    else begin
	if (tkeep[31] && {tdata_reg[7:0], tdata[255:248]} ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[30] && tdata[255:240]  ==  16'h0d0a) 
                    with_terminal_code  <= 1'b1;
        else if(tkeep[29] && tdata[247:232]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[28] && tdata[239:224]  ==  16'h0d0a) 
                    with_terminal_code  <= 1'b1;
        else if(tkeep[27] && tdata[231:216]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[26] && tdata[223:208]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[25] && tdata[215:200]   ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[24] && tdata[207:192]   ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[23] && tdata[199:184]  ==  16'h0d0a) 
                    with_terminal_code  <= 1'b1;
        else if(tkeep[22] && tdata[191:176]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[21] && tdata[183:168]  ==  16'h0d0a) 
                    with_terminal_code  <= 1'b1;
        else if(tkeep[20] && tdata[175:160]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[19] && tdata[167:152]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[18] && tdata[159:144]   ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[17] && tdata[151:136]   ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[16] && tdata[143:128]  ==  16'h0d0a) 
                    with_terminal_code  <= 1'b1;
        else if(tkeep[15] && tdata[135:120]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[14] && tdata[127:112]  ==  16'h0d0a) 
                    with_terminal_code  <= 1'b1;
        else if(tkeep[13] && tdata[119:104]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[12] && tdata[111:96]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[11] && tdata[103:88]   ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[10] && tdata[95:80]   ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;                
        else if(tkeep[9] && tdata[87:72]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[8] && tdata[79:64]   ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[7] && tdata[71:56]   ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[6] && tdata[63:48]  ==  16'h0d0a) 
                    with_terminal_code  <= 1'b1;
        else if(tkeep[5] && tdata[55:40]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[4] && tdata[47:32]  ==  16'h0d0a) 
                    with_terminal_code  <= 1'b1;
        else if(tkeep[3] && tdata[39:24]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[2] && tdata[31:16]  ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[1] && tdata[23:8]   ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else if(tkeep[0] && tdata[15:0]   ==  16'h0d0a)
                    with_terminal_code  <= 1'b1;
        else
                    with_terminal_code  <= 1'b0;
    end
end



// read format_type register array 
/*
always @(posedge clk) begin
    if(reset) begin
	    listed_stock_format_type_stats_rd_value  <=  16'd0;
	    listed_stock_format_type_stats_rd_ack    <=  1'b0;
	end
	
	else begin
	    if(listed_stock_format_type_stats_rd_req) begin
	        listed_stock_format_type_stats_rd_value  <=  listed_stock_format_type_stats_reg[listed_stock_format_type_stats_rd_addr];
*/
	     //   listed_stock_format_type_stats_rd_value  <=   counter1;
	     /*   if(listed_stock_format_type_stats_rd_addr == 0)
	            listed_stock_format_type_stats_rd_value  <=  counter1;
	        else if(listed_stock_format_type_stats_rd_addr == 1)
	            listed_stock_format_type_stats_rd_value  <=  counter2;
	        else if(listed_stock_format_type_stats_rd_addr == 2)
	            listed_stock_format_type_stats_rd_value  <=  counter3;
            else
	            listed_stock_format_type_stats_rd_value  <=  counter4;*/
/*
		listed_stock_format_type_stats_rd_ack    <=  1'b1;
	    end
		
        else begin
		    listed_stock_format_type_stats_rd_ack    <=  1'b0;
	    end
	end
end
*/

// read format_type register array
/* 
always @(posedge clk) begin
    if(reset) begin
	    OTC_stock_format_type_stats_rd_value  <=  16'd0;
	    OTC_stock_format_type_stats_rd_ack    <=  1'b0;
	end
	
	else begin
	    if(OTC_stock_format_type_stats_rd_req) begin
	        OTC_stock_format_type_stats_rd_value  <=  OTC_stock_format_type_stats_reg[OTC_stock_format_type_stats_rd_addr];
		    OTC_stock_format_type_stats_rd_ack    <=  1'b1;
	    end
		
        else begin
		    OTC_stock_format_type_stats_rd_ack    <=  1'b0;
	    end
	end
end

*/
// read format_type register array 
/*
always @(posedge clk) begin
    if(reset) begin
	    listed_warrant_format_type_stats_rd_value  <=  16'd0;
	    listed_warrant_format_type_stats_rd_ack    <=  1'b0;
	end
	
	else begin
	    if(listed_warrant_format_type_stats_rd_req) begin
	        listed_warrant_format_type_stats_rd_value  <=  listed_warrant_format_type_stats_reg[listed_warrant_format_type_stats_rd_addr];
		    listed_warrant_format_type_stats_rd_ack    <=  1'b1;
	    end
		
        else begin
		    listed_warrant_format_type_stats_rd_ack    <=  1'b0;
	    end
	end
end
*/
// read format_type register array 
/*
always @(posedge clk) begin
    if(reset) begin
	    OTC_warrant_format_type_stats_rd_value  <=  16'd0;
	    OTC_warrant_format_type_stats_rd_ack    <=  1'b0;
	end
	
	else begin
	    if(OTC_warrant_format_type_stats_rd_req) begin
	        OTC_warrant_format_type_stats_rd_value  <=  OTC_warrant_format_type_stats_reg[listed_warrant_format_type_stats_rd_addr];
	  	    OTC_warrant_format_type_stats_rd_ack    <=  1'b1;
	    end
		
        else begin
		    OTC_warrant_format_type_stats_rd_ack    <=  1'b0;
	    end
	end
end
*/

endmodule

   
