//-
// Copyright (C) 2010, 2011 The Board of Trustees of The Leland Stanford
//                          Junior University
// Copyright (C) 2010, 2011 Muhammad Shahbaz
// Copyright (C) 2015 Gianni Antichi, Noa Zilberman, Salvator Galea
// All rights reserved.
//
// This software was developed by
// Stanford University and the University of Cambridge Computer Laboratory
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
// as part of the DARPA MRC research programme.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regarding copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//


`include "output_port_lookup_cpu_regs_defines.v"

module router_output_port_lookup
#(
	// -- Master AXI Stream Data Width
	parameter C_M_AXIS_DATA_WIDTH	= 256,
	parameter C_S_AXIS_DATA_WIDTH	= 256,
	parameter C_M_AXIS_TUSER_WIDTH	= 128,
	parameter C_S_AXIS_TUSER_WIDTH	= 128,


	parameter C_S_AXI_DATA_WIDTH	= 32,          
	parameter C_S_AXI_ADDR_WIDTH	= 12,          
	parameter C_USE_WSTRB		= 0,
	parameter C_DPHASE_TIMEOUT	= 0,               
	parameter C_NUM_ADDRESS_RANGES	= 1,
	parameter C_TOTAL_NUM_CE	= 1,
	parameter C_S_AXI_MIN_SIZE	= 32'h0000_FFFF,
	parameter C_FAMILY		= "virtex7", 
	parameter C_BASEADDR		= 32'h00000000,
	parameter C_HIGHADDR		= 32'h0000FFFF


)
(
    // -- Global Ports
    input                                      axis_aclk,
    input                                      axis_resetn,

    // -- Master Stream Ports (interface to data path)
    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_tuser,
    output                                     m_axis_tvalid,
    input                                      m_axis_tready,
    output                                     m_axis_tlast,

    // -- Slave Stream Ports (interface to RX queues)
    input [C_S_AXIS_DATA_WIDTH - 1:0]          s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0]  s_axis_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser,
    input                                      s_axis_tvalid,
    output                                     s_axis_tready,
    input                                      s_axis_tlast,


    // -- Slave AXI Ports
    input                                     S_AXI_ACLK,
    input                                     S_AXI_ARESETN,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_AWADDR,
    input                                     S_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S_AXI_WSTRB,
    input                                     S_AXI_WVALID,
    input                                     S_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_ARADDR,
    input                                     S_AXI_ARVALID,
    input                                     S_AXI_RREADY,
    output                                    S_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_RDATA,
    output     [1 : 0]                        S_AXI_RRESP,
    output                                    S_AXI_RVALID,
    output                                    S_AXI_WREADY,
    output     [1 : 0]                        S_AXI_BRESP,
    output                                    S_AXI_BVALID,
    output                                    S_AXI_AWREADY,

    input				      input_arbiter_not_empty,
    input				      output_queue_not_empty

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

  localparam NUM_QUEUES        = 8;
  localparam NUM_QUEUES_WIDTH  = log2(NUM_QUEUES);
  localparam LPM_LUT_ROWS      = `MEM_IP_LPM_TCAM_DEPTH;
  localparam LPM_LUT_ROWS_BITS = log2(LPM_LUT_ROWS);
  localparam ARP_LUT_ROWS      = `MEM_IP_ARP_CAM_DEPTH;
  localparam ARP_LUT_ROWS_BITS = log2(ARP_LUT_ROWS);
  localparam FILTER_ROWS       = `MEM_DEST_IP_CAM_DEPTH;
  localparam FILTER_ROWS_BITS  = log2(FILTER_ROWS);


  // -- Signals
 
  wire                                            pkt_sent_from_cpu;
  wire                                            pkt_sent_to_cpu_options_ver;
  wire                                            pkt_sent_to_cpu_bad_ttl;
  wire                                            pkt_sent_to_cpu_dest_ip_hit;
  wire                                            pkt_forwarded;
  wire                                            pkt_dropped_checksum;
  wire                                            pkt_sent_to_cpu_non_ip;
  wire                                            pkt_sent_to_cpu_arp_miss;
  wire [31:0]                                            pkt_sent_to_cpu_lpm_miss;
  wire                                            pkt_dropped_wrong_dst_mac;

  wire 						  counter_low_32;
  wire						  counter_mid_32;
  wire 						  counter_high_32;

  wire						 fix_logon_trigger;
  wire   	  	        		 fix_logout_trigger;
  wire						 fix_resend_trigger;

  wire						 tcp_logout_handshake_trigger;
  wire						 tcp_logon_handshake_trigger;


  wire [31:0]					 resend_begin_fix_seq_num;
  wire [31:0]					 resend_end_fix_seq_num;


  wire [LPM_LUT_ROWS_BITS-1:0]                    lpm_rd_addr;
  wire                                            lpm_rd_req;
  wire [31:0]                                     lpm_rd_ip;
  wire [31:0]                                     lpm_rd_mask;
  wire [NUM_QUEUES-1:0]                           lpm_rd_oq;
  wire [31:0]                                     lpm_rd_next_hop_ip;
  wire                                            lpm_rd_ack;
  wire [LPM_LUT_ROWS_BITS-1:0]                    lpm_wr_addr;
  wire                                            lpm_wr_req;
  wire [NUM_QUEUES-1:0]                           lpm_wr_oq;
  wire [31:0]                                     lpm_wr_next_hop_ip;
  wire [31:0]                                     lpm_wr_ip;
  wire [31:0]                                     lpm_wr_mask;
  wire                                            lpm_wr_ack;

  wire [ARP_LUT_ROWS_BITS-1:0]                    arp_rd_addr;
  wire                                            arp_rd_req;
  wire  [47:0]                                    arp_rd_mac;
  wire  [31:0]                                    arp_rd_ip;
  wire                                            arp_rd_ack;
  wire [ARP_LUT_ROWS_BITS-1:0]                    arp_wr_addr;
  wire                                            arp_wr_req;
  wire [47:0]                                     arp_wr_mac;
  wire [31:0]                                     arp_wr_ip;
  wire                                            arp_wr_ack;

  wire [FILTER_ROWS_BITS-1:0]                     dest_ip_filter_rd_addr;
  wire                                            dest_ip_filter_rd_req;
  wire [31:0]                                     dest_ip_filter_rd_ip;
  wire                                            dest_ip_filter_rd_ack;
  wire [FILTER_ROWS_BITS-1:0]                     dest_ip_filter_wr_addr;
  wire                                            dest_ip_filter_wr_req;
  wire [31:0]                                     dest_ip_filter_wr_ip;
  wire                                            dest_ip_filter_wr_ack;

  wire [9:0]                                      stock_id_mapping_rd_addr;
  wire                                            stock_id_mapping_rd_req;
  wire [69:0]                                     stock_id_mapping_rd_data;
  wire                                            stock_id_mapping_rd_ack;
  wire [9:0]		                          stock_id_mapping_wr_addr;
  wire                                            stock_id_mapping_wr_req;
  wire [69:0]                                     stock_id_mapping_wr_data;
  wire                                            stock_id_mapping_wr_ack;

  wire [10:0]                                     warrants_id_mapping_rd_addr;
  wire                                            warrants_id_mapping_rd_req;
  wire [11:0]                                     warrants_id_mapping_rd_data;
  wire                                            warrants_id_mapping_rd_ack;
  wire [10:0]                                     warrants_id_mapping_wr_addr;
  wire                                            warrants_id_mapping_wr_req;
  wire [11:0]                                     warrants_id_mapping_wr_data;
  wire                                            warrants_id_mapping_wr_ack;
  

  wire [12:0]                                     order_id_mapping_rd_addr;
  wire                                            order_id_mapping_rd_req;
  wire [47:0]                                     order_id_mapping_rd_data;
  wire                                            order_id_mapping_rd_ack;
  wire [11:0]		                          order_id_mapping_wr_addr;
  wire                                            order_id_mapping_wr_req;
  wire [47:0]                                     order_id_mapping_wr_data;
  wire                                            order_id_mapping_wr_ack;
  

  wire [47:0]                                     mac_0;
  wire [47:0]                                     mac_1;
  wire [47:0]                                     mac_2;
  wire [47:0]                                     mac_3;
    


    reg      [`REG_ID_BITS]    					id_reg;
    reg      [`REG_VERSION_BITS]    				version_reg;
    wire     [`REG_RESET_BITS]    				reset_reg;
    reg      [`REG_FLIP_BITS]    				ip2cpu_flip_reg;
    wire     [`REG_FLIP_BITS]    				cpu2ip_flip_reg;
    reg      [`REG_DEBUG_BITS]    				ip2cpu_debug_reg;
    wire     [`REG_DEBUG_BITS]    				cpu2ip_debug_reg;
    reg      [`REG_PKT_SENT_FROM_CPU_CNTR_BITS]   		pkt_sent_from_cpu_cntr_reg;
    wire                             				pkt_sent_from_cpu_cntr_reg_clear;
    reg      [`REG_PKT_SENT_TO_CPU_OPTIONS_VER_CNTR_BITS]    	pkt_sent_to_cpu_options_ver_cntr_reg;
    wire                             				pkt_sent_to_cpu_options_ver_cntr_reg_clear;
    reg      [`REG_PKT_SENT_TO_CPU_BAD_TTL_CNTR_BITS]    	pkt_sent_to_cpu_bad_ttl_cntr_reg;
    wire                             				pkt_sent_to_cpu_bad_ttl_cntr_reg_clear;
    reg      [`REG_PKT_SENT_TO_CPU_DEST_IP_HIT_CNTR_BITS]    	pkt_sent_to_cpu_dest_ip_hit_cntr_reg;
    wire                             				pkt_sent_to_cpu_dest_ip_hit_cntr_reg_clear;
    reg      [`REG_PKT_FORWARDED_CNTR_BITS]    			pkt_forwarded_cntr_reg;
    wire                             				pkt_forwarded_cntr_reg_clear;
    reg      [`REG_PKT_DROPPED_CHECKSUM_CNTR_BITS]    		pkt_dropped_checksum_cntr_reg;
    wire                             				pkt_dropped_checksum_cntr_reg_clear;
    reg      [`REG_PKT_SENT_TO_CPU_NON_IP_CNTR_BITS]    	pkt_sent_to_cpu_non_ip_cntr_reg;
    wire                             				pkt_sent_to_cpu_non_ip_cntr_reg_clear;
    reg      [`REG_PKT_SENT_TO_CPU_ARP_MISS_CNTR_BITS]    	pkt_sent_to_cpu_arp_miss_cntr_reg;
    wire                             				pkt_sent_to_cpu_arp_miss_cntr_reg_clear;
    reg      [`REG_PKT_SENT_TO_CPU_LPM_MISS_CNTR_BITS]    	pkt_sent_to_cpu_lpm_miss_cntr_reg;
    wire                             				pkt_sent_to_cpu_lpm_miss_cntr_reg_clear;
    reg      [`REG_PKT_DROPPED_WRONG_DST_MAC_CNTR_BITS]    	pkt_dropped_wrong_dst_mac_cntr_reg;
    wire                             				pkt_dropped_wrong_dst_mac_cntr_reg_clear;
    wire     [`REG_MAC_0_HI_BITS]    				mac_0_hi_reg;
    wire     [`REG_MAC_0_LOW_BITS]    				mac_0_low_reg;
    wire     [`REG_MAC_1_HI_BITS]    				mac_1_hi_reg;
    wire     [`REG_MAC_1_LOW_BITS]    				mac_1_low_reg;
    wire     [`REG_MAC_2_HI_BITS]    				mac_2_hi_reg;
    wire     [`REG_MAC_2_LOW_BITS]    				mac_2_low_reg;
    wire     [`REG_MAC_3_HI_BITS]    				mac_3_hi_reg;
    wire     [`REG_MAC_3_LOW_BITS]    				mac_3_low_reg;
    wire     [`MEM_IP_LPM_TCAM_ADDR_BITS]    			ip_lpm_tcam_addr;
    wire     [127:0]    					ip_lpm_tcam_data;
    wire                              				ip_lpm_tcam_rd_wrn;
    wire                              				ip_lpm_tcam_cmd_valid;
    reg      [127:0]    					ip_lpm_tcam_reply;
    reg                               				ip_lpm_tcam_reply_valid;
    wire     [`MEM_IP_ARP_CAM_ADDR_BITS]    			ip_arp_cam_addr;
    wire     [127:0]    					ip_arp_cam_data;
    wire                              				ip_arp_cam_rd_wrn;
    wire                              				ip_arp_cam_cmd_valid;
    reg      [127:0]    					ip_arp_cam_reply;
    reg                               				ip_arp_cam_reply_valid;
    wire     [`MEM_DEST_IP_CAM_ADDR_BITS]    			dest_ip_cam_addr;
    wire     [127:0]    					dest_ip_cam_data;
    wire                              				dest_ip_cam_rd_wrn;
    wire                              				dest_ip_cam_cmd_valid;
    reg      [127:0]    					dest_ip_cam_reply;
    reg                               				dest_ip_cam_reply_valid;                           
    // --- connect_signal
    reg      [`REG_CONNECT_SIGNAL_BITS]    ip2cpu_connect_signal_reg;
    wire     [`REG_CONNECT_SIGNAL_BITS]    cpu2ip_connect_signal_reg;
    reg      [`REG_SHUTDOWN_SIGNAL_BITS]    ip2cpu_shutdown_signal_reg;
    wire     [`REG_SHUTDOWN_SIGNAL_BITS]    cpu2ip_shutdown_signal_reg;
