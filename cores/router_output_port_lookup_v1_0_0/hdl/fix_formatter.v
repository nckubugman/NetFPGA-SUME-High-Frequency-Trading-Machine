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


module fix_formatter
  #(parameter C_S_AXIS_DATA_WIDTH	= 256,
    parameter C_S_AXIS_TUSER_WIDTH	= 128,
    parameter NUM_QUEUES		= 8,
    parameter NUM_QUEUES_WIDTH		= log2(NUM_QUEUES)
  )
  (// --- interface to input fifo - fallthrough
/*   input                              in_fifo_vld,
   input [C_S_AXIS_DATA_WIDTH-1:0]    in_fifo_tdata,
   input			      in_fifo_tlast,
   input [C_S_AXIS_TUSER_WIDTH-1:0]   in_fifo_tuser,
   input [C_S_AXIS_DATA_WIDTH/8-1:0]  in_fifo_keep,
   output reg                         in_fifo_rd_en,
*/
   // --- interface to next module
   output reg                         		out_tvalid,
   output reg [C_S_AXIS_DATA_WIDTH-1:0]		out_tdata,
   output reg [C_S_AXIS_TUSER_WIDTH-1:0]	out_tuser,     // new checksum assuming decremented TTL
   input                              		out_tready,
   output reg [C_S_AXIS_DATA_WIDTH/8-1:0]  	out_keep,
   output reg					out_tlast,

   input [15:0]                  pkt_year,
   input [15:0]                  pkt_mon,
   input [15:0]                  pkt_day,
   input [15:0]                  pkt_hour,
   input [15:0]                  pkt_min,
   input [15:0]                  pkt_sec,
   input [15:0]                  pkt_ms,
  

   input				parse_order_vld,
   output reg				rd_preprocess_info,
//   input  [216:0]			order_index_out,
   input [240:0]		order_index_out,

   // misc
   input[31:0]			 ack_value,
   input[31:0]			 seq_value,
   input[31:0]			 ts_val,
   input[31:0]			 ecr_val,

   output reg			 send_one,
   output reg			 is_send_pkt,
   input			 rd_preprocess_done,


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
   localparam MOVE_TUSER    	  = 2;
   localparam CHANGE_PKT     	  = 4;
   localparam SEND_PKT         	  = 8;
   localparam DROP_PKT            = 16;
   localparam HEADER_0		  = 32;
   localparam HEADER_1		  = 64;
   localparam PAYLOAD_0  	  = 128;
   localparam PAYLOAD_1		  = 256;
   localparam PAYLOAD_2		  = 512;
   localparam PAYLOAD_3		  = 1024;
   localparam PAYLOAD_4		  = 2048;
   localparam PAYLOAD_5		  = 4096;
   localparam PAYLOAD_6		  = 8192;
   localparam DELAY		  = 16384;
   localparam WAIT_RD_PREPROCESS_DONE = 16385;
   localparam C_AXIS_SRC_PORT_POS = 16;
   localparam C_AXIS_DST_PORT_POS = 24;
   //---------------------- Wires and regs -------------------------
   wire                 preprocess_vld;

   reg [NUM_STATES-1:0]		state;
   reg [NUM_STATES-1:0]		state_next;
   reg				out_tvalid_next;
   reg				out_tlast_next;
   reg [C_S_AXIS_DATA_WIDTH-1:0]	out_tdata_next;
   reg [C_S_AXIS_TUSER_WIDTH-1:0]	out_tuser_next;
   reg [C_S_AXIS_DATA_WIDTH/8-1:0]	out_keep_next;

   reg [47:0]           src_mac_sel;

   reg [NUM_QUEUES-1:0] dst_port;
   reg [NUM_QUEUES-1:0] dst_port_next;

   reg                  to_from_cpu;
   reg                  to_from_cpu_next;

   reg [3:0] 			counter;
   reg [3:0] 			counter_reg;
   reg 				send_one_next;
   wire	[NUM_QUEUES-1:0] output_port;		
   
   reg				generate_lock;
   reg				generate_lock_next;
//   reg			send_one ;
   reg				send_cross ;
   reg				send_first;

   reg				is_send_pkt_next;
   always @(*) begin
/*      out_tlast_next                = in_fifo_tlast;
      out_tdata_next		    = in_fifo_tdata;
      out_tuser_next		    = in_fifo_tuser;
      out_keep_next		    = in_fifo_keep;
      out_tvalid_next               = 0;*/
      out_tlast_next                = 'h0;
      out_tdata_next		    = 256'h0;
      out_tuser_next		    = 128'h0;
      out_keep_next		    = 32'h0;
      out_tvalid_next               = 0;
      rd_preprocess_info            = 0;
      state_next                    = state;
      counter			    = counter_reg;
	send_one_next 		    = 0;
       is_send_pkt_next 	    = 0;
//      in_fifo_rd_en                 = 0;
      send_first		    = 0;
//      send_cross		    = 1;
      case(state)
        WAIT_PREPROCESS_RDY: begin
/*
	  if(parse_order_vld && out_tready) begin
		if(order_index_out[0] == 1'b1) begin	
			state_next = HEADER_0;
			is_send_pkt = 1;
		end
		else begin
	                rd_preprocess_info          = 1;
		end
	  end
*/

          if(parse_order_vld && out_tready) begin
/*
	      if(send_one==0)begin
                if(order_index_out[0] == 1'b1) begin
                        state_next = HEADER_0;
                        //is_send_pkt = 1;
                end
                else begin
                        rd_preprocess_info          = 1;
			send_one = 0 ;
			//is_send_pkt = 0;
                end
	      end
	      else begin
*/

                if(order_index_out[0] == 1'b1) begin
/*
		   if(counter_reg==0)begin
			state_next = HEADER_0;
			send_one = 1;
		   end
		   else begin
*/
		    	if((generate_lock^rd_preprocess_done)==1'b1)begin
                        	state_next = HEADER_0;
                        	is_send_pkt_next = 1;
				send_first = 1;
				send_cross = 0;
		    	end
		    	else begin
				state_next = WAIT_PREPROCESS_RDY;
			end

//		   end
                end
                else begin
                        rd_preprocess_info          = 1;
/*
			if(send_one)begin
				send_cross =1;
			end
			else begin
				send_cross = 0;
			end
*/
			if(rd_preprocess_done)begin
				send_cross = 0;
			end
			else begin
				send_cross = 1;
			end

/*
			send_one = 0 ;
			counter = 0;
			is_send_pkt = 0;
*/
                end

//	      end
/*
                if(order_index_out[0] == 1'b1) begin
			case({send_one,rd_preprocess_done})
			   	2'b10:begin
					state_next = WAIT_PREPROCESS_RDY;
					is_send_pkt = 0;
				end

				2'b01:begin
					//state_next = HEADER_0 ;
					state_next = WAIT_PREPROCESS_RDY;
					//send_one = 1;	
				end

				2'b00:begin
					state_next = HEADER_0;
					//send_one = 1;
				end
				2'b11:begin
					state_next = HEADER_0 ;
					//send_one = 1;
				end
			endcase
                end
                else begin
                        rd_preprocess_info          = 1;
                        send_one = 0 ;
                        counter = 0;
                        is_send_pkt = 0;
                end

*/

	      
          end

        end // case: WAIT_PREPROCESS_RDY
/*
	SEND_PKT: begin
	    if(in_fifo_vld && out_tready) begin
	      //out_tuser_next[C_AXIS_DST_PORT_POS+7:C_AXIS_DST_PORT_POS] = dst_port; 
	      out_tvalid_next	= 1;
	      in_fifo_rd_en	= 1;
	      if(in_fifo_tlast) begin
		state_next =  WAIT_PREPROCESS_RDY;
                 rd_preprocess_info          = 1;
	      end
	    end
	end
        DROP_PKT: begin
           if(in_fifo_vld) begin
              in_fifo_rd_en = 1;
              if(in_fifo_tlast) begin
                 state_next = WAIT_PREPROCESS_RDY;
                 rd_preprocess_info          = 1;
	      end
           end
        end
*/
	WAIT_RD_PREPROCESS_DONE: begin
		if(rd_preprocess_done)begin
			state_next = HEADER_0;
		end
		else begin
			is_send_pkt = 0;
		end
	end

	HEADER_0: begin
		if(out_tready) begin
	                //out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450008004500}, {64'h00f87a2840004006}, {64'h023c8c7452bd8c74}};
	                out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450008004500}, {64'h00E87a2840004006}, {64'h023c8c7452bd8c74}}; //length 224 Before length248
			out_tvalid_next = 1;
			out_tuser_next = {64'h0,16'h08,16'h02,8'h40, 8'h01, 16'hF6}; //106
			out_tlast_next  = 0;
			out_keep_next  = 32'hffffffff;
			state_next      = HEADER_1;
		end
	end
	HEADER_1: begin
		if(out_tready) begin
			//out_tdata_next = {{64'h52b7e704138a0000}, {64'h005ef44151718018}, {64'h0073585b00000101}, {64'h080a020e6781bbc4}};
			out_tdata_next = {{48'h52b9e704138a},ack_value,seq_value,{16'h8018}, {64'h0073b0b200000101},{16'h080a}, {ecr_val+1} , ts_val[31:16]};
			out_tvalid_next = 1;
                        out_tuser_next = {64'h0,16'h08,16'h02,8'h40, 8'h01, 16'hF6};
			out_tlast_next  = 0;
			out_keep_next  = 32'hffffffff;
	                //rd_preprocess_info          = 1;
			//state_next      = WAIT_PREPROCESS_RDY;
			state_next      = PAYLOAD_0;
		end
	end
	PAYLOAD_0: begin
		if(out_tready) begin
			//out_tdata_next = {{64'h0000383d4649582e}, {64'h342e3401393d3135}, {64'h300133353d460133}, {64'h343d303030303030}}; //FIX Length 393d31373301 for TWSE FLAG
			out_tdata_next = {{64'h0000383d4649582e}, {64'h342e3401393d3135}, {64'h370133353d460133}, {64'h343d303030303030}}; //FIX Length 393d31373301 for TWSE FLAG
			out_tvalid_next = 1;
                        out_tuser_next = {64'h0,16'h08,16'h02,8'h40, 8'h01, 16'hF6};
			out_tlast_next  = 0;
			out_keep_next  = 32'hffffffff;
	                //rd_preprocess_info          = 1;
			//state_next      = WAIT_PREPROCESS_RDY;
			state_next      = PAYLOAD_1;
		end
	end
	PAYLOAD_1: begin
		if(out_tready) begin
			//out_tdata_next = {{64'h0134393d434c4945}, {64'h4e54310135323d32}, {64'h303138303130382d}, {64'h31323a32343a3438}};
			out_tdata_next = {{64'h0134393d434c4945}, {56'h4e54310135323d},{4'h3}, pkt_year[15:12], {4'h3}, pkt_year[11:8], {4'h3}, pkt_year[7:4], {4'h3}, pkt_year[3:0], {4'h3}, 
					pkt_mon[7:4], {4'h3}, pkt_mon[3:0],{4'h3}, pkt_day[7:4], {4'h3}, pkt_day[3:0], {8'h2d}, {4'h3}, pkt_hour[7:4], {4'h3}, pkt_hour[3:0], {8'h3a}, {4'h3},
					 pkt_min[7:4], {4'h3}, pkt_min[3:0] , {8'h3a}, {4'h3}, pkt_sec[7:4], {4'h3}, pkt_sec[3:0]};
			out_tvalid_next = 1;
                        out_tuser_next = {64'h0,16'h08,16'h02,8'h40, 8'h01, 16'hF6};
			out_tlast_next  = 0;
			out_keep_next  = 32'hffffffff;
	                //rd_preprocess_info          = 1;
			//state_next      = WAIT_PREPROCESS_RDY;
			state_next      = PAYLOAD_2;
		end
	end
	PAYLOAD_2: begin
		if(out_tready) begin
			//out_tdata_next = {{64'h2e3337330135363d}, {64'h4558454355544f52}, {32'h0134313d}, order_index_out[216:121]}; //31313d44304334 4431344431424334 
			out_tdata_next = {{8'h2e}, {4'h3}, pkt_ms[11:8], {4'h3}, pkt_ms[7:4], {4'h3}, pkt_ms[3:0], {8'h01},{24'h35363d}, {64'h4558454355544f52}, {32'h0134313d}, order_index_out[240:145]}; //31313d44304334 4431344431424334 
			out_tvalid_next = 1;
                        out_tuser_next = {64'h0,16'h08,16'h02,8'h40, 8'h01, 16'hF6};
			out_tlast_next  = 0;
			out_keep_next  = 32'hffffffff;
	                //rd_preprocess_info          = 1;
			//state_next      = WAIT_PREPROCESS_RDY;
			state_next      = PAYLOAD_3;
		end
	end
	PAYLOAD_3: begin
		if(out_tready) begin
			//out_tdata_next = {{64'h0133373d5a30624c}, {64'h4a01313d38383838}, {32'h38383501}, {24'h35353d}, order_index_out[80:33], {8'h01}, {16'h3430}};
			out_tdata_next = {{64'h0131313d30335a30}, {64'h3030323438313838}, {32'h0133373d}, order_index_out[144:105], {56'h01313d38383838}};
			out_tvalid_next = 1;
                        out_tuser_next = {64'h0,16'h08,16'h02,8'h40, 8'h01, 16'hF6};
			out_tlast_next  = 0;
			out_keep_next  = 32'hffffffff;
	                //rd_preprocess_info          = 1;
			//state_next      = WAIT_PREPROCESS_RDY;
			state_next      = PAYLOAD_4;
		end
	end
	PAYLOAD_4: begin
		if(out_tready) begin
			//out_tdata_next = {{64'h3d320133383d3433}, {64'h310135343d310134}, {64'h343d303030303738}, {64'h3230300135393d30}};
			//out_tdata_next = {{56'h3838350135353d}, order_index_out[80:33], {32'h0135343d}, order_index_out[32:25], {8'h01}, {64'h36303d3230313830}, {40'h3130382d31}};
			out_tdata_next = {{56'h3838350135353d}, order_index_out[104:57], {32'h0135343d}, order_index_out[32:25], {8'h01}, {24'h36303d},{4'h3}, pkt_year[15:12], {4'h3}, 
					pkt_year[11:8], {4'h3}, pkt_year[7:4], {4'h3}, pkt_year[3:0], {4'h3},
                                        pkt_mon[7:4], {4'h3}, pkt_mon[3:0],{4'h3}, pkt_day[7:4], {4'h3}, pkt_day[3:0], {8'h2d}, {4'h3}, pkt_hour[7:4]};
			out_tvalid_next = 1; 
                        out_tuser_next = {64'h0,16'h08,16'h02,8'h40, 8'h01, 16'hF6};
			out_tlast_next  = 0;
			out_keep_next  = 32'hffffffff;
	                //rd_preprocess_info          = 1;
			//state_next      = WAIT_PREPROCESS_RDY;
			state_next      = PAYLOAD_5;
		end
	end
	PAYLOAD_5: begin
		if(out_tready) begin
			
			//out_tdata_next = {{64'h323a32343a343801}, {48'h31303030303d}, order_index_out[24:17], {56'h0131303030323d}, order_index_out[16:9], {56'h0131303030343d}, order_index_out[8:1], {8'h01}};
			//out_tdata_next = {{64'h323a32343a343801},{64'h31303d3031310100},{128'h0}};
			out_tdata_next = {{4'h3}, pkt_hour[3:0], {8'h3a}, {4'h3},pkt_min[7:4], {4'h3}, pkt_min[3:0] , {8'h3a}, {4'h3}, pkt_sec[7:4], {4'h3}, pkt_sec[3:0],8'h01,
					  {24'h33383d},{order_index_out[56:33],8'h01},
					 {64'h31303d3031310100},{72'h0}};  
			out_tvalid_next = 1;
		        //out_tuser_next[C_AXIS_DST_PORT_POS+7:0] = {8'h40, 8'h01, 16'h106}; 
                        out_tuser_next = {64'h0,16'h08,16'h02,8'h40, 8'h01, 16'hF6};
	                rd_preprocess_info          = 1;
			out_tlast_next  = 1;
			out_keep_next  = 32'hfffffc00;
			send_one  = 1 ;
			//is_send_pkt = 1;
			counter = counter_reg + 'b1;
			//state_next      = PAYLOAD_6;
			//state_next      = WAIT_PREPROCESS_RDY;
			state_next = WAIT_PREPROCESS_RDY ;
		end
	end
	PAYLOAD_6: begin
		if(out_tready) begin
			out_tdata_next = {{64'h31303d3031010000}, {192'h0}};
			out_tvalid_next = 1;
		        //out_tuser_next[C_AXIS_DST_PORT_POS+7:0] = {8'h40, 8'h01, 16'h106}; 
                        out_tuser_next = {64'h0,16'h08,16'h02,8'h40, 8'h01, 16'h106};
	                rd_preprocess_info          = 1;
			out_tlast_next  = 1;
			out_keep_next  = 32'hfc000000;
			//state_next      = DELAY;
			//send_one 	= 1 ;
			state_next      = WAIT_PREPROCESS_RDY;
		end
	end
	DELAY: begin
		counter = counter_reg + 'b1;
		if(counter_reg == 'd15) begin
			state_next      = WAIT_PREPROCESS_RDY;
			counter = 'h0;
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
         to_from_cpu       <= 0;
         dst_port          <= 'h0;
	 counter_reg	   <= 'h0;
//	 send_one	   <= 0;
      end
      else begin
         state             <= state_next;
	 out_tvalid	   <= out_tvalid_next;
         out_tlast         <= out_tlast_next;
         out_tdata	   <= out_tdata_next;
         out_tuser         <= out_tuser_next;
         out_keep          <= out_keep_next;
         to_from_cpu       <= to_from_cpu_next;
         dst_port          <= dst_port_next;
	 counter_reg	   <= counter;
	 //send_one          <= send_one_next;
	 if(order_index_out[0]==1'b0)begin
		counter_reg <= 0 ;
	 end 
      end // else: !if(reset)
      
   end // always @ (posedge clk)


   always @(posedge clk)begin
	if(reset)begin
		generate_lock <= 1;
		is_send_pkt   <= 0;
	end
	else begin
	   is_send_pkt <= is_send_pkt_next;
	   if(send_cross)begin
		generate_lock <= 1;
	   end
	   else begin
		generate_lock <= 0;
	   end
/*
           if(order_index_out[0]==1'b0)begin
                generate_lock <= 1 ;
           end
	   else begin 
		generate_lock <= 0;
	   end
*/
//	   generate_lock <= 1;
	end
   end


endmodule // op_lut_process_sm

