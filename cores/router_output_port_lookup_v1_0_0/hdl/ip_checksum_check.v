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


module ip_checksum_check
  #(parameter C_S_AXIS_DATA_WIDTH=256)
  (
   //--- datapath interface
   input  [C_S_AXIS_DATA_WIDTH-1:0]   tdata,
   input                              valid,

   //--- interface to preprocess
   input                              word_IP_DST_HI,
   input                              word_IP_DST_LO,

   // --- interface to process
   output                             ip_checksum_vld,
   output     [15:0]                  ip_new_checksum,     // new checksum assuming decremented TTL
   input                              rd_ip_checksum,

   // misc
   input reset,
   input clk
   );

   //---------------------- Wires and regs---------------------------
   reg	[19:0]	checksum, checksum_next;
   reg	[16:0]	adjusted_checksum;
   reg  [15:0]  ip_old_checksum ;
   reg		checksum_done;
   reg		info_ready;
   wire		empty;
   reg	[7:0]	ttl_new;
   reg		ttl_good;
   reg		hdr_has_options;
   reg		add_carry;
   reg	add_carry_d1;

   reg	[19:0]	cksm_sum_0, cksm_sum_1, cksm_sum_0_next, cksm_sum_1_next, cksm_sum_2, cksm_sum_2_next, cksm_sum_3, cksm_sum_3_next;
   wire	[19:0]	cksm_temp,cksm_temp2;

   //------------------------- Modules-------------------------------
/*
   fallthrough_small_fifo #(.WIDTH(26), .MAX_DEPTH_BITS(2))
      info_fifo
        (.din ({adjusted_checksum[15:0], ttl_good, ttl_new, hdr_has_options}),	// {IP good, new checksum}
         .wr_en (info_ready),							// Write enable
         .rd_en (rd_checksum),							// Read the next word
         .dout ({ip_new_checksum, ip_ttl_is_good, ip_new_ttl, ip_hdr_has_options}),
         .full (),
         .nearly_full (),
         .prog_full (),
         .empty (),
         .reset (reset),
         .clk (clk)
         );
*/
   fallthrough_small_fifo #(.WIDTH(16), .MAX_DEPTH_BITS(2))
      cksm_fifo
        (.din (~checksum[15:0]),
         .wr_en (checksum_done),	// Write enable
         .rd_en (rd_ip_checksum),		// Read the next word
         .dout (ip_new_checksum),
         .full (),
         .nearly_full (),
         .prog_full (),
         .empty (empty),
         .reset (reset),
         .clk (clk)
         );

   //------------------------- Logic -------------------------------
   assign ip_checksum_vld = !empty;

   assign cksm_temp = cksm_sum_0 + cksm_sum_1;
   assign cksm_temp2 = cksm_sum_2 + cksm_sum_3;

   always @(*) begin
      checksum_next = checksum;
      cksm_sum_0_next = cksm_sum_0;
      cksm_sum_1_next = cksm_sum_1;
      cksm_sum_2_next = cksm_sum_2;
      cksm_sum_3_next = cksm_sum_3;
      if(word_IP_DST_HI) begin
	 cksm_sum_0_next = tdata[143:128]+tdata[127:112];
	 cksm_sum_1_next = tdata[111:96]+tdata[95:80];
	 cksm_sum_2_next = tdata[79:64]+tdata[47:32];
	 //cksm_sum_2_next = tdata[63:48]+tdata[47:32];
	 cksm_sum_3_next = tdata[31:16]+tdata[15:0];
      end
      if(word_IP_DST_LO) begin
	 checksum_next = cksm_temp + cksm_temp2 + tdata[255:240];
      end
      if(add_carry) begin
	 checksum_next = checksum[19:16] + checksum[15:0] ;//-ip_old_checksum;// - ip_old_checksum;
      end
/*
      if(add_carry_d1)begin
         checksum_next = checksum - ip_old_checksum ; 
      end
*/
   end // always @ (*)

   // checksum logic. 16bit 1's complement over the IP header.
   // --- see RFC1936 for guidance.
   // If checksum is good then it should be 0xffff
   always @(posedge clk) begin
      if(reset) begin
         adjusted_checksum	<= 17'h0; // calculates the new chksum
         checksum_done		<= 0;
         ttl_new		<= 0;
         ttl_good		<= 0;
         hdr_has_options	<= 0;
         info_ready		<= 0;
	 checksum		<= 20'h0;
         add_carry		<= 0;
	 add_carry_d1		<= 0;
	 ip_old_checksum        <= 16'h0;
         cksm_sum_0		<= 0;
         cksm_sum_1		<= 0;
         cksm_sum_2		<= 0;
         cksm_sum_3		<= 0;
      end
      else begin
	 checksum <= checksum_next;
         cksm_sum_0 <= cksm_sum_0_next;
         cksm_sum_1 <= cksm_sum_1_next;
         cksm_sum_2 <= cksm_sum_2_next;
         cksm_sum_3 <= cksm_sum_3_next;

         /* make sure the version is correct and there are no options */
         if(word_IP_DST_HI) begin
	    hdr_has_options	<= (tdata[143:136]!=8'h45);
	    ttl_new		<= (tdata[79:72]==8'h0) ? 8'h0 : tdata[79:72] - 1'b1;
	    ttl_good		<= (tdata[79:72] > 8'h1);
	    adjusted_checksum	<= {1'h0, tdata[63:48]} + 17'h0100; // adjust for the decrement in TTL (BIG Endian)
	    ip_old_checksum     <= tdata[63:48];
         end

         if(word_IP_DST_LO) begin
            adjusted_checksum	<= {1'h0, adjusted_checksum[15:0]} + adjusted_checksum[16];
            info_ready		<= 1;
            add_carry		<= 1;
         end
         else begin
            info_ready	<= 0;
            add_carry	<= 0;
         end

         if(add_carry) begin
	    add_carry_d1 <= 1;	
         end
	 else begin
            add_carry_d1 <= 0;
         end

	 if(add_carry_d1) begin
	    checksum_done <= 1;		
	 end

         else begin
            checksum_done <= 0;
         end

         // synthesis translate_off
         // If we have any carry left in top 4 bits then algorithm is wrong
         if (checksum_done && checksum[19:16] != 4'h0) begin
            $display("%t %m ERROR: top 4 bits of checksum_word_0 not zero - algo wrong???",
                     $time);
            #100 $stop;
         end
         // synthesis translate_on

      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // IP_checksum