/*
    reg      [`REG_FIX_LOGOUT_TRIGGER_BITS]    ip2cpu_fix_logout_trigger_reg;
    wire     [`REG_FIX_LOGOUT_TRIGGER_BITS]    cpu2ip_fix_logout_trigger_reg;
*/
    reg      [`REG_FIX_LOGON_TRIGGER_BITS]  fix_logon_trigger_reg;
    wire                                     fix_logon_trigger_reg_clear;


    reg      [`REG_FIX_LOGOUT_TRIGGER_BITS]  fix_logout_trigger_reg;
    wire  				     fix_logout_trigger_reg_clear;
    
    reg	     [`REG_FIX_LOGOUT_TRIGGER_BITS]  fix_resend_trigger_reg;
    wire				     fix_resend_trigger_reg_clear;

    reg	     [`REG_RESEND_BEGIN_FIX_SEQ_NUM_BITS] resend_begin_fix_seq_num_reg;
    wire					  resend_begin_fix_seq_num_reg_clear;


    reg      [`REG_RESEND_END_FIX_SEQ_NUM_BITS]   resend_end_fix_seq_num_reg;
    wire                                          resend_end_fix_seq_num_reg_clear;


    reg	     [`REG_TCP_LOGOUT_HANDSHAKE_TRIGGER_BITS]  tcp_logout_handshake_trigger_reg;
    wire						tcp_logout_handshake_trigger_reg_clear;

    reg	     [`REG_TCP_LOGON_HANDSHAKE_TRIGGER_BITS]   tcp_logon_handshake_trigger_reg;
    wire						tcp_logon_handshake_trigger_reg_clear;


   
   //  ---- FIX Seqence number Handle

    reg       [`REG_CURRENT_FIX_SEQ_NUM_BITS] ip2cpu_current_fix_seq_num_reg; 
    wire      [`REG_CURRENT_FIX_SEQ_NUM_BITS] cpu2ip_current_fix_seq_num_reg;

    reg       [`REG_OVERWRITE_FIX_SEQ_NUM_BITS] ip2cpu_overwrite_fix_seq_num_reg;
    wire      [`REG_OVERWRITE_FIX_SEQ_NUM_BITS] cpu2ip_overwrite_fix_seq_num_reg;

/*
    reg	      [`REG_RESEND_BEGIN_FIX_SEQ_NUM_BITS] ip2cpu_resend_begin_fix_seq_num_reg;
    wire      [`REG_RESEND_BEGIN_FIX_SEQ_NUM_BITS] cpu2ip_resend_begin_fix_seq_num_reg;


    reg       [`REG_RESEND_END_FIX_SEQ_NUM_BITS] ip2cpu_resend_end_fix_seq_num_reg;
    wire      [`REG_RESEND_END_FIX_SEQ_NUM_BITS] cpu2ip_resend_end_fix_seq_num_reg;
*/
    
   // Counter
    reg       [`REG_COUNTER_LOW_32_BITS] counter_low_32_reg;
    wire				 counter_low_32_reg_clear;

    reg	      [`REG_COUNTER_MID_32_BITS] counter_mid_32_reg;
    wire  				 counter_mid_32_reg_clear;

    reg	      [`REG_COUNTER_HIGH_32_BITS] counter_high_32_reg;
    wire				  counter_high_32_reg_clear;

    // --- hw_clock
    reg      [`REG_KERNEL_TIME_MS_BITS]    ip2cpu_kernel_time_ms_reg;
    wire     [`REG_KERNEL_TIME_MS_BITS]    cpu2ip_kernel_time_ms_reg;
    reg      [`REG_KERNEL_TIME_S_BITS]    ip2cpu_kernel_time_s_reg;
    wire     [`REG_KERNEL_TIME_S_BITS]    cpu2ip_kernel_time_s_reg;
    reg      [`REG_KERNEL_TIME_MIN_BITS]    ip2cpu_kernel_time_min_reg;
    wire     [`REG_KERNEL_TIME_MIN_BITS]    cpu2ip_kernel_time_min_reg;
    reg      [`REG_KERNEL_TIME_HOUR_BITS]    ip2cpu_kernel_time_hour_reg;
    wire     [`REG_KERNEL_TIME_HOUR_BITS]    cpu2ip_kernel_time_hour_reg;
    reg      [`REG_KERNEL_TIME_DAY_BITS]    ip2cpu_kernel_time_day_reg;
    wire     [`REG_KERNEL_TIME_DAY_BITS]    cpu2ip_kernel_time_day_reg;
    reg      [`REG_KERNEL_TIME_MON_BITS]    ip2cpu_kernel_time_mon_reg;
    wire     [`REG_KERNEL_TIME_MON_BITS]    cpu2ip_kernel_time_mon_reg;
    reg      [`REG_KERNEL_TIME_YEAR_BITS]    ip2cpu_kernel_time_year_reg;
    wire     [`REG_KERNEL_TIME_YEAR_BITS]    cpu2ip_kernel_time_year_reg;
    wire  [15:0]                     pkt_year;
    wire  [15:0]                     pkt_mon;
    wire  [15:0]                     pkt_day;
    wire  [15:0]                     pkt_hour;
    wire  [15:0]                     pkt_min;
    wire  [15:0]                     pkt_sec;
    wire  [15:0]                     pkt_ms;
    

    // --- strategy table
    wire      [`MEM_STOCK_ID_MAPPING_ADDR_BITS]    stock_id_mapping_addr;
    wire      [`MEM_STOCK_ID_MAPPING_DATA_BITS]    stock_id_mapping_data;
    wire                              stock_id_mapping_rd_wrn;
    wire                              stock_id_mapping_cmd_valid;
    reg       [`MEM_STOCK_ID_MAPPING_DATA_BITS]    stock_id_mapping_reply;
    reg                               stock_id_mapping_reply_valid;
   
    // --- warrants table
    wire      [`MEM_WARRANTS_ID_MAPPING_ADDR_BITS]    warrants_id_mapping_addr;
    wire      [`MEM_WARRANTS_ID_MAPPING_DATA_BITS]    warrants_id_mapping_data;
    wire                              warrants_id_mapping_rd_wrn;
    wire                              warrants_id_mapping_cmd_valid;
    reg       [`MEM_WARRANTS_ID_MAPPING_DATA_BITS]    warrants_id_mapping_reply;
    reg                               warrants_id_mapping_reply_valid;


 
    // --- order table
    wire      [`MEM_ORDER_ID_MAPPING_ADDR_BITS]    order_id_mapping_addr;
    wire      [`MEM_ORDER_ID_MAPPING_DATA_BITS]    order_id_mapping_data;
    wire                              order_id_mapping_rd_wrn;
    wire                              order_id_mapping_cmd_valid;
    reg       [`MEM_ORDER_ID_MAPPING_DATA_BITS]    order_id_mapping_reply;
    reg                               order_id_mapping_reply_valid;

    wire 							clear_counters;
    wire 							reset_registers;
    wire     [3:0]						reset_tables;

    wire [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_tdata_op;
    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep_op;
    wire [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_tuser_op;
    wire                                     m_axis_tvalid_op;
    wire                                      m_axis_tready_op;
    wire                                     m_axis_tlast_op;

    wire  [25:0]			udp_val;

    // --- counter wade
    wire				ol_not_empty;
    wire				og_not_empty;
    reg [95:0]				process_count;


   // --- wade connect_state_machine
   wire                        connect_signal;
   wire                        syn_sended;
   wire                        is_syn_ack;
   wire                        logon_sended;
   wire                        is_ack;
   wire                        ack_sended;
   wire                        is_fix_logon;
   wire                        is_fix_report;
   wire                        order_sended;


  // Tcp option 
   wire [31:0]                          ack_value;
   wire [31:0]                          seq_value;
   wire [31:0]                          ts_val;
   wire [31:0]                          ecr_val;
 


   // --- wade resend seq num

//   wire [31:0]                 resend_num;
   wire                        resend_req;
   wire                        resend_ack;

   wire 			resend_mode_one;
   wire				resend_mode_two;
   wire				resend_mode_three;


   wire				is_resend;
   wire				is_connect_pkt;
   wire				is_order_pkt;
//   wire [31:0]                 fix_server_seq;

/*
   wire [31:0]		fix_resend_num_begin;
   wire [31:0]		fix_resend_num_end;
*/
  // ----yifang counter
   wire	[31:0]	is_op_pkt_counter;
   wire [31:0]	is_og_pkt_counter;

   wire	        send_one;
   wire	        is_send_pkt ;
   wire		rd_preprocess_done;

//   wire [216:0]                         order_index_out;    
   wire	 [240:0]			order_index_out;

 
   assign mac_0	=	{mac_0_hi_reg[15:0],mac_0_low_reg};
   assign mac_1	=	{mac_1_hi_reg[15:0],mac_1_low_reg};
   assign mac_2	=	{mac_2_hi_reg[15:0],mac_2_low_reg};
   assign mac_3	=	{mac_3_hi_reg[15:0],mac_3_low_reg};

   // -- Read signals for stock_id_mapping
   assign stock_id_mapping_rd_req	=	stock_id_mapping_cmd_valid & stock_id_mapping_rd_wrn;
//   assign stock_id_mapping_rd_addr	=	stock_id_mapping_rd_req ? stock_id_mapping_addr : 9'b0;
   assign stock_id_mapping_rd_addr	=	stock_id_mapping_addr;
   // -- Write signals for stock_id_mapping
   assign stock_id_mapping_wr_req 	=	stock_id_mapping_cmd_valid & ~stock_id_mapping_rd_wrn;
//   assign stock_id_mapping_wr_addr  	=	stock_id_mapping_wr_req ? stock_id_mapping_addr 	: 9'b0;
   assign stock_id_mapping_wr_addr  	=	stock_id_mapping_addr;
   //assign stock_id_mapping_wr_data   	=       stock_id_mapping_wr_req ? stock_id_mapping_data 	: 70'b0;
   assign stock_id_mapping_wr_data   	=       stock_id_mapping_data;
   


   // -- Read signals for warrants_id_mapping
   assign warrants_id_mapping_rd_req    =       warrants_id_mapping_cmd_valid & warrants_id_mapping_rd_wrn;
   assign warrants_id_mapping_rd_addr   =       warrants_id_mapping_addr;
   assign warrants_id_mapping_wr_req    =       warrants_id_mapping_cmd_valid & ~warrants_id_mapping_rd_wrn;
   assign warrants_id_mapping_wr_addr   =       warrants_id_mapping_addr;
   assign warrants_id_mapping_wr_data           =       warrants_id_mapping_data;
   // -- Read signals for order_id_mapping
   assign order_id_mapping_rd_req	=	order_id_mapping_cmd_valid & order_id_mapping_rd_wrn;
   assign order_id_mapping_rd_addr	=	order_id_mapping_addr;
   assign order_id_mapping_wr_req 	=	order_id_mapping_cmd_valid & ~order_id_mapping_rd_wrn;
   assign order_id_mapping_wr_addr  	=	order_id_mapping_addr;
   assign order_id_mapping_wr_data   	=       order_id_mapping_data;

// -- Read signals for ip_lpm_tcam, ip_arp_cam, dest_ip_cam
  always @(posedge axis_aclk)  begin
	if (~resetn_sync) begin
	  	stock_id_mapping_reply		<=	70'b0;
	  	stock_id_mapping_reply_valid	<=	1'b0;
		warrants_id_mapping_reply      <= 12'b0;
		warrants_id_mapping_reply_valid <= 1'b0;
	  	order_id_mapping_reply		<=	48'b0;
	  	order_id_mapping_reply_valid	<=	1'b0;
	  	dest_ip_cam_reply		<=	128'b0;
	  	dest_ip_cam_reply_valid		<=	1'b0;
		ip_arp_cam_reply		<=	128'b0;
		ip_arp_cam_reply_valid		<=	1'b0;
		ip_lpm_tcam_reply		<=	128'b0;
		ip_lpm_tcam_reply_valid		<=	1'b0;
	end
	else begin
	  	stock_id_mapping_reply		<=	stock_id_mapping_rd_ack ? stock_id_mapping_rd_data : stock_id_mapping_reply;
	  	stock_id_mapping_reply_valid	<=	stock_id_mapping_rd_ack ? 1'b1 : 1'b0;
                warrants_id_mapping_reply      <=      warrants_id_mapping_rd_ack ? warrants_id_mapping_rd_data : warrants_id_mapping_reply;
                warrants_id_mapping_reply_valid      <=      warrants_id_mapping_rd_ack ? 1'b1 : 1'b0;
		order_id_mapping_reply      <=      order_id_mapping_rd_ack ? order_id_mapping_rd_data : order_id_mapping_reply;
		order_id_mapping_reply_valid      <=      order_id_mapping_rd_ack ? 1'b1 : 1'b0;
		dest_ip_cam_reply	<= dest_ip_filter_rd_ack ? {{96{1'b0}},dest_ip_filter_rd_ip} : dest_ip_cam_reply;
  		dest_ip_cam_reply_valid	<= dest_ip_filter_rd_ack ? 1'b1 : 1'b0;
		ip_arp_cam_reply 	<= arp_rd_ack ? {{16{1'b0}},arp_rd_mac,{32{1'b0}},arp_rd_ip} : ip_arp_cam_reply;
		ip_arp_cam_reply_valid	<= arp_rd_ack ? 1'b1 : 1'b0;
		ip_lpm_tcam_reply	<= lpm_rd_ack ? {lpm_rd_ip,lpm_rd_next_hop_ip,lpm_rd_mask,{24{1'b0}},lpm_rd_oq} : ip_lpm_tcam_reply;
		ip_lpm_tcam_reply_valid <= lpm_rd_ack ? 1'b1 : 1'b0;
	end
  end

  

  // -- Router
  ip_feed_fix_parser #
  (
    .C_M_AXIS_DATA_WIDTH  (C_M_AXIS_DATA_WIDTH),
    .C_S_AXIS_DATA_WIDTH  (C_S_AXIS_DATA_WIDTH),
    .C_M_AXIS_TUSER_WIDTH (C_M_AXIS_TUSER_WIDTH),
    .C_S_AXIS_TUSER_WIDTH (C_S_AXIS_TUSER_WIDTH),
    .NUM_OUTPUT_QUEUES    (NUM_QUEUES),
    .LPM_LUT_DEPTH        (LPM_LUT_ROWS),
    .ARP_LUT_DEPTH        (ARP_LUT_ROWS),
    .FILTER_DEPTH         (FILTER_ROWS)
   )
  ip_feed_fix_parser
  (
    // -- Global Ports
    .axis_aclk      (axis_aclk),
    .axis_resetn    (axis_resetn),

    // -- Master Stream Ports (interface to data path)
/*
    .m_axis_tdata  (m_axis_tdata),
    .m_axis_tkeep  (m_axis_tkeep),
    .m_axis_tuser  (m_axis_tuser),
    .m_axis_tvalid (m_axis_tvalid), 
    .m_axis_tready (m_axis_tready),
    .m_axis_tlast  (m_axis_tlast),
*/

    .m_axis_tdata  (m_axis_tdata_op),
    .m_axis_tkeep  (m_axis_tkeep_op),
    .m_axis_tuser  (m_axis_tuser_op),
    .m_axis_tvalid (m_axis_tvalid_op), 
    .m_axis_tready (m_axis_tready_op),
    .m_axis_tlast  (m_axis_tlast_op),


    // -- Slave Stream Ports (interface to RX queues)

    .s_axis_tdata  (s_axis_tdata),
    .s_axis_tkeep  (s_axis_tkeep),
    .s_axis_tuser  (s_axis_tuser),
    .s_axis_tvalid (s_axis_tvalid),
    .s_axis_tready (s_axis_tready),
    .s_axis_tlast  (s_axis_tlast),

    // -- Interface to op_lut_process_sm
    .pkt_sent_from_cpu            (pkt_sent_from_cpu),
    .pkt_sent_to_cpu_options_ver  (pkt_sent_to_cpu_options_ver), 
    .pkt_sent_to_cpu_bad_ttl      (pkt_sent_to_cpu_bad_ttl),     
    .pkt_sent_to_cpu_dest_ip_hit  (pkt_sent_to_cpu_dest_ip_hit), 
    .pkt_forwarded                (pkt_forwarded),          
    .pkt_dropped_checksum         (pkt_dropped_checksum),        
    .pkt_sent_to_cpu_non_ip       (pkt_sent_to_cpu_non_ip),      
    .pkt_sent_to_cpu_arp_miss     (pkt_sent_to_cpu_arp_miss),    
    .pkt_sent_to_cpu_lpm_miss     (pkt_sent_to_cpu_lpm_miss),    
    .pkt_dropped_wrong_dst_mac    (pkt_dropped_wrong_dst_mac),


    // -- Interface to stock_id_mapping
    // -- Connect siganl
    .cpu2ip_connect_signal_reg          (cpu2ip_connect_signal_reg),
    .cpu2ip_shutdown_signal_reg		(cpu2ip_shutdown_signal_reg),
    //.fix_logout_signal			(fix_logout_signal),
    .fix_logon_trigger			(fix_logon_trigger),
    .fix_logout_trigger			(fix_logout_trigger),
    .fix_resend_trigger			(fix_resend_trigger),
    
    .tcp_logout_handshake_trigger	(tcp_logout_handshake_trigger),
    .tcp_logon_handshake_trigger	(tcp_logon_handshake_trigger),

    .resend_begin_fix_seq_num		(resend_begin_fix_seq_num),
    .resend_end_fix_seq_num		(resend_end_fix_seq_num),

    // --FIX LOGOUT TRIGGER signal
 //    .ip2cpu_fix_logout_trigger_reg     (ip2cpu_fix_logout_trigger_reg),
    




    // time
    .pkt_ms(pkt_ms),
    .pkt_sec(pkt_sec),
    .pkt_min(pkt_min),
    .pkt_hour(pkt_hour),
    .pkt_day(pkt_day),
    .pkt_mon(pkt_mon),
    .pkt_year(pkt_year),



    // -- Interface to eth_parser
    .mac_0                        (mac_0),
    .mac_1                        (mac_1),
    .mac_2                        (mac_2),
    .mac_3                        (mac_3),

    .udp_val			  (udp_val),

     // --- wade connect state machine
//     .connect_value(connect_signal),

     .syn_sended(syn_sended),
     .is_syn_ack(is_syn_ack),
     //.logon_sended(login_sended),
     .is_ack(is_ack),
     .ack_sended(ack_sended),
     .is_fix_logon(is_fix_logon),
     .is_fix_report(is_fix_report),

     // --- wade resend seq num
     //.resend_num(resend_num),
/*
     .fix_resend_num_begin(fix_resend_num_begin),
     .fix_resend_num_end(fix_resend_num_end),
*/
     //.resend_req(resend_req),
     .resend_ack(resend_ack),

     .resend_mode_one(resend_mode_one),
     .resend_mode_two(resend_mode_two),
     .resend_mode_three(resend_mode_three),
     .is_resend(is_resend),
     //.recv_fix_server_seq(fix_server_seq),

     .is_connect_pkt(is_connect_pkt),
     .is_order_pkt(is_order_pkt), 
    .ol_not_empty		  (ol_not_empty),
    // --- Reset to Register Tables ( {dest_ip_cam,ip_arp_cam,ip_lpm_tcam,-} )
    .ack_value	(ack_value),
    .seq_value	(seq_value),
    .ts_val 	(ts_val),
    .ecr_val	(ecr_val),

    .is_send_pkt (is_send_pkt),
    .rd_preprocess_done(rd_preprocess_done),
    .order_index_out(order_index_out),
    .reset_tables		  (reset_tables)
    //.op_pkt_counter		  (op_pkt_counter)
  );

  fix_generator #
  (
    .C_M_AXIS_DATA_WIDTH  (C_M_AXIS_DATA_WIDTH),
    .C_S_AXIS_DATA_WIDTH  (C_S_AXIS_DATA_WIDTH),
    .C_M_AXIS_TUSER_WIDTH (C_M_AXIS_TUSER_WIDTH),
    .C_S_AXIS_TUSER_WIDTH (C_S_AXIS_TUSER_WIDTH),
    .NUM_OUTPUT_QUEUES    (NUM_QUEUES),
    .LPM_LUT_DEPTH        (LPM_LUT_ROWS),
    .ARP_LUT_DEPTH        (ARP_LUT_ROWS),
    .FILTER_DEPTH         (FILTER_ROWS)
   ) 
     fix_generator
  (
    // -- Global Ports
    .axis_aclk      (axis_aclk),
    .axis_resetn    (axis_resetn),

    // -- Master Stream Ports (interface to data path)
    .m_axis_tdata  (m_axis_tdata),
    .m_axis_tkeep  (m_axis_tkeep),
    .m_axis_tuser  (m_axis_tuser),
    .m_axis_tvalid (m_axis_tvalid), 
    .m_axis_tready (m_axis_tready),
    .m_axis_tlast  (m_axis_tlast),

    // -- Slave Stream Ports (interface to RX queues)
    .s_axis_tdata  (m_axis_tdata_op),
    .s_axis_tkeep  (m_axis_tkeep_op),
    .s_axis_tuser  (m_axis_tuser_op),
    .s_axis_tvalid (m_axis_tvalid_op),
    .s_axis_tready (m_axis_tready_op),
    .s_axis_tlast  (m_axis_tlast_op),


    // -- Interface to stock_id_mapping
    .stock_id_mapping_rd_addr       (stock_id_mapping_rd_addr),  
    .stock_id_mapping_rd_req        (stock_id_mapping_rd_req),   
    .stock_id_mapping_rd_data         (stock_id_mapping_rd_data),    
    .stock_id_mapping_rd_ack        (stock_id_mapping_rd_ack),   
    .stock_id_mapping_wr_addr       (stock_id_mapping_wr_addr),  
    .stock_id_mapping_wr_req        (stock_id_mapping_wr_req),   
    .stock_id_mapping_wr_data         (stock_id_mapping_wr_data),    
    .stock_id_mapping_wr_ack        (stock_id_mapping_wr_ack),   

    // -- Interface to warrant_id_mapping
    .warrants_id_mapping_rd_addr       (warrants_id_mapping_rd_addr),
    .warrants_id_mapping_rd_req        (warrants_id_mapping_rd_req),
    .warrants_id_mapping_rd_data       (warrants_id_mapping_rd_data),
    .warrants_id_mapping_rd_ack        (warrants_id_mapping_rd_ack),
    .warrants_id_mapping_wr_addr       (warrants_id_mapping_wr_addr),
    .warrants_id_mapping_wr_req        (warrants_id_mapping_wr_req),
    .warrants_id_mapping_wr_data       (warrants_id_mapping_wr_data),
    .warrants_id_mapping_wr_ack        (warrants_id_mapping_wr_ack),

    // -- Interface to order_id_mapping
    .order_id_mapping_rd_addr       (order_id_mapping_rd_addr),  
    .order_id_mapping_rd_req        (order_id_mapping_rd_req),   
    .order_id_mapping_rd_data       (order_id_mapping_rd_data),    
    .order_id_mapping_rd_ack        (order_id_mapping_rd_ack),   
    .order_id_mapping_wr_addr       (order_id_mapping_wr_addr),  
    .order_id_mapping_wr_req        (order_id_mapping_wr_req),   
    .order_id_mapping_wr_data       (order_id_mapping_wr_data),    
    .order_id_mapping_wr_ack        (order_id_mapping_wr_ack),   

    .pkt_ms(pkt_ms),
    .pkt_sec(pkt_sec),
    .pkt_min(pkt_min),
    .pkt_hour(pkt_hour),
    .pkt_day(pkt_day),
    .pkt_mon(pkt_mon),
    .pkt_year(pkt_year),
   
    
     // ---FIX Connection
    
 
     .syn_sended(syn_sended),
     .is_syn_ack(is_syn_ack),
    // .logon_sended(login_sended),
     .is_ack(is_ack),
     .ack_sended(ack_sended),
     .is_fix_logon(is_fix_logon),
     .is_fix_report(is_fix_report),
     .fix_resend_num_begin(resend_begin_fix_seq_num),
     .fix_resend_num_end(resend_end_fix_seq_num),
     //.resend_req(resend_req),
     .resend_ack(resend_ack),

     .resend_mode_one(resend_mode_one),
     .resend_mode_two(resend_mode_two),
     .resend_mode_three(resend_mode_three),
     .is_resend(is_resend),

     .cpu2ip_overwrite_fix_seq_num_reg(cpu2ip_overwrite_fix_seq_num_reg),
 
    .og_not_empty		  (og_not_empty),

    //TCP_option
    .ack_value(ack_value),
    .seq_value(seq_value),
    .ts_val(ts_val),
    .ecr_val(ecr_val),

    .is_send_pkt(is_send_pkt),
    .rd_preprocess_done(rd_preprocess_done),
   
    .order_index_out(order_index_out),

    // --- Reset to Register Tables ( {dest_ip_cam,ip_arp_cam,ip_lpm_tcam,-} )
    .reset_tables		  (reset_tables)

  );


/*
 fix_counter #
  (
    .C_S_AXIS_DATA_WIDTH  (C_S_AXIS_DATA_WIDTH)
   ) fix_counter
  (
    // -- Global Ports
    .op_pkt_counter(is_op_pkt_counter),
    .og_pkt_counter(is_og_pkt_counter),
    .aclk      (axis_aclk),
    .reset     (axis_resetn),

   ) 


 fix_seq_number #
  (
    .C_S_AXIS_DATA_WIDTH  (C_S_AXIS_DATA_WIDTH)
   ) fix_counter
  (
    // -- Global Ports
    .op_pkt_counter(is_op_pkt_counter),
    .og_pkt_counter(is_og_pkt_counter),
    .aclk      (axis_aclk),
    .reset     (axis_resetn),
    .recv_fix_server_seq(recv_fix_server_seq)

   )

*/


 // --- Registers section
 output_port_lookup_cpu_regs 
 #(
   .C_S_AXI_DATA_WIDTH (C_S_AXI_DATA_WIDTH),
   .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH),
   .C_BASE_ADDRESS    (C_BASEADDR)
 ) opl_cpu_regs_inst
 (   
    // General ports
    .clk                    (axis_aclk),
    .resetn                 (axis_resetn),
    // AXI Lite ports
    .S_AXI_ACLK             (S_AXI_ACLK),
    .S_AXI_ARESETN          (S_AXI_ARESETN),
    .S_AXI_AWADDR           (S_AXI_AWADDR),
    .S_AXI_AWVALID          (S_AXI_AWVALID),
    .S_AXI_WDATA            (S_AXI_WDATA),
    .S_AXI_WSTRB            (S_AXI_WSTRB),
    .S_AXI_WVALID           (S_AXI_WVALID),
    .S_AXI_BREADY           (S_AXI_BREADY),
    .S_AXI_ARADDR           (S_AXI_ARADDR),
    .S_AXI_ARVALID          (S_AXI_ARVALID),
    .S_AXI_RREADY           (S_AXI_RREADY),
    .S_AXI_ARREADY          (S_AXI_ARREADY),
    .S_AXI_RDATA            (S_AXI_RDATA),
    .S_AXI_RRESP            (S_AXI_RRESP),
    .S_AXI_RVALID           (S_AXI_RVALID),
    .S_AXI_WREADY           (S_AXI_WREADY),
    .S_AXI_BRESP            (S_AXI_BRESP),
    .S_AXI_BVALID           (S_AXI_BVALID),
    .S_AXI_AWREADY          (S_AXI_AWREADY),

    // Register ports
   .id_reg          				(id_reg),
   .version_reg          			(version_reg),
   .reset_reg          				(reset_reg),
   .ip2cpu_flip_reg          			(ip2cpu_flip_reg),
   .cpu2ip_flip_reg          			(cpu2ip_flip_reg),
   .ip2cpu_debug_reg          			(ip2cpu_debug_reg),
   .cpu2ip_debug_reg          			(cpu2ip_debug_reg),
   .pkt_sent_from_cpu_cntr_reg          	(pkt_sent_from_cpu_cntr_reg),
   .pkt_sent_from_cpu_cntr_reg_clear    	(pkt_sent_from_cpu_cntr_reg_clear),
   .pkt_sent_to_cpu_options_ver_cntr_reg        (pkt_sent_to_cpu_options_ver_cntr_reg),
   .pkt_sent_to_cpu_options_ver_cntr_reg_clear  (pkt_sent_to_cpu_options_ver_cntr_reg_clear),
   .pkt_sent_to_cpu_bad_ttl_cntr_reg          	(pkt_sent_to_cpu_bad_ttl_cntr_reg),
   .pkt_sent_to_cpu_bad_ttl_cntr_reg_clear    	(pkt_sent_to_cpu_bad_ttl_cntr_reg_clear),
   .pkt_sent_to_cpu_dest_ip_hit_cntr_reg        (pkt_sent_to_cpu_dest_ip_hit_cntr_reg),
   .pkt_sent_to_cpu_dest_ip_hit_cntr_reg_clear  (pkt_sent_to_cpu_dest_ip_hit_cntr_reg_clear),
   .pkt_forwarded_cntr_reg         		(pkt_forwarded_cntr_reg),
   .pkt_forwarded_cntr_reg_clear    		(pkt_forwarded_cntr_reg_clear),
   .pkt_dropped_checksum_cntr_reg          	(pkt_dropped_checksum_cntr_reg),
   .pkt_dropped_checksum_cntr_reg_clear    	(pkt_dropped_checksum_cntr_reg_clear),
   .pkt_sent_to_cpu_non_ip_cntr_reg          	(pkt_sent_to_cpu_non_ip_cntr_reg),
   .pkt_sent_to_cpu_non_ip_cntr_reg_clear    	(pkt_sent_to_cpu_non_ip_cntr_reg_clear),
   .pkt_sent_to_cpu_arp_miss_cntr_reg           (pkt_sent_to_cpu_arp_miss_cntr_reg),
   .pkt_sent_to_cpu_arp_miss_cntr_reg_clear     (pkt_sent_to_cpu_arp_miss_cntr_reg_clear),
   .pkt_sent_to_cpu_lpm_miss_cntr_reg           (pkt_sent_to_cpu_lpm_miss_cntr_reg),
   .pkt_sent_to_cpu_lpm_miss_cntr_reg_clear     (pkt_sent_to_cpu_lpm_miss_cntr_reg_clear),
   .pkt_dropped_wrong_dst_mac_cntr_reg          (pkt_dropped_wrong_dst_mac_cntr_reg),
   .pkt_dropped_wrong_dst_mac_cntr_reg_clear    (pkt_dropped_wrong_dst_mac_cntr_reg_clear),
   .mac_0_hi_reg          			(mac_0_hi_reg),
   .mac_0_low_reg          			(mac_0_low_reg),
   .mac_1_hi_reg          			(mac_1_hi_reg),
   .mac_1_low_reg          			(mac_1_low_reg),
   .mac_2_hi_reg          			(mac_2_hi_reg),
   .mac_2_low_reg          			(mac_2_low_reg),
   .mac_3_hi_reg          			(mac_3_hi_reg),
   .mac_3_low_reg          			(mac_3_low_reg),
    // -- Register Table ports
   .ip_lpm_tcam_addr          			(ip_lpm_tcam_addr),
   .ip_lpm_tcam_data          			(ip_lpm_tcam_data),
   .ip_lpm_tcam_rd_wrn        			(ip_lpm_tcam_rd_wrn),
   .ip_lpm_tcam_cmd_valid     			(ip_lpm_tcam_cmd_valid),
   .ip_lpm_tcam_reply         			(ip_lpm_tcam_reply),
   .ip_lpm_tcam_reply_valid   			(ip_lpm_tcam_reply_valid),
   .ip_arp_cam_addr           			(ip_arp_cam_addr),
   .ip_arp_cam_data           			(ip_arp_cam_data),
   .ip_arp_cam_rd_wrn         			(ip_arp_cam_rd_wrn),
   .ip_arp_cam_cmd_valid      			(ip_arp_cam_cmd_valid),
   .ip_arp_cam_reply          			(ip_arp_cam_reply),
   .ip_arp_cam_reply_valid    			(ip_arp_cam_reply_valid),
   .dest_ip_cam_addr          			(dest_ip_cam_addr),
   .dest_ip_cam_data          			(dest_ip_cam_data),
   .dest_ip_cam_rd_wrn        			(dest_ip_cam_rd_wrn),
   .dest_ip_cam_cmd_valid     			(dest_ip_cam_cmd_valid),
   .dest_ip_cam_reply         			(dest_ip_cam_reply),
   .dest_ip_cam_reply_valid   			(dest_ip_cam_reply_valid),


   //----Counter
   .counter_low_32_reg          (counter_low_32_reg),
   .counter_low_32_reg_clear    (counter_low_32_reg_clear),
   .counter_mid_32_reg          (counter_mid_32_reg),
   .counter_mid_32_reg_clear    (counter_mid_32_reg_clear),
   .counter_high_32_reg          (counter_high_32_reg),
   .counter_high_32_reg_clear    (counter_high_32_reg_clear), 



  // --- connect_signal
   .ip2cpu_connect_signal_reg          (ip2cpu_connect_signal_reg),
   .cpu2ip_connect_signal_reg          (cpu2ip_connect_signal_reg),
   .ip2cpu_shutdown_signal_reg         (ip2cpu_shutdown_signal_reg),
   .cpu2ip_shutdown_signal_reg         (cpu2ip_shutdown_signal_reg),
   /*
   .ip2cpu_fix_logout_trigger_reg      (ip2cpu_fix_logout_trigger_reg),
   .cpu2ip_fix_logout_trigger_reg      (cpu2ip_fix_logout_trigger_reg),
   */
   .fix_logon_trigger_reg	       (fix_logon_trigger_reg),
   .fix_logon_trigger_reg_clear	       (fix_logon_trigger_reg_clear),	
   .fix_logout_trigger_reg	       (fix_logout_trigger_reg),
   .fix_logout_trigger_reg_clear       (fix_logout_trigger_reg_clear),
   
   .fix_resend_trigger_reg		(fix_resend_trigger_reg),
   .fix_resend_trigger_reg_clear	(fix_resend_trigger_reg_clear),

   .tcp_logout_handshake_trigger_reg    (tcp_logout_handshake_trigger_reg),
   .tcp_logout_handshake_trigger_reg_clear   (tcp_logout_handshake_trigger_reg_clear),

   .tcp_logon_handshake_trigger_reg     (tcp_logon_handshake_trigger_reg),
   .tcp_logon_handshake_trigger_reg_clear(tcp_logon_handshake_trigger_reg_clear),



   .resend_begin_fix_seq_num_reg	(resend_begin_fix_seq_num_reg),
   .resend_begin_fix_seq_num_reg_clear      (resend_begin_fix_seq_num_reg_clear),

   .resend_end_fix_seq_num_reg	        (resend_end_fix_seq_num_reg),
   .resend_end_fix_seq_num_reg_clear        (resend_end_fix_seq_num_reg_clear),

   //.fix_logout_signal 		       (fix_logout_signal),


  // --- FIX Seqence number control

   .ip2cpu_current_fix_seq_num_reg     (ip2cpu_current_fix_seq_num_reg),
   .cpu2ip_current_fix_seq_num_reg     (cpu2ip_current_fix_seq_num_reg),

   .ip2cpu_overwrite_fix_seq_num_reg   (ip2cpu_overwrite_fix_seq_num_reg),
   .cpu2ip_overwrite_fix_seq_num_reg   (cpu2ip_overwrite_fix_seq_num_reg),


/*
   .ip2cpu_resend_begin_fix_seq_num_reg(ip2cpu_resend_begin_fix_seq_num_reg),
   .cpu2ip_resend_begin_fix_seq_num_reg(cpu2ip_resend_begin_fix_seq_num_reg),

   .ip2cpu_resend_end_fix_seq_num_reg  (ip2cpu_resend_end_fix_seq_num_reg),
   .cpu2ip_resend_end_fix_seq_num_reg  (cpu2ip_resend_end_fix_seq_num_reg),
*/    

   // --- hw_clock
   .ip2cpu_kernel_time_ms_reg          (ip2cpu_kernel_time_ms_reg),
   .cpu2ip_kernel_time_ms_reg          (cpu2ip_kernel_time_ms_reg),
   .ip2cpu_kernel_time_s_reg          (ip2cpu_kernel_time_s_reg),
   .cpu2ip_kernel_time_s_reg          (cpu2ip_kernel_time_s_reg),
   .ip2cpu_kernel_time_min_reg          (ip2cpu_kernel_time_min_reg),
   .cpu2ip_kernel_time_min_reg          (cpu2ip_kernel_time_min_reg),
   .ip2cpu_kernel_time_hour_reg          (ip2cpu_kernel_time_hour_reg),
   .cpu2ip_kernel_time_hour_reg          (cpu2ip_kernel_time_hour_reg),
   .ip2cpu_kernel_time_day_reg          (ip2cpu_kernel_time_day_reg),
   .cpu2ip_kernel_time_day_reg          (cpu2ip_kernel_time_day_reg),
   .ip2cpu_kernel_time_mon_reg          (ip2cpu_kernel_time_mon_reg),
   .cpu2ip_kernel_time_mon_reg          (cpu2ip_kernel_time_mon_reg),
   .ip2cpu_kernel_time_year_reg          (ip2cpu_kernel_time_year_reg),
   .cpu2ip_kernel_time_year_reg          (cpu2ip_kernel_time_year_reg),
   .pkt_ms(pkt_ms),
   .pkt_sec(pkt_sec),
   .pkt_min(pkt_min),
   .pkt_hour(pkt_hour),
   .pkt_day(pkt_day),
   .pkt_mon(pkt_mon),
   .pkt_year(pkt_year),

   .stock_id_mapping_addr          (stock_id_mapping_addr),
   .stock_id_mapping_data          (stock_id_mapping_data),
   .stock_id_mapping_rd_wrn        (stock_id_mapping_rd_wrn),
   .stock_id_mapping_cmd_valid     (stock_id_mapping_cmd_valid ),
   .stock_id_mapping_reply         (stock_id_mapping_reply),
   .stock_id_mapping_reply_valid   (stock_id_mapping_reply_valid),

   .warrants_id_mapping_addr          (warrants_id_mapping_addr),
   .warrants_id_mapping_data          (warrants_id_mapping_data),
   .warrants_id_mapping_rd_wrn        (warrants_id_mapping_rd_wrn),
   .warrants_id_mapping_cmd_valid     (warrants_id_mapping_cmd_valid ),
   .warrants_id_mapping_reply         (warrants_id_mapping_reply),
   .warrants_id_mapping_reply_valid   (warrants_id_mapping_reply_valid),

   .order_id_mapping_addr          (order_id_mapping_addr),
   .order_id_mapping_data          (order_id_mapping_data),
   .order_id_mapping_rd_wrn        (order_id_mapping_rd_wrn),
   .order_id_mapping_cmd_valid     (order_id_mapping_cmd_valid ),
   .order_id_mapping_reply         (order_id_mapping_reply),
   .order_id_mapping_reply_valid   (order_id_mapping_reply_valid),
   
   // Global Registers - user can select if to use
   .cpu_resetn_soft	(),		//software reset, after cpu module
   .resetn_soft    	(),		//software reset to cpu module (from central reset management)
   .resetn_sync    	(resetn_sync)	//synchronized reset, use for better timing
);

   assign clear_counters =  reset_reg[0];
   assign reset_registers = reset_reg[4];
   assign reset_tables   =  reset_reg[11:8];


always @(posedge axis_aclk)
	if (~resetn_sync | reset_registers) begin
		id_reg 					<= #1	 `REG_ID_DEFAULT;
		version_reg 				<= #1    `REG_VERSION_DEFAULT;
		ip2cpu_flip_reg 			<= #1    `REG_FLIP_DEFAULT;
		ip2cpu_debug_reg 			<= #1    `REG_DEBUG_DEFAULT;
		pkt_sent_from_cpu_cntr_reg 		<= #1    `REG_PKT_SENT_FROM_CPU_CNTR_DEFAULT;
		pkt_sent_to_cpu_options_ver_cntr_reg 	<= #1    `REG_PKT_SENT_TO_CPU_OPTIONS_VER_CNTR_DEFAULT;
		pkt_sent_to_cpu_bad_ttl_cntr_reg 	<= #1    `REG_PKT_SENT_TO_CPU_BAD_TTL_CNTR_DEFAULT;
		pkt_sent_to_cpu_dest_ip_hit_cntr_reg 	<= #1    `REG_PKT_SENT_TO_CPU_DEST_IP_HIT_CNTR_DEFAULT;
		pkt_forwarded_cntr_reg 			<= #1    `REG_PKT_FORWARDED_CNTR_DEFAULT;
		pkt_dropped_checksum_cntr_reg 		<= #1    `REG_PKT_DROPPED_CHECKSUM_CNTR_DEFAULT;
		pkt_sent_to_cpu_non_ip_cntr_reg 	<= #1    `REG_PKT_SENT_TO_CPU_NON_IP_CNTR_DEFAULT;
		pkt_sent_to_cpu_arp_miss_cntr_reg 	<= #1    `REG_PKT_SENT_TO_CPU_ARP_MISS_CNTR_DEFAULT;
		pkt_sent_to_cpu_lpm_miss_cntr_reg 	<= #1    `REG_PKT_SENT_TO_CPU_LPM_MISS_CNTR_DEFAULT;
		pkt_dropped_wrong_dst_mac_cntr_reg 	<= #1    `REG_PKT_DROPPED_WRONG_DST_MAC_CNTR_DEFAULT;
        	// add new register here
		ip2cpu_connect_signal_reg <= #1    `REG_CONNECT_SIGNAL_DEFAULT;
		ip2cpu_shutdown_signal_reg<= #1    `REG_SHUTDOWN_SIGNAL_DEFAULT;
		//ip2cpu_fix_logout_trigger_reg <= #1 `REG_FIX_LOGOUT_TRIGGER_DEFAULT;

		fix_logon_trigger_reg     <= #1    `REG_FIX_LOGON_TRIGGER_DEFAULT;
		fix_logout_trigger_reg    <= #1    `REG_FIX_LOGOUT_TRIGGER_DEFAULT;
		fix_resend_trigger_reg    <= #1    `REG_FIX_RESEND_TRIGGER_DEFAULT;


		tcp_logout_handshake_trigger_reg <= #1    `REG_TCP_LOGOUT_HANDSHAKE_TRIGGER_DEFAULT;
		tcp_logon_handshake_trigger_reg  <= #1    `REG_TCP_LOGON_HANDSHAKE_TRIGGER_DEFAULT;

		resend_begin_fix_seq_num_reg <= #1   `REG_RESEND_BEGIN_FIX_SEQ_NUM_DEFAULT;
		resend_end_fix_seq_num_reg   <= #1   `REG_RESEND_END_FIX_SEQ_NUM_DEFAULT;



		ip2cpu_current_fix_seq_num_reg <= #1 `REG_CURRENT_FIX_SEQ_NUM_DEFAULT;
		ip2cpu_overwrite_fix_seq_num_reg<= #1 `REG_OVERWRITE_FIX_SEQ_NUM_DEFAULT;
/*
		ip2cpu_resend_begin_fix_seq_num_reg<= #1 `REG_RESEND_BEGIN_FIX_SEQ_NUM_DEFAULT;
		ip2cpu_resend_end_fix_seq_num_reg  <= #1 `REG_RESEND_END_FIX_SEQ_NUM_DEFAULT;
*/


        	ip2cpu_kernel_time_ms_reg <= #1    `REG_KERNEL_TIME_MS_DEFAULT;
        	ip2cpu_kernel_time_s_reg <= #1    `REG_KERNEL_TIME_S_DEFAULT;
        	ip2cpu_kernel_time_min_reg <= #1    `REG_KERNEL_TIME_MIN_DEFAULT;
        	ip2cpu_kernel_time_hour_reg <= #1    `REG_KERNEL_TIME_HOUR_DEFAULT;
        	ip2cpu_kernel_time_day_reg <= #1    `REG_KERNEL_TIME_DAY_DEFAULT;
        	ip2cpu_kernel_time_mon_reg <= #1    `REG_KERNEL_TIME_MON_DEFAULT;
        	ip2cpu_kernel_time_year_reg <= #1    `REG_KERNEL_TIME_YEAR_DEFAULT;
	end
	else begin
		id_reg 			<= #1    `REG_ID_DEFAULT;
		version_reg 		<= #1    `REG_VERSION_DEFAULT;
		ip2cpu_flip_reg 	<= #1    ~cpu2ip_flip_reg;
		ip2cpu_debug_reg 	<= #1    `REG_DEBUG_DEFAULT+cpu2ip_debug_reg;


		// -- pkt_sent_from_cpu counter
		pkt_sent_from_cpu_cntr_reg[`REG_PKT_SENT_FROM_CPU_CNTR_WIDTH - 2 : 0]	<=	(clear_counters | pkt_sent_from_cpu_cntr_reg_clear) ? 'h0 : pkt_sent_from_cpu_cntr_reg[`REG_PKT_SENT_FROM_CPU_CNTR_WIDTH - 2 : 0] + pkt_sent_from_cpu;
		pkt_sent_from_cpu_cntr_reg[`REG_PKT_SENT_FROM_CPU_CNTR_WIDTH - 1 : 0]	<=	(clear_counters | pkt_sent_from_cpu_cntr_reg_clear) ? 1'b1 : pkt_sent_from_cpu & (pkt_sent_from_cpu_cntr_reg[`REG_PKT_SENT_FROM_CPU_CNTR_WIDTH - 2 : 0] + 1'b1 > {(`REG_PKT_SENT_FROM_CPU_CNTR_WIDTH-1){1'b1}}) ? 1'b1 : pkt_sent_from_cpu_cntr_reg[`REG_PKT_SENT_FROM_CPU_CNTR_WIDTH - 1];


		// -- pkt_sent_to_cpu_options_ver counter
		pkt_sent_to_cpu_options_ver_cntr_reg[`REG_PKT_SENT_TO_CPU_OPTIONS_VER_CNTR_WIDTH - 2 : 0]	<=	(clear_counters | pkt_sent_to_cpu_options_ver_cntr_reg_clear) ? 'h0 : pkt_sent_to_cpu_options_ver_cntr_reg[`REG_PKT_SENT_TO_CPU_OPTIONS_VER_CNTR_WIDTH - 2 : 0] + pkt_sent_to_cpu_options_ver;
		pkt_sent_to_cpu_options_ver_cntr_reg[`REG_PKT_SENT_TO_CPU_OPTIONS_VER_CNTR_WIDTH - 1]		<=	(clear_counters | pkt_sent_to_cpu_options_ver_cntr_reg_clear) ? 1'b0 : pkt_sent_to_cpu_options_ver & (pkt_sent_to_cpu_options_ver_cntr_reg[`REG_PKT_SENT_TO_CPU_OPTIONS_VER_CNTR_WIDTH - 2 : 0] + 1'b1 > {(`REG_PKT_SENT_TO_CPU_OPTIONS_VER_CNTR_WIDTH-1){1'b1}}) ? 1'b1 : pkt_sent_to_cpu_options_ver_cntr_reg[`REG_PKT_SENT_TO_CPU_OPTIONS_VER_CNTR_WIDTH - 1];


		// -- pkt_sent_to_cpu_bad_ttl counter
		pkt_sent_to_cpu_bad_ttl_cntr_reg[`REG_PKT_SENT_TO_CPU_BAD_TTL_CNTR_WIDTH - 2 : 0]	<=	(clear_counters | pkt_sent_to_cpu_bad_ttl_cntr_reg_clear) ? 'h0 : pkt_sent_to_cpu_bad_ttl_cntr_reg[`REG_PKT_SENT_TO_CPU_BAD_TTL_CNTR_WIDTH - 2 : 0] + pkt_sent_to_cpu_bad_ttl;
		pkt_sent_to_cpu_bad_ttl_cntr_reg[`REG_PKT_SENT_TO_CPU_BAD_TTL_CNTR_WIDTH - 1]		<=	(clear_counters | pkt_sent_to_cpu_bad_ttl_cntr_reg_clear) ? 1'b0 : pkt_sent_to_cpu_bad_ttl & (pkt_sent_to_cpu_bad_ttl_cntr_reg[`REG_PKT_SENT_TO_CPU_BAD_TTL_CNTR_WIDTH - 2 : 0] + 1'b1 > {(`REG_PKT_SENT_TO_CPU_BAD_TTL_CNTR_WIDTH-1){1'b1}}) ? 1'b1 : pkt_sent_to_cpu_bad_ttl_cntr_reg[`REG_PKT_SENT_TO_CPU_BAD_TTL_CNTR_WIDTH - 1];


		// -- pkt_sent_to_cpu_dest_ip_hit counter
		pkt_sent_to_cpu_dest_ip_hit_cntr_reg[`REG_PKT_SENT_TO_CPU_DEST_IP_HIT_CNTR_WIDTH - 2 : 0]	<=	(clear_counters | pkt_sent_to_cpu_dest_ip_hit_cntr_reg_clear) ? 'h0 : pkt_sent_to_cpu_dest_ip_hit_cntr_reg[`REG_PKT_SENT_TO_CPU_DEST_IP_HIT_CNTR_WIDTH - 2 : 0] + pkt_sent_to_cpu_dest_ip_hit;
		pkt_sent_to_cpu_dest_ip_hit_cntr_reg[`REG_PKT_SENT_TO_CPU_DEST_IP_HIT_CNTR_WIDTH - 1]		<=	(clear_counters | pkt_sent_to_cpu_dest_ip_hit_cntr_reg_clear) ? 1'b0 : pkt_sent_to_cpu_dest_ip_hit & (pkt_sent_to_cpu_dest_ip_hit_cntr_reg[`REG_PKT_SENT_TO_CPU_DEST_IP_HIT_CNTR_WIDTH - 2 : 0] + 1'b1 > {(`REG_PKT_SENT_TO_CPU_DEST_IP_HIT_CNTR_WIDTH-1){1'b1}}) ? 1'b1 : pkt_sent_to_cpu_dest_ip_hit_cntr_reg[`REG_PKT_SENT_TO_CPU_DEST_IP_HIT_CNTR_WIDTH - 1];


		// -- pkt_forwarded counter
		pkt_forwarded_cntr_reg[`REG_PKT_FORWARDED_CNTR_WIDTH - 2 : 0]	<=	(clear_counters | pkt_forwarded_cntr_reg_clear) ? 'h0 : pkt_forwarded_cntr_reg[`REG_PKT_FORWARDED_CNTR_WIDTH - 2 : 0] + pkt_forwarded;
		pkt_forwarded_cntr_reg[`REG_PKT_FORWARDED_CNTR_WIDTH - 1]	<=	(clear_counters | pkt_forwarded_cntr_reg_clear) ? 1'b0 : pkt_forwarded & (pkt_forwarded_cntr_reg[`REG_PKT_FORWARDED_CNTR_WIDTH - 2 : 0] + (1'b1) > {(`REG_PKT_FORWARDED_CNTR_WIDTH-1){1'b1}}) ? 1'b1 : pkt_forwarded_cntr_reg[`REG_PKT_FORWARDED_CNTR_WIDTH - 1];


		// -- pkt_dropped_checksum counter
		pkt_dropped_checksum_cntr_reg[`REG_PKT_DROPPED_CHECKSUM_CNTR_WIDTH - 2 : 0]	<=	(clear_counters | pkt_dropped_checksum_cntr_reg_clear) ? 'h0 : pkt_dropped_checksum_cntr_reg[`REG_PKT_DROPPED_CHECKSUM_CNTR_WIDTH - 2 : 0] + pkt_dropped_checksum;
		pkt_dropped_checksum_cntr_reg[`REG_PKT_DROPPED_CHECKSUM_CNTR_WIDTH - 1 ]	<=	(clear_counters | pkt_dropped_checksum_cntr_reg_clear) ? 1'b0 : pkt_dropped_checksum & (pkt_dropped_checksum_cntr_reg[`REG_PKT_DROPPED_CHECKSUM_CNTR_WIDTH - 2 : 0] + 1'b1 > {(`REG_PKT_DROPPED_CHECKSUM_CNTR_WIDTH-1){1'b1}}) ? 1'b1 : pkt_dropped_checksum_cntr_reg[`REG_PKT_DROPPED_CHECKSUM_CNTR_WIDTH - 1];


		// -- pkt_sent_to_cpu_non_ip counter
		pkt_sent_to_cpu_non_ip_cntr_reg[`REG_PKT_SENT_TO_CPU_NON_IP_CNTR_WIDTH - 2 : 0]	<=	(clear_counters | pkt_sent_to_cpu_non_ip_cntr_reg_clear) ? 'h0 : pkt_sent_to_cpu_non_ip_cntr_reg[`REG_PKT_SENT_TO_CPU_NON_IP_CNTR_WIDTH - 2 : 0] + pkt_sent_to_cpu_non_ip;
		pkt_sent_to_cpu_non_ip_cntr_reg[`REG_PKT_SENT_TO_CPU_NON_IP_CNTR_WIDTH - 1 ]	<=	(clear_counters | pkt_sent_to_cpu_non_ip_cntr_reg_clear) ? 1'b0 : pkt_sent_to_cpu_non_ip & (pkt_sent_to_cpu_non_ip_cntr_reg[`REG_PKT_SENT_TO_CPU_NON_IP_CNTR_WIDTH - 2 : 0] + 1'b1 > {(`REG_PKT_SENT_TO_CPU_NON_IP_CNTR_WIDTH-1){1'b1}}) ? 1'b1 : pkt_sent_to_cpu_non_ip_cntr_reg[`REG_PKT_SENT_TO_CPU_NON_IP_CNTR_WIDTH - 1];
		

		// -- pkt_sent_to_cpu_arp_miss counter
		pkt_sent_to_cpu_arp_miss_cntr_reg[`REG_PKT_SENT_TO_CPU_ARP_MISS_CNTR_WIDTH - 2 : 0]	<=	(clear_counters | pkt_sent_to_cpu_arp_miss_cntr_reg_clear) ? 'h0 : pkt_sent_to_cpu_arp_miss_cntr_reg[`REG_PKT_SENT_TO_CPU_ARP_MISS_CNTR_WIDTH - 2 : 0] + pkt_sent_to_cpu_arp_miss;
		pkt_sent_to_cpu_arp_miss_cntr_reg[`REG_PKT_SENT_TO_CPU_ARP_MISS_CNTR_WIDTH - 1 ]	<=	(clear_counters | pkt_sent_to_cpu_arp_miss_cntr_reg_clear) ? 1'b0 : pkt_sent_to_cpu_arp_miss & (pkt_sent_to_cpu_arp_miss_cntr_reg[`REG_PKT_SENT_TO_CPU_ARP_MISS_CNTR_WIDTH - 2 : 0] + 1'b1 > {(`REG_PKT_SENT_TO_CPU_ARP_MISS_CNTR_WIDTH-1){1'b1}}) ? 1'b1 : pkt_sent_to_cpu_arp_miss_cntr_reg[`REG_PKT_SENT_TO_CPU_ARP_MISS_CNTR_WIDTH - 1];


		// -- pkt_sent_to_cpu_lpm_miss counter
