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


module ip_feed_fix_parser
#(
    //Master AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH	= 256,
    parameter C_S_AXIS_DATA_WIDTH	= 256,
    parameter C_M_AXIS_TUSER_WIDTH	= 128,
    parameter C_S_AXIS_TUSER_WIDTH	= 128,
    parameter NUM_OUTPUT_QUEUES		= 8,
    parameter NUM_OUTPUT_QUEUES_WIDTH	= log2(NUM_OUTPUT_QUEUES),
    parameter LPM_LUT_DEPTH		= 32,
    parameter LPM_LUT_DEPTH_BITS 	= log2(LPM_LUT_DEPTH),
    parameter ARP_LUT_DEPTH 		= 32,
    parameter ARP_LUT_DEPTH_BITS	= log2(ARP_LUT_DEPTH),
    parameter FILTER_DEPTH		= 32,
    parameter FILTER_DEPTH_BITS		= log2(FILTER_DEPTH)
)
(
    // Global Ports
    input axis_aclk,
    input axis_resetn,

    // Master Stream Ports (interface to data path)
    output [C_M_AXIS_DATA_WIDTH - 1:0]		m_axis_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0]	m_axis_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]		m_axis_tuser,
    output m_axis_tvalid,
    input  m_axis_tready,
    output m_axis_tlast,

    // Slave Stream Ports (interface to RX queues)
    input [C_S_AXIS_DATA_WIDTH - 1:0]		s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0]	s_axis_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]		s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast,

    // --- interface to op_lut_process_sm
    output                               pkt_sent_from_cpu,              // pulsed: we've sent a pkt from the CPU
    output                               pkt_sent_to_cpu_options_ver,    // pulsed: we've sent a pkt to the CPU coz it has options/bad version
    output                               pkt_sent_to_cpu_bad_ttl,        // pulsed: sent a pkt to the CPU coz the TTL is 1 or 0
    output                               pkt_sent_to_cpu_dest_ip_hit,    // pulsed: sent a pkt to the CPU coz it has hit in the destination ip filter list
    output                               pkt_forwarded     ,             // pulsed: forwarded pkt to the destination port
    output                               pkt_dropped_checksum,           // pulsed: dropped pkt coz bad checksum
    output                               pkt_sent_to_cpu_non_ip,         // pulsed: sent pkt to cpu coz it's not IP
    output                               pkt_sent_to_cpu_arp_miss,       // pulsed: sent pkt to cpu coz we didn't find arp entry for next hop ip
    output [31:0]                       pkt_sent_to_cpu_lpm_miss,       // pulsed: sent pkt to cpu coz we didn't find lpm entry for destination ip
    output                               pkt_dropped_wrong_dst_mac,      // pulsed: dropped pkt not destined to us


/*     // --- interface to stock_id_mapping
    input [9:0]                                      stock_id_mapping_rd_addr,
    input                                            stock_id_mapping_rd_req,
    output [69:0]                                     stock_id_mapping_rd_data,
    output                                            stock_id_mapping_rd_ack,
    input [9:0]		                          stock_id_mapping_wr_addr,
    input                                            stock_id_mapping_wr_req,
    input [69:0]                                     stock_id_mapping_wr_data,
    output                                            stock_id_mapping_wr_ack,
*/
    // --- connect_signal
    input [31:0]			 cpu2ip_connect_signal_reg, 
    input [31:0]			 cpu2ip_shutdown_signal_reg,

   
    //output				fix_logout_signal, 
    output				fix_logon_trigger,
    output    				fix_logout_trigger,
    output				fix_resend_trigger,

	
    output				tcp_logout_handshake_trigger,
    output				tcp_logon_handshake_trigger,


    
    output [31:0]			resend_begin_fix_seq_num,
    output [31:0]			resend_end_fix_seq_num,

   //---- FIX LOGOUT TRIGGER
    //output reg[31:0]			 ip2cpu_fix_logout_trigger_reg,


    input [15:0]                  pkt_year,
    input [15:0]                  pkt_mon,
    input [15:0]                  pkt_day,
    input [15:0]                  pkt_hour,
    input [15:0]                  pkt_min,
    input [15:0]                  pkt_sec,
    input [15:0]                  pkt_ms,



 
    // --- eth_parser
    input [47:0]                         mac_0,    // address of rx queue 0
    input [47:0]                         mac_1,    // address of rx queue 1
    input [47:0]                         mac_2,    // address of rx queue 2
    input [47:0]                         mac_3,    // address of rx queue 3

    output [25:0]			 udp_val,

    // --- wade connect_state_machine
