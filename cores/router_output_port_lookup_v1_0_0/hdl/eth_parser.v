/*******************************************************************************
*
* Copyright (C) 2010, 2011 The Board of Trustees of The Leland Stanford
*                          Junior University
* Copyright (C) 2010, 2011 Muhammad Shahbaz
* Copyright (C) 2015 Gianni Antichi
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


  module eth_parser
    #(parameter C_S_AXIS_DATA_WIDTH	= 256,
      parameter NUM_QUEUES		= 8,
      parameter NUM_QUEUES_WIDTH	= log2(NUM_QUEUES)
      )
   (// --- Interface to the previous stage
    input  [C_S_AXIS_DATA_WIDTH-1:0]   tdata,
   
    // --- Interface to process block
    //output                             is_arp_pkt,
    output                             is_udp_pkt,
    output                             is_ip_pkt,
    output                             is_for_us,
    output                             is_broadcast,
    output [NUM_QUEUES_WIDTH-1:0]      mac_dst_port_num,
    input                              eth_parser_rd_info,
    output                             eth_parser_info_vld,

    // --- Interface to preprocess block
    input                              word_IP_DST_HI,

    // --- Interface to registers
    input  [47:0]                      mac_0,    // address of rx queue 0
    input  [47:0]                      mac_1,    // address of rx queue 1
    input  [47:0]                      mac_2,    // address of rx queue 2
    input  [47:0]                      mac_3,    // address of rx queue 3

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
   localparam				ETH_ARP	= 16'h0806;	// byte order = Big Endian
   localparam				ETH_IP 	= 16'h0800;	// byte order = Big Endian

   localparam 				UDP     = 8'h11;
   localparam                           IDLE		= 1;
   localparam                           DO_SEARCH	= 2;
   localparam				FLUSH_ENTRY	= 4;

   //---------------------- Wires/Regs -------------------------------
   reg [47:0]                          dst_MAC;
   reg [47:0]                          mac_sel;
   reg [15:0]                          ethertype;

   reg                                 search_req;

   reg [2:0]                           state, state_next;
   reg [log2(NUM_QUEUES/2):0]          mac_count, mac_count_next;
   reg                                 wr_en;
   reg                                 port_found;

   wire                                broadcast_bit;

   wire [47:0]			       dst_MAC_fifo;
   wire [15:0]			       ethertype_fifo;
   reg				       rd_parser;
   wire				       parser_fifo_empty;

   reg  [7:0]			       protocol;
   //----------------------- Modules ---------------------------------
   fallthrough_small_fifo #(.WIDTH(4+NUM_QUEUES_WIDTH), .MAX_DEPTH_BITS(2))
      eth_fifo
        (.din ({port_found,               			// is for us
                //(ethertype==ETH_ARP),				// is ARP
                (ethertype==ETH_IP),				// is IP
		(protocol==UDP),				// is UDP
                (broadcast_bit),				// is broadcast
                {mac_count[log2(NUM_QUEUES/2)-1:0], 1'b0}}),	// dst port num
         .wr_en (wr_en),					// Write enable
         .rd_en (eth_parser_rd_info),				// Read the next word
         .dout ({is_for_us, is_ip_pkt, is_udp_pkt, is_broadcast, mac_dst_port_num}),
         .full (),
         .nearly_full (),
         .prog_full (),
         .empty (empty),
         .reset (reset),
         .clk (clk)
         );


  fallthrough_small_fifo #(.WIDTH(48+16), .MAX_DEPTH_BITS  (2))
      parser
        (.din           ({dst_MAC,ethertype}), // Data in
         .wr_en         (search_req),          // Write enable
         .rd_en         (rd_parser),           // Read the next word
         .dout          ({dst_MAC_fifo, ethertype_fifo}),
         .full          (),
         .nearly_full   (parser_fifo_nearly_full),
         .prog_full     (),
         .empty         (parser_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );


   //------------------------ Logic ----------------------------------
   assign eth_parser_info_vld = !empty;
   assign broadcast_bit = dst_MAC_fifo[40]; 	// Big endian

   always @(*) begin
      mac_sel = mac_0;
      case(mac_count)
         0: mac_sel = mac_0;
         1: mac_sel = mac_1;
         2: mac_sel = mac_2;
         3: mac_sel = mac_3;
         4: mac_sel = ~48'h0;
      endcase // case(mac_count)
   end // always @ (*)

   /******************************************************************
    * Get the destination, source and ethertype of the pkt
    *****************************************************************/
   always @(posedge clk) begin
      if(reset) begin
         dst_MAC    <= 0;
         ethertype  <= 0;
         search_req <= 0;
	 protocol   <= 'h0;
      end
      else begin
	 if(word_IP_DST_HI) begin
	    dst_MAC	<= tdata[255:208]; 	// Big endian
	    ethertype	<= tdata[159:144]; 	// Big endian
	    search_req	<= 1;
	    protocol    <= tdata[71:64];
	 end
         else begin
            search_req     <= 0;
         end
      end // else: !if(reset)
   end // always @ (posedge clk)

   /*************************************************************
    * check to see if the destination port matches any of our port
    * MAC addresses. We need to make sure that this search is
    * completed before the end of the packet.
    *************************************************************/
   always @(*) begin

      state_next = state;
      mac_count_next = mac_count;
      wr_en = 0;
      port_found = 0;
      rd_parser = 0;

      case(state)

        IDLE: begin
           if(!parser_fifo_empty) begin
              state_next	= DO_SEARCH;
              mac_count_next	= NUM_QUEUES/2;
           end
        end

        DO_SEARCH: begin
           mac_count_next = mac_count-1;
           if(mac_sel==dst_MAC_fifo || broadcast_bit) begin
              wr_en		= 1;
              state_next	= FLUSH_ENTRY;
              port_found	= 1;
           end
           else if(mac_count == 0) begin
              state_next	= FLUSH_ENTRY;
              wr_en 		= 1;
           end
        end

	FLUSH_ENTRY: begin
		rd_parser	= 1;
		state_next	= IDLE;
	end

      endcase // case(state)

   end // always @(*)


   always @(posedge clk) begin
      if(reset) begin
         state		<= IDLE;
         mac_count	<= 0;
      end
      else begin
         state		<= state_next;
         mac_count	<= mac_count_next;
      end
   end

endmodule // eth_parser