/*
		pkt_sent_to_cpu_lpm_miss_cntr_reg[`REG_PKT_SENT_TO_CPU_LPM_MISS_CNTR_WIDTH - 2 : 0]	<=	(clear_counters | pkt_sent_to_cpu_lpm_miss_cntr_reg_clear) ? 'h0 : pkt_sent_to_cpu_lpm_miss_cntr_reg[`REG_PKT_SENT_TO_CPU_LPM_MISS_CNTR_WIDTH - 2 : 0] + pkt_sent_to_cpu_lpm_miss;
		pkt_sent_to_cpu_lpm_miss_cntr_reg[`REG_PKT_SENT_TO_CPU_LPM_MISS_CNTR_WIDTH - 1 ]	<=	(clear_counters | pkt_sent_to_cpu_lpm_miss_cntr_reg_clear) ? 1'b0 : pkt_sent_to_cpu_lpm_miss & (pkt_sent_to_cpu_lpm_miss_cntr_reg[`REG_PKT_SENT_TO_CPU_LPM_MISS_CNTR_WIDTH - 2 : 0] + 1'b1 > {(`REG_PKT_SENT_TO_CPU_LPM_MISS_CNTR_WIDTH-1){1'b1}}) ? 1'b1 : pkt_sent_to_cpu_lpm_miss_cntr_reg[`REG_PKT_SENT_TO_CPU_LPM_MISS_CNTR_WIDTH - 1];
*/
		pkt_sent_to_cpu_lpm_miss_cntr_reg <= pkt_sent_to_cpu_lpm_miss ;

		// -- pkt_dropped_wrong_dst_mac counter
		pkt_dropped_wrong_dst_mac_cntr_reg[`REG_PKT_DROPPED_WRONG_DST_MAC_CNTR_WIDTH - 2 : 0]	<=	(clear_counters | pkt_dropped_wrong_dst_mac_cntr_reg_clear) ? 'h0 : pkt_dropped_wrong_dst_mac_cntr_reg[`REG_PKT_DROPPED_WRONG_DST_MAC_CNTR_WIDTH - 2 : 0] + pkt_dropped_wrong_dst_mac;
		pkt_dropped_wrong_dst_mac_cntr_reg[`REG_PKT_DROPPED_WRONG_DST_MAC_CNTR_WIDTH - 1 ]	<=	(clear_counters | pkt_dropped_wrong_dst_mac_cntr_reg_clear) ? 1'b0 : pkt_dropped_wrong_dst_mac & (pkt_dropped_wrong_dst_mac_cntr_reg[`REG_PKT_DROPPED_WRONG_DST_MAC_CNTR_WIDTH - 2 : 0] + 1'b1 > {(`REG_PKT_DROPPED_WRONG_DST_MAC_CNTR_WIDTH-1){1'b1}}) ? 1'b1 : pkt_dropped_wrong_dst_mac_cntr_reg[`REG_PKT_DROPPED_WRONG_DST_MAC_CNTR_WIDTH - 1];


		//FIX LOGON TRIGGER counter
		fix_logon_trigger_reg[`REG_FIX_LOGON_TRIGGER_WIDTH - 2 : 0] <= (clear_counters | fix_logon_trigger_reg_clear) ? 'h0 : fix_logon_trigger_reg[`REG_FIX_LOGON_TRIGGER_WIDTH - 2 : 0] + fix_logon_trigger;
                fix_logon_trigger_reg[`REG_FIX_LOGON_TRIGGER_WIDTH - 1 ]    <= (clear_counters | fix_logon_trigger_reg_clear) ? 1'b0 : fix_logon_trigger & (fix_logon_trigger_reg[`REG_FIX_LOGON_TRIGGER_WIDTH - 2 : 0] + 1'b1 > {(`REG_FIX_LOGON_TRIGGER_WIDTH-1){1'b1}}) ? 1'b1 : fix_logon_trigger_reg[`REG_FIX_LOGON_TRIGGER_WIDTH - 1];




 // -- FIX_LOGOUT TRIGGER counter

                fix_logout_trigger_reg[`REG_FIX_LOGOUT_TRIGGER_WIDTH - 2 : 0] <= (clear_counters | fix_logout_trigger_reg_clear) ? 'h0 : fix_logout_trigger_reg[`REG_FIX_LOGOUT_TRIGGER_WIDTH - 2 : 0] + fix_logout_trigger;
                fix_logout_trigger_reg[`REG_FIX_LOGOUT_TRIGGER_WIDTH - 1 ]    <= (clear_counters | fix_logout_trigger_reg_clear) ? 1'b0 : fix_logout_trigger & (fix_logout_trigger_reg[`REG_FIX_LOGOUT_TRIGGER_WIDTH - 2 : 0] + 1'b1 > {(`REG_FIX_LOGOUT_TRIGGER_WIDTH-1){1'b1}}) ? 1'b1 : fix_logout_trigger_reg[`REG_FIX_LOGOUT_TRIGGER_WIDTH - 1];


