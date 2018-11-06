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


module pkt_arbiter
  #(parameter C_S_AXIS_DATA_WIDTH	= 256,
    parameter C_S_AXIS_TUSER_WIDTH	= 128,
    parameter NUM_QUEUES		= 8,
    parameter NUM_QUEUES_WIDTH		= log2(NUM_QUEUES)
  )
  (// --- interface to input fifo - fallthrough
   input                              fix_order_in_tvalid,
   input [C_S_AXIS_DATA_WIDTH-1:0]    fix_order_in_tdata,
   input			      fix_order_in_tlast,
   input [C_S_AXIS_TUSER_WIDTH-1:0]   fix_order_in_tuser,
   input [C_S_AXIS_DATA_WIDTH/8-1:0]  fix_order_in_tkeep,
   output			      fix_order_in_rd_en,

   input                              in_fifo_vld,
   input [C_S_AXIS_DATA_WIDTH-1:0]    in_fifo_tdata,
   input                              in_fifo_tlast,
   input [C_S_AXIS_TUSER_WIDTH-1:0]   in_fifo_tuser,
   input [C_S_AXIS_DATA_WIDTH/8-1:0]  in_fifo_tkeep,
   output			      in_fifo_rd_en,

   // --- interface to next module
/*
   output reg                         		out_tvalid,
   output reg [C_S_AXIS_DATA_WIDTH-1:0]		out_tdata,
   output reg [C_S_AXIS_TUSER_WIDTH-1:0]	out_tuser,     // new checksum assuming decremented TTL
   input                              		out_tready,
   output reg [C_S_AXIS_DATA_WIDTH/8-1:0]  	out_keep,
   output reg					out_tlast,
*/
   output reg                                   fix_seq_num_in_tvalid,
   output reg [C_S_AXIS_DATA_WIDTH-1:0]         fix_seq_num_in_tdata,
   output reg [C_S_AXIS_TUSER_WIDTH-1:0]        fix_seq_num_in_tuser,     // new checksum assuming decremented TTL
   input                                        fix_seq_num_in_tready,
   output reg [C_S_AXIS_DATA_WIDTH/8-1:0]       fix_seq_num_in_tkeep,
   output reg                                   fix_seq_num_in_tlast,


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


   wire [255:0]                 fix_order_cancel_out_fifo_tdata;
   wire [31:0]                  fix_order_cancel_out_fifo_tkeep;
   wire [127:0]                 fix_order_cancel_out_fifo_tuser;
   wire                         fix_order_cancel_out_fifo_tlast;
   wire                         fix_order_cancel_out_fifo_nearly_full;
   wire                         fix_order_cancel_out_fifo_empty;
   reg				fix_order_cancel_rd_en;

   wire [255:0]                 connect_pkt_out_fifo_tdata;
   wire [31:0]                  connect_pkt_out_fifo_tkeep;
   wire [127:0]                 connect_pkt_out_fifo_tuser;
   wire                         connect_pkt_out_fifo_tlast;
   wire                         connect_pkt_out_fifo_nearly_full;
   wire                         connect_pkt_out_fifo_empty;
   reg				connect_pkt_rd_en;



   reg [255:0] fix_seq_num_in_tdata_next;
   reg [127:0] fix_seq_num_in_tuser_next;
   reg [31:0]  fix_seq_num_in_tkeep_next;
   reg         fix_seq_num_in_tvalid_next;
   reg         fix_seq_num_in_tlast_next;

   reg [NUM_STATES-1:0]         state;
   reg [NUM_STATES-1:0]         state_next;

  //--------------------------------------------//
   localparam NUM_STATES          = 16;
   localparam WAIT_PREPROCESS_RDY = 1;
   localparam PASS_ORDER_CANCEL   = 2;
   localparam PASS_TCP_FIX_CONNECT= 4;



 

   fallthrough_small_fifo #(.WIDTH(1+C_S_AXIS_TUSER_WIDTH+C_S_AXIS_DATA_WIDTH/8+C_S_AXIS_DATA_WIDTH), .MAX_DEPTH_BITS(9))
      fix_formatter_output_buff_fifo
        (.din           ({fix_order_in_tlast,fix_order_in_tuser,fix_order_in_tkeep,fix_order_in_tdata}),  // Data in
         .wr_en         (fix_order_in_tvalid ),             // Write enable
         .rd_en         (fix_order_cancel_rd_en),    // Read the next word
         .dout          ({fix_order_cancel_out_fifo_tlast,fix_order_cancel_out_fifo_tuser,fix_order_cancel_out_fifo_tkeep,fix_order_cancel_out_fifo_tdata}),
         .full          (),
         .nearly_full   (fix_order_cancel_out_fifo_nearly_full),
         .prog_full     (),
         .empty         (fix_order_cancel_out_fifo_empty),
         .reset         (reset),
         .clk           (clk)
        );

fallthrough_small_fifo #(.WIDTH(1+C_S_AXIS_TUSER_WIDTH+(C_S_AXIS_DATA_WIDTH/8)+C_S_AXIS_DATA_WIDTH), .MAX_DEPTH_BITS(6))
      connect_pkt_output_buff_fifo
        (.din           ({in_fifo_tlast,in_fifo_tuser, in_fifo_tkeep, in_fifo_tdata}),  // Data in
         .wr_en         (in_fifo_vld),             // Write enable
         .rd_en         (connect_pkt_rd_en),    // Read the next word
         .dout          ({connect_pkt_out_fifo_tlast,connect_pkt_out_fifo_tuser,connect_pkt_out_fifo_tkeep,connect_pkt_out_fifo_tdata}),
         .full          (),
         .nearly_full   (connect_pkt_out_fifo_nearly_full),
         .prog_full     (),
         .empty         (connect_pkt_out_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

assign fix_order_in_rd_en = !fix_order_cancel_out_fifo_nearly_full;
assign in_fifo_rd_en	  = !connect_pkt_out_fifo_nearly_full;

  always @(*) begin
        fix_seq_num_in_tvalid_next      = 0;
        fix_seq_num_in_tlast_next       = 0;
        fix_seq_num_in_tdata_next       = 0;
        fix_seq_num_in_tuser_next       = 0;
        fix_seq_num_in_tkeep_next        = 0;
        state_next = state;
        fix_order_cancel_rd_en = 0;
        connect_pkt_rd_en      = 0;
        case(state)
        WAIT_PREPROCESS_RDY:begin
                fix_seq_num_in_tvalid_next = 0;
                fix_order_cancel_rd_en = 0;
                connect_pkt_rd_en      = 0;
/*
		if(!connect_pkt_out_fifo_empty&&fix_seq_num_in_tready)begin
                        state_next = PASS_TCP_FIX_CONNECT;
                end
                else if(!fix_order_cancel_out_fifo_empty&&fix_seq_num_in_tready)begin
                        state_next = PASS_ORDER_CANCEL;
                end
                else begin
                        state_next = WAIT_PREPROCESS_RDY;
                end
*/

                if(!fix_order_cancel_out_fifo_empty&&fix_seq_num_in_tready)begin
                        state_next = PASS_ORDER_CANCEL;
                end
                else if(!connect_pkt_out_fifo_empty&&fix_seq_num_in_tready)begin
                        state_next = PASS_TCP_FIX_CONNECT;
                end
                else begin
                        state_next = WAIT_PREPROCESS_RDY;
                end
 
        end



        PASS_ORDER_CANCEL :begin
                  if(!fix_order_cancel_out_fifo_empty&&fix_seq_num_in_tready)begin
                        fix_order_cancel_rd_en = 1;
                        fix_seq_num_in_tvalid_next = 1;
                        fix_seq_num_in_tdata_next  = fix_order_cancel_out_fifo_tdata;
                        fix_seq_num_in_tkeep_next   = fix_order_cancel_out_fifo_tkeep;
                        fix_seq_num_in_tuser_next  = fix_order_cancel_out_fifo_tuser;
                        fix_seq_num_in_tlast_next  = fix_order_cancel_out_fifo_tlast;
                        if(fix_order_cancel_out_fifo_tlast)begin
                                state_next = WAIT_PREPROCESS_RDY;
                        end
                end
        end
        PASS_TCP_FIX_CONNECT :begin
                if(!connect_pkt_out_fifo_empty&&fix_seq_num_in_tready)begin
                        connect_pkt_rd_en = 1;
                        fix_seq_num_in_tvalid_next = 1;
                        fix_seq_num_in_tdata_next  = connect_pkt_out_fifo_tdata;
                        fix_seq_num_in_tkeep_next   = connect_pkt_out_fifo_tkeep;
                        fix_seq_num_in_tuser_next  = connect_pkt_out_fifo_tuser;
                        fix_seq_num_in_tlast_next  = connect_pkt_out_fifo_tlast;
                        if(connect_pkt_out_fifo_tlast)begin
                                state_next = WAIT_PREPROCESS_RDY;
                        end
                end
        end



        endcase
  end


   always @(posedge clk) begin
      if(reset) begin
         state             <= WAIT_PREPROCESS_RDY;
         fix_seq_num_in_tvalid     <= 0;
         fix_seq_num_in_tdata      <= 0;
         fix_seq_num_in_tuser      <= 0;
         fix_seq_num_in_tkeep      <= 0;
         fix_seq_num_in_tlast      <= 0;

      end

      else begin
         state             <= state_next;
	 fix_seq_num_in_tvalid	      <= fix_seq_num_in_tvalid_next;
         fix_seq_num_in_tlast         <= fix_seq_num_in_tlast_next;
         fix_seq_num_in_tdata         <= fix_seq_num_in_tdata_next;
         fix_seq_num_in_tuser         <= fix_seq_num_in_tuser_next;
         fix_seq_num_in_tkeep         <= fix_seq_num_in_tkeep_next;
      end // else: !if(reset)
   end // always @ (posedge clk)


endmodule // op_lut_process_sm