//    output                             connect_value,

    output                             syn_sended,
    output                             is_syn_ack,
//    output                             logon_sended,
    output                             is_ack,
    output                             ack_sended,
    output                             is_fix_logon,
    output                             is_fix_report,
    // --- wade resend seq num
    output [31:0]		   fix_resend_num_begin,
    output [31:0]		   fix_resend_num_end,
    //output                         resend_req,
    input                          resend_ack,
    
    output			   resend_mode_one,
    output			   resend_mode_two,
    output			   resend_mode_three,
    output			   is_resend,
    // --- counter wade
    output				 ol_not_empty,
  
    output			    is_connect_pkt,
    output			    is_order_pkt ,
	 


    output			    ack_value,
    output			    seq_value,
    output			    ts_val,
    output			    ecr_val, 
    input			    send_one,
    input			    is_send_pkt,
    output			    rd_preprocess_done,
//    input [216:0]                         order_index_out,
    input  [240:0]		   order_index_out,
    
// --- Reset Tables
    input [3:0]				 reset_tables

    //output 		  is_op_pkt

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

   //--------------------- Internal Parameter-------------------------


   //---------------------- Wires and regs----------------------------

   wire [NUM_OUTPUT_QUEUES_WIDTH-1:0] 	mac_dst_port_num;
   wire [31:0]                 		next_hop_ip;

   wire [NUM_OUTPUT_QUEUES-1:0]       	lpm_output_port;

   wire [47:0]                 		next_hop_mac;
   wire [NUM_OUTPUT_QUEUES-1:0]       	output_port;
   
   wire [7:0]                  		ip_new_ttl;
   wire [15:0]                 		ip_new_checksum;

   wire [NUM_OUTPUT_QUEUES-1:0]       	to_cpu_output_port;
   wire [NUM_OUTPUT_QUEUES-1:0]       	from_cpu_output_port;
   wire [NUM_OUTPUT_QUEUES_WIDTH-1:0] 	input_port_num;

   wire [C_M_AXIS_DATA_WIDTH-1:0]	in_fifo_tdata;
   wire [C_M_AXIS_TUSER_WIDTH-1:0]	in_fifo_tuser;
   wire [C_M_AXIS_DATA_WIDTH/8-1:0]	in_fifo_tkeep;
   wire					in_fifo_tlast;

   wire                        		in_fifo_nearly_full;
   wire			       		arp_done;
 


   wire					word_IP_DST_HI;
   wire					word_IP_DST_LO;
   wire				 	word_OPT_PAYLOAD;
   wire					word_OPT_PAYLOAD_2;
   wire					word_OPT_PAYLOAD_3;
   wire					word_OPT_PAYLOAD_4;
  
   // udp_checksum
   wire					udp_checksum_vld;
   wire					udp_checksum_is_good;
   wire [25:0]				udp_value;
   wire                                 ip_feed_filter_vld;
   wire 				is_ip_feed;

   wire					is_udp_pkt;


   // --- wade tcp verification
   wire                        		hand_shake_vld;
   wire                        		is_tcp_hand_shake;
   wire                        		is_tcp_ack;
   wire                        		is_tcp_fin;
   wire                        		fix_filter_vld;
   wire                        		is_fix;
   wire                        		is_report;
   wire                        		is_resend;
   wire					is_heartbeat;
   wire					is_testReq;
   wire					is_logout;
   wire					is_fix_order;
   wire [31:0]                 		ack_value;
   wire [31:0]                 		seq_value;
   wire [31:0]                 		ts_val;
   wire [31:0]                 		ecr_val;
   wire                        		receive_tcp_checksum_is_good;
   wire                        		receive_tcp_checksum_vld;

   wire					is_connect_pkt;
   wire					is_order_pkt ;
   wire					rd_preprocess_done;

   wire					is_session_reject;
   wire					is_order_cancel_reject;
   // Control signals
   assign s_axis_tready = ~in_fifo_nearly_full ;
   
   assign ol_not_empty  = !in_fifo_empty;

   //-------------------- Modules and Logic ---------------------------
   
   /* The size of this fifo has to be large enough to fit the previous modules' headers
    * and the ethernet header */
   fallthrough_small_fifo #(.WIDTH(C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8+1), .MAX_DEPTH_BITS(10))
      input_fifo
        (.din ({s_axis_tlast, s_axis_tuser, s_axis_tkeep, s_axis_tdata}),	// Data in
         .wr_en (s_axis_tvalid & ~in_fifo_nearly_full),				// Write enable
         .rd_en (in_fifo_rd_en),						// Read the next word
         .dout ({in_fifo_tlast, in_fifo_tuser, in_fifo_tkeep, in_fifo_tdata}),
         .full (),
         .prog_full (),
         .nearly_full (in_fifo_nearly_full),
         .empty (in_fifo_empty),
         .reset (~axis_resetn),
         .clk (axis_aclk)
         );

  preprocess_control
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH)
       ) preprocess_control
       ( // --- Interface to the previous stage
	 // --- Input
	  .tdata		    (s_axis_tdata),
          .valid		    (s_axis_tvalid & ~in_fifo_nearly_full),
	  .tlast		    (s_axis_tlast),

         // --- Interface to other preprocess blocks
	 // --- Output
         .word_IP_DST_HI            (word_IP_DST_HI),
         .word_IP_DST_LO            (word_IP_DST_LO),
	 .word_OPT_PAYLOAD          (word_OPT_PAYLOAD),
	 .word_OPT_PAYLOAD_2        (word_OPT_PAYLOAD_2),
	 .word_OPT_PAYLOAD_3	    (word_OPT_PAYLOAD_3),
	 .word_OPT_PAYLOAD_4	    (word_OPT_PAYLOAD_4),
         // --- Misc
	 // --- Input
         .reset                     (~axis_resetn),
         .clk                       (axis_aclk)
         );

   eth_parser
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
       .NUM_QUEUES(NUM_OUTPUT_QUEUES)
       ) eth_parser
       ( // --- Interface to the previous stage
	 // --- Input
	 .tdata			(s_axis_tdata),

         // --- Interface to process block
	 // --- Output
         //.is_arp_pkt            (is_arp_pkt), 
	 .is_udp_pkt            (is_udp_pkt),
         .is_ip_pkt             (is_ip_pkt),
         .is_for_us             (is_for_us),
         .is_broadcast          (is_broadcast),
         .mac_dst_port_num      (mac_dst_port_num),

         // --- Input
         .eth_parser_rd_info    (rd_preprocess_info),

	 // --- Output
         .eth_parser_info_vld   (eth_parser_info_vld),

         // --- Interface to preprocess block
	 // --- Input
         .word_IP_DST_HI        (word_IP_DST_HI),

         // --- Interface to registers
	 // --- Input
         .mac_0                 (mac_0),    // address of rx queue 0
         .mac_1                 (mac_1),    // address of rx queue 1
         .mac_2                 (mac_2),    // address of rx queue 2
         .mac_3                 (mac_3),    // address of rx queue 3

         // --- Misc
	 // --- Input
         .reset                 (~axis_resetn),
         .clk                   (axis_aclk)
         );



   ip_checksum
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH)
       ) ip_checksum
       ( //--- datapath interface
	 .tdata		       	    (s_axis_tdata),
         .valid		    	    (s_axis_tvalid & ~in_fifo_nearly_full),

         //--- interface to preprocess
         .word_IP_DST_HI            (word_IP_DST_HI),
         .word_IP_DST_LO            (word_IP_DST_LO),

         // --- interface to process
         .ip_checksum_vld           (ip_checksum_vld),
         .ip_checksum_is_good       (ip_checksum_is_good),
         .ip_hdr_has_options        (ip_hdr_has_options),
         //.ip_ttl_is_good            (ip_ttl_is_good),
         //.ip_new_ttl                (ip_new_ttl),
         //.ip_new_checksum           (ip_new_checksum),     // new checksum assuming decremented TTL
         .rd_checksum               (rd_preprocess_info),

         // misc
         .reset                     (~axis_resetn),
         .clk                       (axis_aclk)
         );


   op_lut_hdr_parser
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
       .C_S_AXIS_TUSER_WIDTH (C_S_AXIS_TUSER_WIDTH),
       .NUM_QUEUES(NUM_OUTPUT_QUEUES)
       ) op_lut_hdr_parser
       ( // --- Interface to the previous stage
	  .tdata		(s_axis_tdata),
          .tuser		(s_axis_tuser),
          .valid		(s_axis_tvalid & ~in_fifo_nearly_full),
	  .tlast		(s_axis_tlast),

         // --- Interface to process block
         .is_from_cpu           (is_from_cpu),
         .to_cpu_output_port    (to_cpu_output_port),
         .from_cpu_output_port  (from_cpu_output_port),
         .input_port_num        (input_port_num),
         .rd_hdr_parser         (rd_preprocess_info),
         .is_from_cpu_vld       (is_from_cpu_vld),

         // --- Misc
         .reset                 (~axis_resetn),
         .clk                   (axis_aclk)
         );


   op_lut_process_sm
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH),
       .C_S_AXIS_TUSER_WIDTH (C_S_AXIS_TUSER_WIDTH),
       .NUM_QUEUES(NUM_OUTPUT_QUEUES)
       ) op_lut_process_sm
       ( // --- interface to input fifo - fallthrough
         .in_fifo_vld                   (!in_fifo_empty),
         .in_fifo_tdata                 (in_fifo_tdata),
	 .in_fifo_tlast			(in_fifo_tlast),
	 .in_fifo_tuser			(in_fifo_tuser),
	 .in_fifo_keep			(in_fifo_tkeep),
         .in_fifo_rd_en                 (in_fifo_rd_en),

         // --- interface to eth_parser
//         .is_arp_pkt                    (is_arp_pkt),
         .is_udp_pkt                     (is_udp_pkt),
         .is_ip_pkt                     (is_ip_pkt),
         .is_for_us                     (is_for_us),
         .is_broadcast                  (is_broadcast),
         .mac_dst_port_num              (mac_dst_port_num),
         .eth_parser_info_vld           (eth_parser_info_vld),

         // --- interface to op_lut_hdr_parser
         .is_from_cpu                   (is_from_cpu),
         .to_cpu_output_port            (to_cpu_output_port),
         .from_cpu_output_port          (from_cpu_output_port),
         .is_from_cpu_vld               (is_from_cpu_vld),
         .input_port_num                (input_port_num),

         // --- interface to IP_checksum
         .ip_checksum_vld               (ip_checksum_vld),
         .ip_checksum_is_good           (ip_checksum_is_good),
         .ip_hdr_has_options            (ip_hdr_has_options),

         // -- connected to all preprocess blocks
         .rd_preprocess_info            (rd_preprocess_info),

         // --- interface to next module
         .out_tvalid                    (m_axis_tvalid),
         .out_tlast 	                (m_axis_tlast),
         .out_tdata                     (m_axis_tdata),
         .out_tuser                     (m_axis_tuser),
         .out_tready                    (m_axis_tready),
	 .out_keep			(m_axis_tkeep),

         // --- interface to registers
         .pkt_sent_from_cpu             (pkt_sent_from_cpu),              // pulsed: we've sent a pkt from the CPU
         .pkt_sent_to_cpu_options_ver   (pkt_sent_to_cpu_options_ver),    // pulsed: we've sent a pkt to the CPU coz it has options/bad version
         .pkt_sent_to_cpu_bad_ttl       (pkt_sent_to_cpu_bad_ttl),        // pulsed: sent a pkt to the CPU coz the TTL is 1 or 0
         .pkt_sent_to_cpu_dest_ip_hit   (pkt_sent_to_cpu_dest_ip_hit),    // pulsed: sent a pkt to the CPU coz it has hit in the destination ip filter list
         .pkt_forwarded                 (pkt_forwarded),             	  // pulsed: forwarded pkt to the destination port
         .pkt_dropped_checksum          (pkt_dropped_checksum),           // pulsed: dropped pkt coz bad checksum
         .pkt_sent_to_cpu_non_ip        (pkt_sent_to_cpu_non_ip),         // pulsed: sent pkt to cpu coz it's not IP
         .pkt_sent_to_cpu_arp_miss      (pkt_sent_to_cpu_arp_miss),       // pulsed: sent pkt to cpu coz no entry in arp table
         .pkt_sent_to_cpu_lpm_miss      (pkt_sent_to_cpu_lpm_miss),       // pulsed: sent pkt to cpu coz no entry in lpm table
         .pkt_dropped_wrong_dst_mac     (pkt_dropped_wrong_dst_mac),      // pulsed: dropped pkt not destined to us
         .mac_0                         (mac_0),    // address of rx queue 0
         .mac_1                         (mac_1),    // address of rx queue 1
         .mac_2                         (mac_2),    // address of rx queue 2
         .mac_3                         (mac_3),    // address of rx queue 3
	 // --- IP FEED Filter
	 .ip_feed_filter_vld        (ip_feed_filter_vld),
	 .is_ip_feed                (is_ip_feed),

	 // --- UDP checksum
	 .udp_checksum_vld          (udp_checksum_vld),
	 .udp_checksum_is_good      (udp_checksum_is_good),
	 .udp_value		    (udp_value),
	 .udp_val		    (udp_val),
	 


         // --- wade tcp verification

         .hand_shake_vld(hand_shake_vld),
         .is_tcp_hand_shake(is_tcp_hand_shake),
         .is_tcp_ack(is_tcp_ack),
         .is_tcp_fin(is_tcp_fin),
         .seq_value(seq_value),
         .ack_value(ack_value),
         .ts_value(ts_val),
         .ecr_value(ecr_val),

	 // --- FIX ORDER PARSER
         .fix_filter_vld	     (fix_filter_vld),
	 .is_fix		     (is_fix),
         .is_logon(is_logon),
         .is_report(is_report),
         .is_resend(is_resend),
	 .is_heartbeat(is_heartbeat),
	 .is_testReq (is_testReq),
	 .is_logout(is_logout),
	 .is_fix_order(is_fix_order),
         .is_session_reject(is_session_reject),
         .is_order_cancel_reject(is_order_cancel_reject),

	  // -- Connect siganl
    	 .cpu2ip_connect_signal_reg          (cpu2ip_connect_signal_reg),
	 .cpu2ip_shutdown_signal_reg         (cpu2ip_shutdown_signal_reg),


         .pkt_ms(pkt_ms),
         .pkt_sec(pkt_sec),
         .pkt_min(pkt_min),
         .pkt_hour(pkt_hour),
         .pkt_day(pkt_day),
         .pkt_mon(pkt_mon),
         .pkt_year(pkt_year),

	 .is_op_send_pkt(is_op_send_pkt),
/*
	 .is_connect_syn_pkt(is_connect_syn_pkt),
   	 .is_send_ack_pkt(is_send_ack_pkt),
   	 .is_connect_logon_pkt(is_connect_logon_pkt),
*/

         // --- wade connect state machine
         .syn_sended(syn_sended),
         .is_syn_ack(is_syn_ack),
        // .logon_sended(login_sended),
         .is_ack(is_ack),
         .ack_sended(ack_sended),
         .is_fix_logon(is_fix_logon),
         .is_fix_report(is_fix_report),

	 .fix_logon_trigger(fix_logon_trigger),
	 .fix_logout_trigger(fix_logout_trigger),
	 .fix_resend_trigger(fix_resend_trigger),
	 .tcp_logout_handshake_trigger(tcp_logout_handshake_trigger),
	 .tcp_logon_handshake_trigger (tcp_logon_handshake_trigger),

	 .is_connect_pkt(is_connect_pkt),
	 .is_order_pkt(is_order_pkt),
	 

	 .send_one(send_one),
	 .is_send_pkt(is_send_pkt),
	 .rd_preprocess_done(rd_preprocess_done),
         .order_index_out(order_index_out),
         // misc
         .reset                         (~axis_resetn),
         .clk                           (axis_aclk)
         );

   ip_feed_filter
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH)
       )
        ip_feed_filter
       ( // --- Interface to the previous stage
	  .tdata		     (s_axis_tdata),
          .tkeep		     (s_axis_tkeep),
          .valid		     (s_axis_tvalid & ~in_fifo_nearly_full),
	  .tlast               	     (s_axis_tlast),

          .word_IP_DST_HI            (word_IP_DST_HI),
          .word_IP_DST_LO            (word_IP_DST_LO),
	  .word_OPT_PAYLOAD          (word_OPT_PAYLOAD),

	  .ip_feed_filter_vld        (ip_feed_filter_vld),
	  .is_ip_feed                (is_ip_feed),
/*	  .is_udp_wire	(is_udp_wire),
	  .esccode_is_1b_wire	(esccode_is_1b_wire),
	  .is_format_six_wire	(is_format_six_wire),
	  .with_terminal_code_wire	(with_terminal_code_wire),	  
*/
	  .rd_ip_feed_filter_result  (rd_preprocess_info),
          // --- Misc
          .reset                     (~axis_resetn),
          .clk                       (axis_aclk)
         );
   udp_checksum
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH)
       )
        udp_checksum
       ( // --- Interface to the previous stage
	  .tdata		     (s_axis_tdata),
          .tkeep		     (s_axis_tkeep),
          .valid		     (s_axis_tvalid & ~in_fifo_nearly_full),
	  .tlast               	     (s_axis_tlast),

          .word_IP_DST_HI            (word_IP_DST_HI),
          .word_IP_DST_LO            (word_IP_DST_LO),

	  .udp_checksum_vld          (udp_checksum_vld),
	  .udp_checksum_is_good      (udp_checksum_is_good),
	  .udp_value		     (udp_value),
          .rd_checksum               (rd_preprocess_info),
          // --- Misc
          .reset                     (~axis_resetn),
          .clk                       (axis_aclk)
         );
   

    fix_filter
     #(.C_S_AXIS_DATA_WIDTH (C_S_AXIS_DATA_WIDTH)
       )
        fix_filter
       ( // --- Interface to the previous stage
	  .tdata		     (s_axis_tdata),
          .tkeep		     (s_axis_tkeep),
          .valid		     (s_axis_tvalid & ~in_fifo_nearly_full),
	  .tlast               	     (s_axis_tlast),

	  .rd_check  		     (rd_preprocess_info),
	  .fix_filter_vld	     (fix_filter_vld),

	  .is_fix		     (is_fix),
          .is_logon		     (is_logon),
          .is_report		     (is_report),
          .is_resend		     (is_resend),
	  .is_heartbeat		     (is_heartbeat),
	  .is_testReq		     (is_testReq),
	  .is_logout		     (is_logout),

	  .is_fix_order		     (is_fix_order),
	  .is_session_reject	     (is_session_reject),
	  .is_order_cancel_reject    (is_order_cancel_reject),

          .resend_begin		     (fix_resend_num_begin),
	  .resend_end		     (fix_resend_num_end),
	  .resend_ack		     (resend_ack),
	  .resend_mode_one	     (resend_mode_one),
	  .resend_mode_two	     (resend_mode_two),
	  .resend_mode_three         (resend_mode_three),
	  .resend_begin_fix_seq_num   (resend_begin_fix_seq_num) ,
	  .resend_end_fix_seq_num     (resend_end_fix_seq_num),

          // --- Misc
          .reset                     (~axis_resetn),
          .clk                       (axis_aclk)
         );

// remember: assert tvalid with the right output port...then wait for tready signal and send data.

    // --- wade tcp verification
    check_tcp_flag
    #(
      .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
      .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH)
     )
        check_tcp_flag(
          .tdata(s_axis_tdata),
//          .tkeep(s_axis_tkeep),
	  .tlast(s_axis_tlast),
          .tvalid(s_axis_tvalid & ~in_fifo_nearly_full),
          .tuser(s_axis_tuser),
          .word_IP_DST_HI(word_IP_DST_HI),
          .word_IP_DST_LO(word_IP_DST_LO),
          .word_OPT_PAYLOAD(word_OPT_PAYLOAD),
          .rd_check(rd_preprocess_info),

          .hand_shake_vld(hand_shake_vld),
          .is_tcp_hand_shake(is_tcp_hand_shake),
          .is_tcp_ack(is_tcp_ack),
          .is_tcp_fin(is_tcp_fin),
//        .is_fix(is_fix),
          .seq_value(seq_value),
          .ack_value(ack_value),
          .ts_val(ts_val),
          .ecr_val(ecr_val),
          // --- Misc
          .reset                     (~axis_resetn),
          .clk                       (axis_aclk)

    );





endmodule // output_port_lookup