//		fix_logout_trigger_reg <= fix_logout_trigger;

		fix_resend_trigger_reg[`REG_FIX_RESEND_TRIGGER_WIDTH - 2 : 0] <= (clear_counters | fix_resend_trigger_reg_clear) ? 'h0 : fix_resend_trigger_reg[`REG_FIX_RESEND_TRIGGER_WIDTH - 2 : 0] + fix_resend_trigger;
                fix_resend_trigger_reg[`REG_FIX_RESEND_TRIGGER_WIDTH - 1 ]    <= (clear_counters | fix_resend_trigger_reg_clear) ? 1'b0 : fix_resend_trigger & (fix_resend_trigger_reg[`REG_FIX_RESEND_TRIGGER_WIDTH - 2 : 0] + 1'b1 > {(`REG_FIX_RESEND_TRIGGER_WIDTH-1){1'b1}}) ? 1'b1 : fix_resend_trigger_reg[`REG_FIX_RESEND_TRIGGER_WIDTH - 1];
		


		tcp_logout_handshake_trigger_reg[`REG_TCP_LOGOUT_HANDSHAKE_TRIGGER_WIDTH - 2 : 0] <= (clear_counters | tcp_logout_handshake_trigger_reg_clear) ? 'h0 : tcp_logout_handshake_trigger_reg[`REG_TCP_LOGOUT_HANDSHAKE_TRIGGER_WIDTH - 2 : 0] + tcp_logout_handshake_trigger;
                tcp_logout_handshake_trigger_reg[`REG_TCP_LOGOUT_HANDSHAKE_TRIGGER_WIDTH - 1 ]    <= (clear_counters | tcp_logout_handshake_trigger_reg_clear) ? 1'b0 : tcp_logout_handshake_trigger & (tcp_logout_handshake_trigger_reg[`REG_TCP_LOGOUT_HANDSHAKE_TRIGGER_WIDTH - 2 : 0] + 1'b1 > {(`REG_TCP_LOGOUT_HANDSHAKE_TRIGGER_WIDTH-1){1'b1}}) ? 1'b1 : tcp_logout_handshake_trigger_reg[`REG_TCP_LOGOUT_HANDSHAKE_TRIGGER_WIDTH - 1];

                tcp_logon_handshake_trigger_reg[`REG_TCP_LOGON_HANDSHAKE_TRIGGER_WIDTH - 2 : 0] <= (clear_counters | tcp_logon_handshake_trigger_reg_clear) ? 'h0 : tcp_logon_handshake_trigger_reg[`REG_TCP_LOGON_HANDSHAKE_TRIGGER_WIDTH - 2 : 0] + tcp_logon_handshake_trigger;
                tcp_logon_handshake_trigger_reg[`REG_TCP_LOGON_HANDSHAKE_TRIGGER_WIDTH - 1 ]    <= (clear_counters | tcp_logon_handshake_trigger_reg_clear) ? 1'b0 : tcp_logon_handshake_trigger & (tcp_logon_handshake_trigger_reg[`REG_TCP_LOGON_HANDSHAKE_TRIGGER_WIDTH - 2 : 0] + 1'b1 > {(`REG_TCP_LOGON_HANDSHAKE_TRIGGER_WIDTH-1){1'b1}}) ? 1'b1 : tcp_logon_handshake_trigger_reg[`REG_TCP_LOGON_HANDSHAKE_TRIGGER_WIDTH - 1];





		resend_begin_fix_seq_num_reg <= resend_begin_fix_seq_num;
		resend_end_fix_seq_num_reg   <= resend_end_fix_seq_num;

