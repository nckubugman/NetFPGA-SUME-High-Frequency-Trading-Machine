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


module op_lut_process_sm
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
   input [C_S_AXIS_DATA_WIDTH/8-1:0]  in_fifo_keep,
   output reg                         in_fifo_rd_en,

   // --- interface to eth_parser
//   input                              is_arp_pkt,
   input                              is_ip_pkt,
   input                              is_udp_pkt,
   input                              is_for_us,
   input                              is_broadcast,
   input                              eth_parser_info_vld,
   input      [NUM_QUEUES_WIDTH-1:0]  mac_dst_port_num,

   // --- interface to ip_arp
/*   input      [47:0]                  next_hop_mac,
   input      [NUM_QUEUES-1:0]        output_port,
   input                              arp_lookup_hit, // indicates if the next hop mac is correct
   input                              lpm_lookup_hit, // indicates if the route to the destination IP was found
   input                              arp_mac_vld,    // indicates the lookup is done
*/
   // --- interface to op_lut_hdr_parser
   input                              is_from_cpu,
   input      [NUM_QUEUES-1:0]        to_cpu_output_port,   // where to send pkts this pkt if it has to go to the CPU
   input      [NUM_QUEUES-1:0]        from_cpu_output_port, // where to send this pkt if it is coming from the CPU
   input                              is_from_cpu_vld,
   input      [NUM_QUEUES_WIDTH-1:0]  input_port_num,

   // --- interface to IP_checksum
   input                              ip_checksum_vld,
   input                              ip_checksum_is_good,
   input                              ip_hdr_has_options,
//   input      [15:0]                  ip_new_checksum,     // new checksum assuming decremented TTL
//   input                              ip_ttl_is_good,
//   input      [7:0]                   ip_new_ttl,

   // --- input to dest_ip_filter
/*   input                              dest_ip_hit,
   input                              dest_ip_filter_vld,
*/
   // -- connected to all preprocess blocks
   output reg                         rd_preprocess_info,

   // --- interface to next module
   output reg                         		out_tvalid,
   output reg [C_S_AXIS_DATA_WIDTH-1:0]		out_tdata,
   output reg [C_S_AXIS_TUSER_WIDTH-1:0]	out_tuser,     // new checksum assuming decremented TTL
   input                              		out_tready,
   output reg [C_S_AXIS_DATA_WIDTH/8-1:0]  	out_keep,
   output reg					out_tlast,

   // --- interface to registers
   output reg                         pkt_sent_from_cpu,              // pulsed: we've sent a pkt from the CPU
   output reg                         pkt_sent_to_cpu_options_ver,    // pulsed: we've sent a pkt to the CPU coz it has options/bad version
   output reg                         pkt_sent_to_cpu_bad_ttl,        // pulsed: sent a pkt to the CPU coz the TTL is 1 or 0
   output reg                         pkt_sent_to_cpu_dest_ip_hit,    // pulsed: sent a pkt to the CPU coz it has hit in the destination ip filter list
   output reg                         pkt_forwarded,	              // pulsed: forwarded pkt to the destination port
   output reg                         pkt_dropped_checksum,           // pulsed: dropped pkt coz bad checksum
   output reg                         pkt_sent_to_cpu_non_ip,         // pulsed: sent pkt to cpu coz it's not IP
   output reg                         pkt_sent_to_cpu_arp_miss,       // pulsed: sent pkt to cpu coz we didn't find arp entry for next hop ip
   output reg [31:0]                 pkt_sent_to_cpu_lpm_miss,       // pulsed: sent pkt to cpu coz we didn't find lpm entry for destination ip
   output reg                          pkt_dropped_wrong_dst_mac,      // pulsed: dropped pkt not destined to us


   output reg			      fix_logon_trigger,
   output reg                         fix_logout_trigger,
   output reg                         fix_resend_trigger,
   output reg                         tcp_logout_handshake_trigger,
   output reg                         tcp_logon_handshake_trigger,



   input  [47:0]                      mac_0,    // address of rx queue 0
   input  [47:0]                      mac_1,    // address of rx queue 1
   input  [47:0]                      mac_2,    // address of rx queue 2
   input  [47:0]                      mac_3,    // address of rx queue 3

   // --- UDP Checksum
   input  			      udp_checksum_vld,
   input			      udp_checksum_is_good,
   input [25:0]			      udp_value,
   output reg [25:0]		      udp_val,

   // --- IP Feed Filter
   input			      ip_feed_filter_vld,
   input			      is_ip_feed,

   // --- TCP Parse
  
   input                              hand_shake_vld,
   input			      is_tcp_hand_shake,
   input			      is_tcp_ack,
   input			      is_tcp_fin,
  
   input [31:0]		   	      ack_value,
   input [31:0]		   	      seq_value,
   input [31:0]		  	      ts_value,
   input [31:0]		   	      ecr_value,
   
   // --- FIX Parser
   input			   fix_filter_vld, 
   input			      is_fix_order,
   input			      is_fix,
   input                              is_logon,
   input                              is_report,
   input                              is_resend,
   input			      is_heartbeat,
   input			      is_testReq,
   input			      is_logout,

   input			      is_session_reject,
   input			      is_order_cancel_reject,


   // --- connect_signal
   input  [31:0]		      cpu2ip_connect_signal_reg, 

   input  [31:0]		      cpu2ip_shutdown_signal_reg,

   // --- wade clock
   input [15:0]            pkt_year,
   input [15:0]            pkt_mon,
   input [15:0]            pkt_day,
   input [15:0]            pkt_hour,
   input [15:0]            pkt_min,
   input [15:0]            pkt_sec,
   input [15:0]            pkt_ms,
   
   output reg	 	   is_op_send_pkt,
/*
   output reg		   is_connect_syn_pkt,
   output reg		   is_send_ack_pkt,
   output reg		   is_connect_logon_pkt,	   

*/
   // --- wade connect_state_machine

   output syn_sended,
   output is_syn_ack,
//   output logon_sended,
   output is_ack,
   output ack_sended,
   output is_fix_logon,
   output is_fix_report,

   output reg is_connect_pkt,
   output reg is_order_pkt,

   input    is_send_pkt, 
   output reg  rd_preprocess_done,