/*
		pkt_sent_to_cpu_arp_miss_cntr_reg <= process_count[95:64];
		pkt_sent_to_cpu_lpm_miss_cntr_reg <= process_count[63:32];
		pkt_dropped_wrong_dst_mac_cntr_reg <= process_count[31:0];
*/
        	// add new register here
		ip2cpu_connect_signal_reg <= #1 cpu2ip_connect_signal_reg;
		ip2cpu_shutdown_signal_reg<= #1 cpu2ip_shutdown_signal_reg;
		//ip2cpu_fix_logout_trigger_reg <= #1 cpu2ip_fix_logout_trigger_reg;
		ip2cpu_current_fix_seq_num_reg<= #1 cpu2ip_current_fix_seq_num_reg;
		ip2cpu_overwrite_fix_seq_num_reg<=#1 cpu2ip_overwrite_fix_seq_num_reg;
/*
		ip2cpu_resend_begin_fix_seq_num_reg<=#1 ip2cpu_resend_begin_fix_seq_num_reg;
		ip2cpu_resend_end_fix_seq_num_reg  <= #1 ip2cpu_resend_end_fix_seq_num_reg;
*/

		ip2cpu_kernel_time_ms_reg <= #1 cpu2ip_kernel_time_ms_reg;
		ip2cpu_kernel_time_s_reg <= #1 cpu2ip_kernel_time_s_reg;
		ip2cpu_kernel_time_min_reg <= #1 cpu2ip_kernel_time_min_reg;
		ip2cpu_kernel_time_hour_reg <= #1 cpu2ip_kernel_time_hour_reg;
		ip2cpu_kernel_time_day_reg <= #1 cpu2ip_kernel_time_day_reg;
		ip2cpu_kernel_time_mon_reg <= #1 cpu2ip_kernel_time_mon_reg;
		ip2cpu_kernel_time_year_reg <= #1 cpu2ip_kernel_time_year_reg;

end

always @(posedge axis_aclk) begin
	if (~resetn_sync) begin
		process_count <= 'h0;
	end
	else begin
		if(input_arbiter_not_empty || output_queue_not_empty || ol_not_empty || og_not_empty) begin
			process_count <= process_count + 'b1;
		end
	end
end

//FIX LOGOUT TRIGGER

/*
       always @(posedge axis_aclk) begin
         if  (~resetn_sync) begin
                ip2cpu_fix_logout_trigger_reg <= 'b0;
         end
         else begin
                if(fix_logout_signal)begin
                        ip2cpu_fix_logout_trigger_reg<= 'b1;
                end
		else begin
			ip2cpu_fix_logout_trigger_reg<= 'b0;
		end
	 end
       end

*/
   
endmodule // output_port_lookup