//   input[216:0]                         order_index_out,
   input [240:0]			  order_index_out,
   // misc
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
   localparam SYN_GEN_1		  = 32;
   localparam SYN_GEN_2		  = 64;
   localparam SYN_GEN_3		  = 128;
   localparam ACK_GEN_1           = 256;
   localparam ACK_GEN_2           = 512;
   localparam ACK_GEN_3           = 1024;   
   localparam HEARTBEAT_GEN_1     = 2048;
   localparam HEARTBEAT_GEN_2     = 4096;
   localparam HEARTBEAT_GEN_3     = 8192;
   localparam HEARTBEAT_GEN_4     = 13100;
   localparam HEARTBEAT_GEN_5     = 13101;

   localparam LOGON_GEN_1     = 13102;
   localparam LOGON_GEN_2     = 13103;
   localparam LOGON_GEN_3     = 13104;
   localparam LOGON_GEN_4     = 13105;
   localparam LOGON_GEN_5     = 13106;
 
   localparam TEST_REQ_HEARTBEAT_GEN_1 = 13107;
   localparam TEST_REQ_HEARTBEAT_GEN_2 = 13108;
   localparam TEST_REQ_HEARTBEAT_GEN_3 = 13109;
   localparam TEST_REQ_HEARTBEAT_GEN_4 = 13110;
   localparam TEST_REQ_HEARTBEAT_GEN_5 = 13111;


   localparam FIN_ACK_GEN_1       = 13112;
   localparam FIN_ACK_GEN_2	      = 13113;
   localparam FIN_ACK_GEN_3	      = 13114;

   localparam LOGOUT_GEN_1    = 13115;
   localparam LOGOUT_GEN_2    = 13116;
   localparam LOGOUT_GEN_3    = 13117;
   localparam LOGOUT_GEN_4    = 13118;
   localparam LOGOUT_GEN_5    = 13119;

   localparam TEST_REQ_GEN_1 = 13120;
   localparam TEST_REQ_GEN_2 = 13121;
   localparam TEST_REQ_GEN_3 = 13122;
   localparam TEST_REQ_GEN_4 = 13123;
   localparam TEST_REQ_GEN_5 = 13124;  

   localparam NEXT_CONNECT_PKT = 13125;
   localparam WAIT_TCP_ACK = 13126;
   localparam DELAY_CYCLE = 13127;
   localparam SEND_REPORT_PKT = 13128;


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
   reg [C_S_AXIS_DATA_WIDTH/8-1:0]	out_tkeep_next;

   reg [47:0]           src_mac_sel;

   reg [NUM_QUEUES-1:0] dst_port;
   reg [NUM_QUEUES-1:0] dst_port_next;

   reg                  to_from_cpu;
   reg                  to_from_cpu_next;

   reg 			counter;
   reg 			counter_next;
 
   reg  		counter_for_shutdown;
   reg			counter_for_shutdown_next;

   wire	[NUM_QUEUES-1:0] output_port;		


   // --- wade stat signal
   
   reg                   send_ack_sig;
   wire                  send_ack_signal;
   wire                  ack_rdy;
   wire [255:0]           ack_tdata;
   wire [31:0]            ack_tkeep;

   reg                   pkt_send_to_log_next;
   reg                   pkt_send_to_log;

   // --- wade connect state machine
   reg                   send_syn_over;
   reg                   send_logon_over;
   reg                   send_ack_over;
   reg                   send_syn_over_next;
   reg                   send_logon_over_next;
   reg                   send_ack_over_next;

   reg			 send_fix_testreq_hearb_next;
   reg			 send_fix_testreq_hearb;
   reg			 send_fix_logout_next;
   reg			 send_fix_logout;
   reg			 send_fix_hearb_next;
   reg			 send_fix_hearb;   


   //  Keep connect  Alive

   reg[31:0] 			 send_pkt_counter_next;
   reg[31:0]			 send_pkt_counter;

   reg			 heartB_seq_num_next;
   reg			 heartB_seq_num;

   reg			is_send_logout_next;
   reg		 	is_send_logout;

   reg			osnt_test;

   reg			fix_connect_start ; 
   reg			fix_connect_start_next;

   wire			fix_logout_sended;
   wire			fix_logon_sended;
   wire			fix_heartb_sended;
   wire			fix_testReq_hearb_sended;
   
   reg          rd_preprocess_done_sm ;
   reg          rd_preprocess_done_sm_next;

   ack_module ack_module(.send_ack_sig(send_ack_sig), .out_rdy(ack_rdy), .out_tdata(ack_tdata), .out_tkeep(ack_tkeep), .reset(reset), .clk(clk));


   //-------------------------- Logic ------------------------------//   
   assign preprocess_vld = eth_parser_info_vld & is_from_cpu_vld & ip_checksum_vld & udp_checksum_vld & ip_feed_filter_vld & hand_shake_vld & fix_filter_vld;
   
   //assign preprocess_vld = eth_parser_info_vld & is_from_cpu_vld & ip_checksum_vld & udp_checksum_vld & ip_feed_filter_vld & fix_filter_vld;

   // --- connect_state machine
   assign syn_sended = send_syn_over;
   assign ack_sended = send_ack_over;
	
   assign fix_logout_sended = send_fix_logout;
   assign fix_logon_sended  = send_logon_over;
   assign fix_heartb_sended = send_fix_hearb;
   assign fix_testReq_hearb_sended = send_fix_testreq_hearb;

   assign is_syn_ack = is_ip_pkt   && is_tcp_hand_shake;
   assign is_fix_logon = is_ip_pkt && is_fix && is_logon;
   assign is_fix_report = is_ip_pkt && is_fix && is_report;
   assign is_ack = is_ip_pkt && is_tcp_ack;
   assign send_ack_signal = send_ack_sig;

   assign output_port = 'h2;  //CPU0

   //assign rd_preprocess_done = rd_preprocess_done_sm;

   /* select the src mac address to write in the forwarded pkt */
   /*always @(*) begin
      case(output_port)
        'h1: src_mac_sel       = mac_0;
        'h4: src_mac_sel       = mac_1;
        'h10: src_mac_sel      = mac_2;
        'h40: src_mac_sel      = mac_3;
        default: src_mac_sel   = mac_0;
      endcase // case(output_port)
   end*/


   /* Modify the packet's hdrs and change tuser */
   always @(*) begin

      out_tlast_next                = in_fifo_tlast;
      out_tdata_next		    = in_fifo_tdata;
      out_tuser_next		    = in_fifo_tuser;
      out_tkeep_next		    = in_fifo_keep;
      out_tvalid_next               = 0;

      rd_preprocess_info            = 0;
      state_next                    = state;
      in_fifo_rd_en                 = 0;
      to_from_cpu_next              = to_from_cpu;
      dst_port_next                 = dst_port;

      pkt_sent_from_cpu             = 0;
      pkt_sent_to_cpu_options_ver   = 0;
      pkt_sent_to_cpu_arp_miss      = 0;
      //pkt_sent_to_cpu_lpm_miss      = 0;
      pkt_sent_to_cpu_bad_ttl       = 0;
      pkt_forwarded                 = 0;
      pkt_dropped_checksum          = 0;
      pkt_sent_to_cpu_non_ip        = 0;
      pkt_dropped_wrong_dst_mac     = 0;
      pkt_sent_to_cpu_dest_ip_hit   = 0;
     
      fix_logon_trigger		    = 0; 
      fix_logout_trigger	    = 0;
      tcp_logout_handshake_trigger  = 0;
      tcp_logon_handshake_trigger   = 0;
      fix_resend_trigger 	    = 0;

      counter_next		    =counter;
      counter_for_shutdown_next     = counter_for_shutdown;
      send_ack_sig                  = 'b0;
      pkt_send_to_log_next          = pkt_send_to_log;
      send_syn_over_next                    = 'b0;
      send_logon_over_next                  = 'b0;
      send_ack_over_next                    = 'b0;
      send_fix_hearb_next		    = 'b0;
      send_fix_testreq_hearb_next	    = 'b0;
      send_fix_logout_next		    = 'b0;

      is_op_send_pkt   		   = 0;    
      heartB_seq_num_next         =0;
      is_send_logout_next 	  = is_send_logout;
      is_order_pkt		 =0;
      is_connect_pkt		 = 0;
      //rd_preprocess_done_sm_next = 0;
      //rd_preprocess_done 	=0;
      case(state)
        WAIT_PREPROCESS_RDY: begin

           if(is_send_pkt)begin
                //rd_preprocess_done_sm_next  = 0;
		rd_preprocess_done = 0;
        	//state_next = WAIT_PREPROCESS_RDY;
	        pkt_sent_from_cpu = 1;
           end
	   else begin
		//rd_preprocess_done_sm_next = 1;
		rd_preprocess_done = 1;
	   end
	     

           if(preprocess_vld) begin
              /* if the packet is from the CPU then all the info on it is correct.
               * We just pipe it to the output */
	            is_op_send_pkt =  1 ;
              /* check that the port on which it was received matches its mac */
              //else if(is_for_us && (input_port_num==mac_dst_port_num || is_broadcast)) begin
              //if((is_for_us) && (input_port_num==mac_dst_port_num || is_broadcast)) begin
              if(ip_checksum_is_good && is_ip_feed && is_udp_pkt && udp_checksum_is_good ) begin
                 	state_next                  = SEND_PKT;
			//pkt_forwarded		    = 1;
			//dst_port_next		    = 'h01;
			pkt_sent_to_cpu_bad_ttl   = 1;
                 	rd_preprocess_info          = 1;
		       	dst_port_next               = output_port;
	      end
              else if(is_tcp_hand_shake ||   is_logon || is_heartbeat) begin
              //else if(is_ip_pkt && (is_tcp_hand_shake || is_tcp_fin || (is_fix && is_heartbeat)||(is_fix && is_testReq))) begin
                     //pkt_sent_to_cpu_options_ver   = 1;
                     to_from_cpu_next   = 0;
                     dst_port_next      = output_port;
                     state_next         = ACK_GEN_1;
                     //state_next       = SEND_PKT ;
                     pkt_forwarded      = 1;
                     //pkt_sent_to_cpu_arp_miss = 1 ;
                     fix_connect_start_next  = 1 ;
                     send_ack_sig       = 1'b1;
              end
 
	      else if(is_ip_pkt && is_fix_order)begin
			state_next = SEND_PKT;
			rd_preprocess_info = 1;
			pkt_forwarded = 1;
			dst_port_next = 'h10;
			//dst_port_next = output_port ;
	      end
              else if(is_testReq) begin
            //  else if(is_ip_pkt && is_fix&& is_testReq)begin
                 //else if(is_ip_pkt && ip_checksum_is_good && (is_fix && is_logon))begin
                     //pkt_sent_to_cpu_options_ver   = 1;
                     to_from_cpu_next   = 0;
                     dst_port_next      = output_port;
                     state_next         = TEST_REQ_HEARTBEAT_GEN_1;
                     //pkt_sent_to_cpu_bad_ttl = 1 ;
              end
              else if( is_report ) begin
	   	    // if(order_index_out[0]=='b0)begin
                     	//pkt_sent_to_cpu_options_ver   = 1;
                     	to_from_cpu_next   = 0;
			  //rd_preprocess_done = 1;
			            //rd_preprocess_info = 1;
                     	//state_next         = DELAY_CYCLE;
			//state_next  = SEND_REPORT_PKT;
			state_next = SEND_REPORT_PKT;
                        //rd_preprocess_done_sm_next = 0;
                     	pkt_sent_to_cpu_bad_ttl = 1 ;
                     	dst_port_next = 'h10;
              end

              //else if(is_fix && (is_send_logout=='b0)) begin
              else if( is_logout )begin
                 //else if(is_ip_pkt && ip_checksum_is_good && (is_fix && is_logon))begin
                     //pkt_sent_to_cpu_options_ver   = 1;
		     //fix_logout_trigger = 1;
		     //rd_preprocess_info = 1;
		     if(is_send_logout=='b0)begin	
			to_from_cpu_next = 0;
			dst_port_next  = output_port;
                     	state_next         = LOGOUT_GEN_1;
		     end
		     else begin
			  state_next = WAIT_PREPROCESS_RDY ;
			  fix_logout_trigger = 1;	
		     end
                    
              end
              else if(is_tcp_fin) begin
                     //pkt_sent_to_cpu_options_ver   = 1;
                     to_from_cpu_next   = 0;
                     dst_port_next      = output_port;
                     //state_next         = HEARTBEAT_GEN_1;
                      state_next         =  ACK_GEN_1;
                     //pkt_sent_to_cpu_arp_miss = 1 ;
                     send_ack_sig       = 1'b1;
              end
              else if(is_resend) begin
                     //pkt_sent_to_cpu_options_ver   = 1;
                     to_from_cpu_next   = 0;
                     dst_port_next      = output_port;
                     //state_next         = HEARTBEAT_GEN_1;
                      state_next         =  ACK_GEN_1;
                     //pkt_sent_to_cpu_arp_miss = 1 ;
                     send_ack_sig       = 1'b1;
		     fix_resend_trigger = 1;
              end
	      else begin // pkt not for us
                 //pkt_sent_to_cpu_non_ip      = 1;
                // pkt_dropped_wrong_dst_mac   = 1;
		 //pkt_sent_to_cpu_lpm_miss    = is_tcp_hand_shake;
                // pkt_sent_to_cpu_bad_ttl      = 1;
                 rd_preprocess_info          = 1;
                 in_fifo_rd_en               = 1;
                 state_next                  = DROP_PKT;
              end // else: (not for_us)

	end
           
	else if(counter == 'b0 && cpu2ip_connect_signal_reg == 1) begin
		pkt_forwarded		    = 1;	
		state_next = SYN_GEN_1;
	end
        else if(counter_for_shutdown == 'b0 && cpu2ip_shutdown_signal_reg == 1) begin
		dst_port_next		    = output_port;
                pkt_forwarded               = 1;
                state_next = LOGOUT_GEN_1;
        end
/*
	else if(osnt_test == 'b1)begin
		
		state_next = SYN_GEN_1;
	end
*/

	//else if(send_pkt_counter == 32'h5F5E1000) begin //160000000
	else if(send_pkt_counter == 32'hFFFFFFFF) begin
		state_next = HEARTBEAT_GEN_1;
	end
	else begin
		state_next = WAIT_PREPROCESS_RDY ;
	end
		
  end // case: WAIT_PREPROCESS_RDY
	WAIT_TCP_ACK: begin
                if(is_tcp_ack)begin
                        //rd_preprocess_done = 1;
			rd_preprocess_info = 1;
			state_next =  WAIT_PREPROCESS_RDY;
			pkt_dropped_checksum = 1;
                end
		else begin
			rd_preprocess_info = 0;
			//rd_preprocess_done = 0;
			state_next = WAIT_TCP_ACK;
			pkt_dropped_wrong_dst_mac = 1;
		end
	end
	SEND_PKT: begin
	    if(in_fifo_vld && out_tready) begin
	      //rd_preprocess_done = 0; 
	      out_tuser_next[C_AXIS_DST_PORT_POS+7:C_AXIS_DST_PORT_POS] = dst_port;
	      //out_tuser_next[C_AXIS_DST_PORT_POS+7:C_AXIS_DST_PORT_POS] = 8'h80;
	      out_tvalid_next	= 1;
	      in_fifo_rd_en	= 1;
	   
	      if(in_fifo_tlast) begin
		 state_next =  WAIT_PREPROCESS_RDY;
		 //rd_preprocess_done = 1;
                 //rd_preprocess_info          = 1;
	      end
	    end
	end
	SEND_REPORT_PKT: begin
            if(in_fifo_vld && out_tready) begin
              rd_preprocess_done_sm_next = 0;
              out_tuser_next[C_AXIS_DST_PORT_POS+7:C_AXIS_DST_PORT_POS] = dst_port;
              //out_tuser_next[C_AXIS_DST_PORT_POS+7:C_AXIS_DST_PORT_POS] = 8'h80;
              out_tvalid_next   = 1;
              in_fifo_rd_en     = 1;

              if(in_fifo_tlast) begin
                 state_next =  ACK_GEN_1;
                 //rd_preprocess_done = 1;
                 //rd_preprocess_info          = 1;
              end
            end
	end
    DROP_PKT: begin
           if(in_fifo_vld) begin
              in_fifo_rd_en = 1;
              if(in_fifo_tlast) begin
                 state_next = WAIT_PREPROCESS_RDY;
                 //rd_preprocess_info          = 1;
              end
           end
    end

    NEXT_CONNECT_PKT: begin
           if(in_fifo_vld) begin
              in_fifo_rd_en = 1;
              if(in_fifo_tlast&&in_fifo_vld) begin
                 rd_preprocess_info          = 1;
                 //state_next = (is_tcp_hand_shake)? LOGON_GEN_1: WAIT_PREPROCESS_RDY;
                 if(is_tcp_hand_shake)begin
                        state_next = LOGON_GEN_1;
                        is_send_logout_next = 1'b0;
                 end
  	    	     else if(is_report)begin
		    	        //rd_preprocess_done_sm_next = 1;
				rd_preprocess_done = 1;
			            state_next = WAIT_PREPROCESS_RDY;
		         end
/*
                 else if(is_testReq)begin
                        state_next = TEST_REQ_HEARTBEAT_GEN_1;
                 end
*/
                else if(is_resend)begin
                        state_next = HEARTBEAT_GEN_1    ;
                end
                else if(is_logon)begin
                        fix_logon_trigger = 1;
                        state_next = WAIT_PREPROCESS_RDY;
                end
                else if(is_tcp_fin)begin
                        tcp_logout_handshake_trigger = 1;
                        state_next = WAIT_PREPROCESS_RDY;
                end
/*
                else if(is_logout)begin
                        //fix_logout_trigger = 1;
                        state_next = WAIT_PREPROCESS_RDY;
                end
*/
                /*
                 else if(is_logout&&is_send_logout=='b0)begin
                        state_next = LOGOUT_GEN_1;
                 end
                 else if(is_logon)begin
                        state_next = LOGOUT_GEN_1;
                 end
                */
/*
                 else if(is_tcp_fin)begin
                        state_next = FIN_ACK_GEN_1;
                 end
*/
                 else begin
                        state_next = WAIT_PREPROCESS_RDY;
                 end
              end
           end
    end

    SYN_GEN_1: begin
           if(out_tready) begin
	      	out_tvalid_next	= 1;
           	//out_tdata_next = {{64'h1c6f65ac1d4fcafe}, {64'hf00d000108004500}, {64'h003c7a2640004006}, {64'h023c8c7452bd8c74}};
    //		out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450308004500}, {64'h003c7a2640004006}, {64'h023c8c7452bd8c74}};
    		out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450008004500}, {64'h003c7a2640004006}, {64'h02378c7452bd8c74}};
	        out_tuser_next = {64'h0,16'h01,16'h01,8'h40, 8'h04, 16'h4a}; 
    		out_tlast_next = 0;
    		out_tkeep_next  = 32'hffffffff;
    		state_next = SYN_GEN_2;
	      end
    end
    SYN_GEN_2: begin
           if(out_tready) begin
	      	out_tvalid_next	= 1;
           	out_tdata_next = {{64'h52b9e704138a0000}, {64'h000000000000a002}, {64'h3908ec7c00000204}, {64'h05b40402080a020e}};
	        out_tuser_next = {64'h0,16'h01,16'h01,8'h40, 8'h04, 16'h4a}; 
		    out_tlast_next = 0;
		    out_tkeep_next  = 32'hffffffff;
		    state_next = SYN_GEN_3;
	      end
    end
    SYN_GEN_3: begin
           if(out_tready) begin
	      	out_tvalid_next	= 1;
           	out_tdata_next = {{64'h677f000000000103}, {64'h0307000000000000}, {64'h0}, {64'h0}};
	        out_tuser_next = {64'h0,16'h01,16'h01,8'h40, 8'h04, 16'h4a}; 
		    out_tlast_next = 1;
		    out_tkeep_next  = 32'hffc00000;
		    state_next =  WAIT_PREPROCESS_RDY;
		    is_op_send_pkt = 1;
            send_syn_over_next = 1'b1;
		    tcp_logon_handshake_trigger = 1;
	//	rd_preprocess_info = 1;
	      end
    end
    ACK_GEN_1: begin
           if(out_tready && ack_rdy) begin
//	     if(out_tready)begin
	      	out_tvalid_next	= 1;
           	
	        out_tuser_next = {64'h0,16'h02,16'h01,8'h40, 8'h04, 16'h42}; 
	    	out_tlast_next = 0;

            out_tdata_next = ack_tdata;
            out_tkeep_next = ack_tkeep;

/*
                out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450008004500}, {64'h003c7a2640004006}, {64'h02378c7452bd8c74}};
		out_tkeep_next = 32'hffffffff;
*/
    		state_next = ACK_GEN_2;
	      end
    end

    ACK_GEN_2: begin
           if(out_tready&& ack_rdy) begin
//	     if(out_tready)begin
	      	out_tvalid_next	= 1;
/*
           	out_tdata_next = {{64'h52b7e704138a0000}, {64'h000000000000a002}, {64'h3908ec8100000204}, {64'h05b40402080a020e}};
*/
	        out_tuser_next = {64'h0,16'h02,16'h01,8'h40, 8'h04, 16'h42}; 
    		out_tlast_next = 0;
    //		out_tkeep_next  = 32'hffffffff;

            out_tdata_next[255:192] ={ ack_tdata[255:208],ack_value[31:16]};
    		out_tdata_next[191:128]= (is_tcp_fin) ? {ack_value[15:0], seq_value, {16'h8011}}: {ack_value[15:0], seq_value, {16'h8010}};
//          out_tdata_next[191:128]=  {ack_value[15:0], seq_value, {16'h8010}};
            out_tdata_next[127:64]  = ack_tdata[127:64];
            out_tdata_next[63:0]    = {{16'h080a}, {ecr_value+1}, ts_value[31:16]};
            out_tkeep_next = ack_tkeep;
		    state_next = ACK_GEN_3;
	       end
    end
    ACK_GEN_3: begin
           if(out_tready && ack_rdy) begin
//	     if(out_tready)begin
/*
		out_tdata_next = {16'hffff , 240'h0};
		out_tkeep_next = 32'hc0000000;
*/
	      	out_tvalid_next	= 1;
           	out_tdata_next = {{ts_value[15:0],ack_tdata[175:128]},{64'h0}, {64'h0}, {64'h0}};
           	
	        out_tuser_next = {64'h0,16'h02,16'h01,8'h40, 8'h04, 16'h42}; 
		out_tlast_next = 1;
		out_tkeep_next  = 32'hc0000000;
		//state_next = DROP_PKT;
		state_next = NEXT_CONNECT_PKT;
		is_op_send_pkt  =  1;
	//	rd_preprocess_info = 1;
		send_ack_over_next = 1;
/*
		if(is_report)begin
			rd_preprocess_info = 1;
			state_next = SEND_PKT;			
			rd_preprocess_done = 1;
		end
*/
	   end
        end

        LOGON_GEN_1: begin
           if(out_tready) begin
                out_tvalid_next = 1; 
		out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450008004500}, {64'h00917a2840004006}, {64'h023c8c7452bd8c74}};
                out_tuser_next = {64'h0,16'h04,16'h02,8'h40, 8'h04, 16'h9f};
                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = LOGON_GEN_2;
           end
	  
        end
        LOGON_GEN_2: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                out_tdata_next = {{48'h52b9e704138a},ack_value,seq_value,{16'h8018}, {64'h0073b0b200000101},{16'h080a}, {ecr_value+1} , ts_value[31:16]};
                out_tuser_next = {64'h0,16'h04,16'h02,8'h40, 8'h04, 16'h9f};
                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = LOGON_GEN_3;
           end
        end

        LOGON_GEN_3: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                out_tdata_next = {ts_value[15:0], {48'h383d4649582e}, {64'h342e3401393d3731},{64'h0133353d41013334},{64'h3d30310134393d43}};
                out_tuser_next  = {64'h0,16'h04,16'h02,8'h40, 8'h04, 16'h9f};
                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = LOGON_GEN_4;
           end
        end

        LOGON_GEN_4: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                out_tdata_next = {{64'h4c49454e54310135}, 
				 {16'h323d}, {4'h3}, pkt_year[15:12], {4'h3}, pkt_year[11:8], {4'h3}, pkt_year[7:4], {4'h3}, pkt_year[3:0], {4'h3}, pkt_mon[7:4], {4'h3}, pkt_mon[3:0],
				 {4'h3}, pkt_day[7:4], {4'h3}, pkt_day[3:0], {8'h2d}, {4'h3}, pkt_hour[7:4], {4'h3}, pkt_hour[3:0], {8'h3a}, {4'h3}, pkt_min[7:4], {4'h3}, pkt_min[3:0] ,
				 {8'h3a}, {4'h3}, pkt_sec[7:4], {4'h3}, pkt_sec[3:0], {8'h2e}, {4'h3}, pkt_ms[11:8], {4'h3}, pkt_ms[7:4], {4'h3}, pkt_ms[3:0], {8'h01}};
                out_tuser_next = {64'h0,16'h04,16'h02,8'h40, 8'h04, 16'h9f};
                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = LOGON_GEN_5;
           end
        end

        LOGON_GEN_5: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                out_tdata_next = {{64'h35363d4558454355}, {64'h544f520139383d30}, {64'h013130383d333001}, {64'h31303d3134300100}};
                out_tuser_next = {64'h0,16'h04,16'h02,8'h40, 8'h04, 16'h9f}; //{80,Begin of FIXchecksum,32}
                out_tlast_next = 1;
                out_tkeep_next  = 32'hfffffffe;
                state_next = WAIT_PREPROCESS_RDY;
		
                send_logon_over_next   = 'b1;
		        is_op_send_pkt = 1;
		//send_pkt_counter_next=0;
           end
        end

        TEST_REQ_HEARTBEAT_GEN_1: begin
           if(out_tready) begin
                out_tvalid_next = 1;
//	        out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450008004500}, {64'h008d7a2640004006}, {64'h023c8c7452bd8c74}};
//                out_tuser_next  = {64'h0,16'h27,16'h02,8'h01, 8'h01, 16'h9b};
		out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450008004500}, {64'h00927a2640004006}, {64'h023c8c7452bd8c74}};
                out_tuser_next = {64'h0,16'h05,16'h02,8'h40,8'h04,16'ha0}; //1f

                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = TEST_REQ_HEARTBEAT_GEN_2;
           end
        end
        TEST_REQ_HEARTBEAT_GEN_2: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                out_tdata_next = {{48'h52b9e704138a},ack_value,seq_value,{16'h8018}, {64'h0073b0b200000101},{16'h080a}, {ecr_value+1} , ts_value[31:16]};
//                out_tuser_next = {64'h0,16'h27,16'h02,8'h01, 8'h01, 16'h9b};
                out_tuser_next = {64'h0,16'h05,16'h02,8'h40,8'h04,16'ha0};

                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = TEST_REQ_HEARTBEAT_GEN_3;
           end
        end

        TEST_REQ_HEARTBEAT_GEN_3: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                //out_tdata_next = {ts_value[15:0], {48'h383d4649582e}, {64'h342e3401393d3637},{64'h0133353d30013334},{64'h3d320134393d434c}};
                //out_tuser_next= {64'h0,16'h27,16'h02,8'h01, 8'h01, 16'h9b};
		out_tdata_next = {ts_value[15:0], {48'h383d4649582e}, {64'h342e3401393d3732},{64'h0133353d30013334},{64'h3d30303030303201}};
                out_tuser_next = {64'h0,16'h05,16'h02,8'h40,8'h04,16'ha0};

                out_tlast_next = 0;
                out_tkeep_next  = 32'hfffffffff;
                state_next =  TEST_REQ_HEARTBEAT_GEN_4;
           end
        end

        TEST_REQ_HEARTBEAT_GEN_4: begin
           if(out_tready) begin
                out_tvalid_next = 1;
/*
                out_tdata_next = {{64'h49454e5431013532},
                                 {8'h3d}, {4'h3}, pkt_year[15:12], {4'h3}, pkt_year[11:8], {4'h3}, pkt_year[7:4], {4'h3}, pkt_year[3:0], {4'h3}, pkt_mon[7:4], {4'h3}, pkt_mon[3:0],
                                 {4'h3}, pkt_day[7:4], {4'h3}, pkt_day[3:0], {8'h2d}, {4'h3}, pkt_hour[7:4], {4'h3}, pkt_hour[3:0], {8'h3a}, {4'h3}, pkt_min[7:4], {4'h3}, pkt_min[3:0] ,
                                 {8'h3a}, {4'h3}, pkt_sec[7:4], {4'h3}, pkt_sec[3:0], {8'h2e}, {4'h3}, pkt_ms[11:8], {4'h3}, pkt_ms[7:4], {4'h3}, pkt_ms[3:0], {8'h01},{8'h35}};

		out_tuser_next = {64'h0,16'h27,16'h02,8'h01, 8'h01, 16'h9b};
*/
                out_tdata_next = {{64'h34393d434c49454e}, {40'h5431013532},
                                 {8'h3d}, {4'h3}, pkt_year[15:12], {4'h3}, pkt_year[11:8],
 				 {4'h3}, pkt_year[7:4], {4'h3}, pkt_year[3:0], {4'h3}, pkt_mon[7:4], {4'h3}, pkt_mon[3:0],
                                 {4'h3}, pkt_day[7:4], {4'h3}, pkt_day[3:0], {8'h2d}, {4'h3}, pkt_hour[7:4], {4'h3}, pkt_hour[3:0], {8'h3a}, {4'h3}, pkt_min[7:4], {4'h3}, pkt_min[3:0] ,
                                 {8'h3a}, {4'h3}, pkt_sec[7:4], {4'h3}, pkt_sec[3:0], {8'h2e}};
                out_tuser_next = {64'h0,16'h05,16'h02,8'h40,8'h04,16'ha0};

                out_tlast_next = 0;
                out_tkeep_next  = 32'hfffffffff;
                state_next =  TEST_REQ_HEARTBEAT_GEN_5;
           end
        end

        TEST_REQ_HEARTBEAT_GEN_5: begin
           if(out_tready) begin
                out_tvalid_next = 1;
//		out_tdata_next =   {{64'h363d455845435554},{64'h4f52013131323d54},{64'h4553540131303d32},{24'h303801},{40'h0}};
                out_tdata_next =   {
					{4'h3}, pkt_ms[11:8], {4'h3}, pkt_ms[7:4], {4'h3}, pkt_ms[3:0], {8'h01},{8'h35},
					{64'h363d455845435554},{64'h4f52013131323d54},{64'h4553540131303d32},{24'h303801}
				   };

//                out_tuser_next  = {64'h0,16'h27,16'h02,8'h01, 8'h01, 16'h9b};
		        out_tuser_next = {64'h0,16'h05,16'h02,8'h40,8'h04,16'ha0};
                out_tlast_next = 1;
//                out_tkeep_next  = 32'hffffffe0;
		        out_tkeep_next  =   32'hffffffff;
                state_next =  WAIT_PREPROCESS_RDY;
		        is_op_send_pkt = 1;
		        rd_preprocess_info = 1;
		        send_fix_testreq_hearb_next = 'b1;
		//send_pkt_counter_next = 0;
           end
        end

        HEARTBEAT_GEN_1: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450008004500}, {64'h00897a2640004006}, {64'h023c8c7452bd8c74}};
                out_tuser_next  = {64'h0,16'h06,16'h02,8'h40, 8'h04, 16'h97};
                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = HEARTBEAT_GEN_2;
           end
        end
        HEARTBEAT_GEN_2: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                //out_tdata_next[255:192] = {{48'h54d40854033b}, ack_value[31:16]};
                //out_tdata_next[191:128]  = (is_tcp_fin) ? {ack_value[15:0], seq_value, {16'h8011}} : {ack_value[15:0], seq_value, {16'h8010}};
                //out_tdata_next[127:64]  = 64'h0073239200000101;
                //out_tdata_next[63:0]    = {{16'h080a}, {ecr_value+1}, ts_value[31:16]};
                //out_tdata_next = {{64'h52b9e704138a0000}, {64'h000000000000a002}, {64'h3908ec8100000204}, {64'h05b40402080a020e}};
                out_tdata_next = {{48'h52b9e704138a},ack_value,seq_value,{16'h8018}, {64'h0073b0b200000101},{16'h080a}, {ecr_value+1} , ts_value[31:16]};
                out_tuser_next = {64'h0,16'h06,16'h02,8'h40, 8'h04, 16'h97};
                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = HEARTBEAT_GEN_3;
           end
        end

        HEARTBEAT_GEN_3: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                //out_tdata_next = {ts_value[15:0], {48'h383d4649582e}, {64'h342e3401393d3631},{64'h0133353d30013334},{64'h3d320134393d434c}};
                out_tdata_next = {ts_value[15:0], {48'h383d4649582e}, {64'h342e3401393d3633},{64'h0133353d30013334},{64'h3d30303030303001}};

                heartB_seq_num_next = heartB_seq_num_next +4'h1 ;
                out_tuser_next= {64'h0,16'h06,16'h02,8'h40, 8'h04, 16'h97};
                out_tlast_next = 0;
                out_tkeep_next  = 32'hfffffffff;
                state_next =  HEARTBEAT_GEN_4;
           end
        end

        HEARTBEAT_GEN_4: begin
           if(out_tready) begin
                out_tvalid_next = 1;
/*
                out_tdata_next = {{64'h49454e5431013532},
                                 {8'h3d}, {4'h3}, pkt_year[15:12], {4'h3}, pkt_year[11:8], {4'h3}, pkt_year[7:4], {4'h3}, pkt_year[3:0], {4'h3}, pkt_mon[7:4], {4'h3}, pkt_mon[3:0],
                                 {4'h3}, pkt_day[7:4], {4'h3}, pkt_day[3:0], {8'h2d}, {4'h3}, pkt_hour[7:4], {4'h3}, pkt_hour[3:0], {8'h3a}, {4'h3}, pkt_min[7:4], {4'h3}, pkt_min[3:0] ,
                                 {8'h3a}, {4'h3}, pkt_sec[7:4], {4'h3}, pkt_sec[3:0], {8'h2e}, {4'h3}, pkt_ms[11:8], {4'h3}, pkt_ms[7:4], {4'h3}, pkt_ms[3:0], {8'h01},{8'h35}};
*/
                out_tdata_next = {{64'h34393d434c49454e}, {40'h5431013532},
                                 {8'h3d}, {4'h3}, pkt_year[15:12], {4'h3}, pkt_year[11:8],
                                 {4'h3}, pkt_year[7:4], {4'h3}, pkt_year[3:0], {4'h3}, pkt_mon[7:4], {4'h3}, pkt_mon[3:0],
                                 {4'h3}, pkt_day[7:4], {4'h3}, pkt_day[3:0], {8'h2d}, {4'h3}, pkt_hour[7:4], {4'h3}, pkt_hour[3:0], {8'h3a}, {4'h3}, pkt_min[7:4], {4'h3}, pkt_min[3:0] ,
                                 {8'h3a}, {4'h3}, pkt_sec[7:4], {4'h3}, pkt_sec[3:0], {8'h2e}};

                out_tuser_next = {64'h0,16'h06,16'h02,8'h40, 8'h04, 16'h97};
                out_tlast_next = 0;
                out_tkeep_next  = 32'hfffffffff;
                state_next =  HEARTBEAT_GEN_5;
           end
        end

        HEARTBEAT_GEN_5: begin
           if(out_tready) begin
                out_tvalid_next = 1;
//                out_tdata_next = {{64'h363d455845435554},{64'h4f520131303d3230},{16'h3801},{48'h0},{64'h0}};
                out_tdata_next =   {
                                      {4'h3}, pkt_ms[11:8], {4'h3}, pkt_ms[7:4], {4'h3}, pkt_ms[3:0], {8'h01},{8'h35},{24'h363d45},
                                      {64'h58454355544f5201},{56'h31303d32303801},8'h0,64'h0
                                   };

                out_tuser_next  = {64'h0,16'h06,16'h02,8'h40, 8'h04, 16'h97};
                out_tlast_next = 1;
                out_tkeep_next  = 32'hfffffe00;
                state_next =  WAIT_PREPROCESS_RDY;
                is_op_send_pkt = 1;
		send_fix_hearb_next = 'b1;
		rd_preprocess_info = 1;
                //send_pkt_counter_next = 0;
           end
        end

       //total length 150  IPv4 total length 136
        LOGOUT_GEN_1: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450008004500}, {64'h00897a2840004006}, {64'h023c8c7452bd8c74}};
                out_tuser_next = {64'h0,16'h07,16'h02,8'h40, 8'h04, 16'h97};
                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = LOGOUT_GEN_2;
           end

        end
        LOGOUT_GEN_2: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                out_tdata_next = {{48'h52b9e704138a},ack_value,seq_value,{16'h8018}, {64'h0073b0b200000101},{16'h080a}, {ecr_value+1} , ts_value[31:16]};
                out_tuser_next = {64'h0,16'h07,16'h02,8'h40, 8'h04, 16'h97};
                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = LOGOUT_GEN_3;
           end
        end

        LOGOUT_GEN_3: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                out_tdata_next = {ts_value[15:0], {48'h383d4649582e}, {64'h342e3401393d3633},{64'h0133353d35013334},{64'h3d30303030303201}};
                out_tuser_next  = {64'h0,16'h07,16'h02,8'h40, 8'h04, 16'h97};
                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = LOGOUT_GEN_4;
           end
        end

        LOGOUT_GEN_4: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                out_tdata_next = {{64'h34393d434c49454e}, {40'h5431013532},
                                 {8'h3d}, {4'h3}, pkt_year[15:12], {4'h3}, pkt_year[11:8],
                                 {4'h3}, pkt_year[7:4], {4'h3}, pkt_year[3:0], {4'h3}, pkt_mon[7:4], {4'h3}, pkt_mon[3:0],
                                 {4'h3}, pkt_day[7:4], {4'h3}, pkt_day[3:0], {8'h2d}, {4'h3}, pkt_hour[7:4], {4'h3}, pkt_hour[3:0], {8'h3a}, {4'h3}, pkt_min[7:4], {4'h3}, pkt_min[3:0] ,
                                 {8'h3a}, {4'h3}, pkt_sec[7:4], {4'h3}, pkt_sec[3:0], {8'h2e}};

                out_tuser_next = {64'h0,16'h07,16'h02,8'h40, 8'h04, 16'h97};
                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = LOGOUT_GEN_5;
           end
        end

        LOGOUT_GEN_5: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                out_tdata_next =   {
                                        {4'h3}, pkt_ms[11:8], {4'h3}, pkt_ms[7:4], {4'h3}, pkt_ms[3:0], {8'h01},{8'h35},
                                        {64'h363d455845435554},{64'h4f520131303d3230},{16'h3801},{8'h0},{64'h0}
                                   };
                out_tuser_next = {64'h0,16'h07,16'h02,8'h40, 8'h04, 16'h97}; //{80,Begin of FIXchecksum,32}
                out_tlast_next = 1;
                out_tkeep_next  = 32'hfffffe00;
                state_next = WAIT_PREPROCESS_RDY;

                send_fix_logout_next   = 'b1;
                is_op_send_pkt = 1;
		is_send_logout_next = 1;
		fix_logout_trigger = 1;
		//send_pkt_counter_next = 0;
           end
        end

        FIN_ACK_GEN_1: begin
           if(out_tready && ack_rdy) begin
//           if(out_tready)begin
                out_tvalid_next = 1;

                out_tuser_next = {64'h0,16'h0,16'h01,8'h01, 8'h01, 16'h42};
                out_tlast_next = 0;

                out_tdata_next = ack_tdata;
                out_tkeep_next = ack_tkeep;

/*
                out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450008004500}, {64'h003c7a2640004006}, {64'h02378c7452bd8c74}};
                out_tkeep_next = 32'hffffffff;
*/
                state_next = ACK_GEN_2;
           end
        end

        FIN_ACK_GEN_2: begin
           if(out_tready&& ack_rdy) begin
//           if(out_tready)begin
                out_tvalid_next = 1;
/*
                out_tdata_next = {{64'h52b7e704138a0000}, {64'h000000000000a002}, {64'h3908ec8100000204}, {64'h05b40402080a020e}};
*/
                out_tuser_next = {64'h0,16'h0,16'h01,8'h01, 8'h01, 16'h42};
                out_tlast_next = 0;
//              out_tkeep_next  = 32'hffffffff;

                out_tdata_next[255:192] ={ ack_tdata[255:208],ack_value[31:16]};
                out_tdata_next[191:128]= {ack_value[15:0], seq_value, {16'h8011}};
                out_tdata_next[127:64]  = ack_tdata[127:64];
                out_tdata_next[63:0]    = {{16'h080a}, {ecr_value+1}, ts_value[31:16]};
                out_tkeep_next = ack_tkeep;

                state_next = ACK_GEN_3;
           end
        end
        FIN_ACK_GEN_3: begin
           if(out_tready && ack_rdy) begin
//           if(out_tready)begin
/*
                out_tdata_next = {16'hffff , 240'h0};
                out_tkeep_next = 32'hc0000000;
*/
                out_tvalid_next = 1;
                out_tdata_next = {{ts_value[15:0],ack_tdata[175:128]},{64'h0}, {64'h0}, {64'h0}};

                out_tuser_next = {64'h0,16'h0,16'h01,8'h01, 8'h01, 16'h42};
                out_tlast_next = 1;
                out_tkeep_next  = 32'hc0000000;
                //state_next =  WAIT_PREPROCESS_RDY;
                state_next = DROP_PKT;
                is_op_send_pkt  =  1;
        //      rd_preprocess_info = 1;
                send_ack_over_next = 1;
           end
        end

        TEST_REQ_GEN_1: begin
           if(out_tready) begin
                out_tvalid_next = 1;
//              out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450008004500}, {64'h008d7a2640004006}, {64'h023c8c7452bd8c74}};
//                out_tuser_next  = {64'h0,16'h27,16'h02,8'h01, 8'h01, 16'h9b};
                out_tdata_next = {{64'h1402ec6d90100253}, {64'h554d450008004500}, {64'h00927a2640004006}, {64'h023c8c7452bd8c74}};
                out_tuser_next = {64'h0,16'h1f,16'h02,8'h01,8'h01,16'ha0};

                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = TEST_REQ_HEARTBEAT_GEN_2;
           end
        end
        TEST_REQ_GEN_2: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                out_tdata_next = {{48'h52b9e704138a},ack_value,seq_value,{16'h8018}, {64'h0073b0b200000101},{16'h080a}, {ecr_value+1} , ts_value[31:16]};
//                out_tuser_next = {64'h0,16'h27,16'h02,8'h01, 8'h01, 16'h9b};
                out_tuser_next = {64'h0,16'h1f,16'h02,8'h01,8'h01,16'ha0};

                out_tlast_next = 0;
                out_tkeep_next  = 32'hffffffff;
                state_next = TEST_REQ_HEARTBEAT_GEN_3;
           end
        end

        TEST_REQ_GEN_3: begin
           if(out_tready) begin
                out_tvalid_next = 1;
                //out_tdata_next = {ts_value[15:0], {48'h383d4649582e}, {64'h342e3401393d3637},{64'h0133353d30013334},{64'h3d320134393d434c}};
                //out_tuser_next= {64'h0,16'h27,16'h02,8'h01, 8'h01, 16'h9b};
                out_tdata_next = {ts_value[15:0], {48'h383d4649582e}, {64'h342e3401393d3732},{64'h0133353d30013334},{64'h3d30303030303201}};
                out_tuser_next = {64'h0,16'h1f,16'h02,8'h01,8'h01,16'ha0};

                out_tlast_next = 0;
                out_tkeep_next  = 32'hfffffffff;
                state_next =  TEST_REQ_HEARTBEAT_GEN_4;
           end
        end

        TEST_REQ_GEN_4: begin
           if(out_tready) begin
                out_tvalid_next = 1;
/*
                out_tdata_next = {{64'h49454e5431013532},
                                 {8'h3d}, {4'h3}, pkt_year[15:12], {4'h3}, pkt_year[11:8], {4'h3}, pkt_year[7:4], {4'h3}, pkt_year[3:0], {4'h3}, pkt_mon[7:4], {4'h3}, pkt_mon[3:0],
                                 {4'h3}, pkt_day[7:4], {4'h3}, pkt_day[3:0], {8'h2d}, {4'h3}, pkt_hour[7:4], {4'h3}, pkt_hour[3:0], {8'h3a}, {4'h3}, pkt_min[7:4], {4'h3}, pkt_min[3:0] ,
                                 {8'h3a}, {4'h3}, pkt_sec[7:4], {4'h3}, pkt_sec[3:0], {8'h2e}, {4'h3}, pkt_ms[11:8], {4'h3}, pkt_ms[7:4], {4'h3}, pkt_ms[3:0], {8'h01},{8'h35}};

                out_tuser_next = {64'h0,16'h27,16'h02,8'h01, 8'h01, 16'h9b};
*/
                out_tdata_next = {{64'h34393d434c49454e}, {40'h5431013532},
                                 {8'h3d}, {4'h3}, pkt_year[15:12], {4'h3}, pkt_year[11:8],
                                 {4'h3}, pkt_year[7:4], {4'h3}, pkt_year[3:0], {4'h3}, pkt_mon[7:4], {4'h3}, pkt_mon[3:0],
                                 {4'h3}, pkt_day[7:4], {4'h3}, pkt_day[3:0], {8'h2d}, {4'h3}, pkt_hour[7:4], {4'h3}, pkt_hour[3:0], {8'h3a}, {4'h3}, pkt_min[7:4], {4'h3}, pkt_min[3:0] ,
                                 {8'h3a}, {4'h3}, pkt_sec[7:4], {4'h3}, pkt_sec[3:0], {8'h2e}};
                out_tuser_next = {64'h0,16'h1f,16'h02,8'h01,8'h01,16'ha0};

                out_tlast_next = 0;
                out_tkeep_next  = 32'hfffffffff;
                state_next =  TEST_REQ_HEARTBEAT_GEN_5;
           end
        end

        TEST_REQ_GEN_5: begin
           if(out_tready) begin
                out_tvalid_next = 1;
//              out_tdata_next =   {{64'h363d455845435554},{64'h4f52013131323d54},{64'h4553540131303d32},{24'h303801},{40'h0}};
                out_tdata_next =   {
                                        {4'h3}, pkt_ms[11:8], {4'h3}, pkt_ms[7:4], {4'h3}, pkt_ms[3:0], {8'h01},{8'h35},
                                        {64'h363d455845435554},{64'h4f52013131323d54},{64'h4553540131303d32},{24'h303801}
                                   };

//                out_tuser_next  = {64'h0,16'h27,16'h02,8'h01, 8'h01, 16'h9b};
                out_tuser_next = {64'h0,16'h1f,16'h02,8'h01,8'h01,16'ha0};
                out_tlast_next = 1;
//                out_tkeep_next  = 32'hffffffe0;
                out_tkeep_next  =   32'hffffffff;
                state_next =  WAIT_PREPROCESS_RDY;
                is_op_send_pkt = 1;
        //      rd_preprocess_info = 1;
           //     send_pkt_counter_next = 0;
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
    	 counter 	   <= 1'b0;
    	 counter_for_shutdown <= 1'b0;
         send_syn_over     <= 'b0;
         send_logon_over   <= 'b0;
         send_ack_over     <= 'b0;
    	 send_fix_testreq_hearb <= 'b0;
    	 send_fix_logout   <= 'b0;
    	 send_fix_hearb	   <= 'b0;
         pkt_send_to_log   <= 'b0;
    //	 send_pkt_counter  <= 0;
         heartB_seq_num    <= 'h0;
    	 is_send_logout    <= 1'b0;
    	 osnt_test	   <= 0;
    	 pkt_sent_to_cpu_lpm_miss <= 0;
    	 fix_connect_start <= 0;
         rd_preprocess_done_sm <= 1;
      end
      else begin
    	 osnt_test 	   <= 1;
         state             <= state_next;
    	 out_tvalid	   <= out_tvalid_next;
         out_tlast         <= out_tlast_next;
         out_tdata	   <= out_tdata_next;
         out_tuser         <= out_tuser_next;
         out_keep         <= out_tkeep_next;
         to_from_cpu       <= to_from_cpu_next;
         dst_port          <= dst_port_next;
    	 counter	   <= cpu2ip_connect_signal_reg;
    	 counter_for_shutdown <= cpu2ip_shutdown_signal_reg;
         pkt_send_to_log   <= pkt_send_to_log_next;
         send_syn_over     <= send_syn_over_next;
         send_logon_over   <= send_logon_over_next;
         send_ack_over     <= send_ack_over_next;
    	 send_fix_hearb    <= send_fix_hearb_next;
    	 send_fix_testreq_hearb<=send_fix_testreq_hearb_next;
    	 send_fix_logout   <= send_fix_logout_next;
    	 heartB_seq_num    <= heartB_seq_num_next;
    	 is_send_logout    <= is_send_logout_next;
    	 pkt_sent_to_cpu_lpm_miss<= send_pkt_counter;
    	 fix_connect_start  <= fix_connect_start_next;
         rd_preprocess_done_sm <= rd_preprocess_done_sm_next;
      end // else: !if(reset)
   end // always @ (posedge clk)

   always @(posedge clk) begin
	if(reset)begin
		send_pkt_counter <= 0;
        	//rd_preprocess_done <= 1 ;
	end
	else begin
/*
             if(rd_preprocess_done_sm)begin
                rd_preprocess_done <= 1;
             end
             else begin
                rd_preprocess_done <= 0;
             end
*/
	         if(fix_connect_start)begin
	                 if(is_send_pkt||fix_logout_sended||fix_logon_sended||fix_heartb_sended||fix_testReq_hearb_sended)begin
	                       send_pkt_counter <= 0 ;
	                 end
	                 else begin
	                       send_pkt_counter <= send_pkt_counter + 1;
	                 end
	         end

	end	
   end
	

endmodule // op_lut_process_sm

