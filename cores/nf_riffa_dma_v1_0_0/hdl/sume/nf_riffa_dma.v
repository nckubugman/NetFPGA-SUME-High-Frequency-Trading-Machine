//-
// Copyright (c) 2015 Y. Audzevich
// All rights reserved.
//
// This software was developed by
// Stanford University and the University of Cambridge Computer Laboratory
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
// as part of the DARPA MRC research programme.
//
//  File:
//        axis_sume_attachment_top.v
//
//  Author: Y. Audzevich
//
//  List of ITEMS:
// - RIFFA SumeGen2x8If128 
// - SUME AXIS attachment
// - SUME AXI-Lite attachment
// NOTE: PCIe should be configured and connected externally.
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

`include "functions.vh"
`include "riffa.vh"
`include "ultrascale.vh"
`timescale 1ps / 1ps

//`default_nettype none  //ya
`include "nf_riffa_dma_cpu_regs_defines.v"

module nf_riffa_dma
    #(// Number of RIFFA Channels
      parameter C_NUM_CHNL = 2,
      // Number of PCIe Lanes == 8
      // Settings from Vivado IP Generator
      parameter C_PCI_DATA_WIDTH = 128,
      parameter C_MAX_PAYLOAD_BYTES = 128, 
      parameter C_LOG_NUM_TAGS = 6,
      // SUME AXIS
      parameter C_AXIS_TDATA_WIDTH  = 128,
      parameter C_AXIS_TKEEP_WIDTH  = 16,
      parameter C_AXIS_TUSER_WIDTH  = 128,
      parameter C_PREAM_VALUE    = 51966, //'hCAFE
      //SUME AXI-Lite
      parameter C_M_AXI_LITE_ADDR_WIDTH = 32,
      parameter C_M_AXI_LITE_DATA_WIDTH = 32,
      parameter C_M_AXI_LITE_STRB_WIDTH = 4,
      // AXI Registers Data Width
      parameter C_S_AXI_DATA_WIDTH    = 32,
      parameter C_S_AXI_ADDR_WIDTH    = 12,
      parameter C_BASEADDR            = 32'h00000000
                 
      ) 
    (
 
    input wire                              user_clk,
    input wire                              user_reset,
    input wire                              user_lnk_up,
    
    //---------------------------------------------------------------------  
    // Interface: RQ (TXC)
    //---------------------------------------------------------------------
    input wire                              s_axis_rq_tready,
    output wire                             s_axis_rq_tvalid,
    output wire                             s_axis_rq_tlast,
    output wire [127:0]                     s_axis_rq_tdata,    
    output wire [(C_PCI_DATA_WIDTH/32)-1:0] s_axis_rq_tkeep,
    output wire [(`SIG_RQ_TUSER_W-1):0]       s_axis_rq_tuser,
    
    //---------------------------------------------------------------------
    // Interface: RC (RXC)
    //---------------------------------------------------------------------
    output wire [21:0]                      m_axis_rc_tready,
    input wire                              m_axis_rc_tvalid,
    input wire                              m_axis_rc_tlast, 
    input wire [(C_PCI_DATA_WIDTH-1):0]       m_axis_rc_tdata,
    input wire [(`SIG_RC_TUSER_W-1):0]        m_axis_rc_tuser,
    input wire [((C_PCI_DATA_WIDTH/32)-1):0]  m_axis_rc_tkeep,
    
    //---------------------------------------------------------------------   
    // Interface: CQ (RXR)
    //---------------------------------------------------------------------
    output wire [21:0]                      m_axis_cq_tready, 
    input wire                              m_axis_cq_tvalid,
    input wire                              m_axis_cq_tlast,
    input wire [(C_PCI_DATA_WIDTH-1):0]       m_axis_cq_tdata,
    input wire [(C_PCI_DATA_WIDTH/32)-1:0]  m_axis_cq_tkeep,
    input wire [(`SIG_CQ_TUSER_W-1):0]        m_axis_cq_tuser,
    
    //---------------------------------------------------------------------   
    // Interface: CC (TXC)
    //---------------------------------------------------------------------
    input wire                              s_axis_cc_tready,
    output wire                             s_axis_cc_tvalid,
    output wire                             s_axis_cc_tlast,
    output wire [127:0]                     s_axis_cc_tdata,
    output wire [(C_PCI_DATA_WIDTH/32)-1:0] s_axis_cc_tkeep,
    output wire [(`SIG_CC_TUSER_W-1):0]       s_axis_cc_tuser,
    
    //---------------------------------------------------------------------
    //  Configuration (CFG) Interface                                      
    //---------------------------------------------------------------------  
    input wire [3:0]                        pcie_rq_seq_num,
    input wire                              pcie_rq_seq_num_vld,
    input wire [5:0]                        pcie_rq_tag,
    input wire                              pcie_rq_tag_vld,    
    output wire                             pcie_cq_np_req,
    input wire [5:0]                        pcie_cq_np_req_count,
    input wire                              cfg_phy_link_down,
    input wire [1:0]                        cfg_phy_link_status,
    input wire [3:0]                        cfg_negotiated_width, // CONFIG_LINK_WIDTH
    input wire [2:0]                        cfg_current_speed, // CONFIG_LINK_RATE
    input wire [2:0]                        cfg_max_payload, // CONFIG_MAX_PAYLOAD
    input wire [2:0]                        cfg_max_read_req, // CONFIG_MAX_READ_REQUEST
    input wire [7:0]                        cfg_function_status, // [2] = CONFIG_BUS_MASTER_ENABLE
    input wire [5:0]                        cfg_function_power_state, // Ignorable but not removable  
    input wire [11:0]                       cfg_vf_status, // Ignorable but not removable
    input wire [17:0]                       cfg_vf_power_state, // Ignorable but not removable
    input wire [1:0]                        cfg_link_power_state, // Ignorable but not removable
    input wire                              cfg_err_cor_out,
    input wire                              cfg_err_nonfatal_out,
    input wire                              cfg_err_fatal_out, 
    input wire                              cfg_ltr_enable,
    input wire [5:0]                        cfg_ltssm_state, // TODO: Connect to LED's
    input wire [1:0]                        cfg_rcb_status, 
    input wire [1:0]                        cfg_dpa_substate_change,  
    input wire [1:0]                        cfg_obff_enable,
    input wire                              cfg_pl_status_change,
    input wire [1:0]                        cfg_tph_requester_enable, 
    input wire [5:0]                        cfg_tph_st_mode, 
    input wire [5:0]                        cfg_vf_tph_requester_enable,
    input wire [17:0]                       cfg_vf_tph_st_mode,
    input wire [7:0]                        cfg_fc_ph,
    input wire [11:0]                       cfg_fc_pd,
    input wire [7:0]                        cfg_fc_nph,
    input wire [11:0]                       cfg_fc_npd,
    input wire [7:0]                        cfg_fc_cplh,
    input wire [11:0]                       cfg_fc_cpld,
    output wire [2:0]                       cfg_fc_sel,    

    //---------------------------------------------------------------------
    //  EndPoint Only                                      
    //--------------------------------------------------------------------- 
    output wire [3:0]                       cfg_interrupt_int,
    output wire [1:0]                       cfg_interrupt_pending,
    input wire                              cfg_interrupt_sent,  
    input wire [1:0]                        cfg_interrupt_msi_enable,
    input wire [5:0]                        cfg_interrupt_msi_vf_enable,    
    input wire [5:0]                        cfg_interrupt_msi_mmenable,   
    input wire                              cfg_interrupt_msi_mask_update,
    input wire [31:0]                       cfg_interrupt_msi_data,    
    output wire [3:0]                       cfg_interrupt_msi_select,
    output wire [31:0]                      cfg_interrupt_msi_int,
    output wire [63:0]                      cfg_interrupt_msi_pending_status, 
    input wire                              cfg_interrupt_msi_sent,
    input wire                              cfg_interrupt_msi_fail,
    output wire [2:0]                       cfg_interrupt_msi_attr,
    output wire                             cfg_interrupt_msi_tph_present,
    output wire [1:0]                       cfg_interrupt_msi_tph_type,
    output wire [8:0]                       cfg_interrupt_msi_tph_st_tag,
    output wire [2:0]                       cfg_interrupt_msi_function_number,
    
    //---------------------------------------------------------------------
    // SUME AXIS interfaces
    //---------------------------------------------------------------------
   
    output wire [(C_AXIS_TDATA_WIDTH-1):0]       m_axis_xge_tx_tdata, 
    output wire [(C_AXIS_TKEEP_WIDTH-1):0]       m_axis_xge_tx_tkeep, 
    output wire [(C_AXIS_TUSER_WIDTH-1):0]       m_axis_xge_tx_tuser,
    output wire                              m_axis_xge_tx_tlast, 
    output wire                              m_axis_xge_tx_tvalid, 
    input wire                               m_axis_xge_tx_tready,            
 
    input wire [(C_AXIS_TDATA_WIDTH-1):0]        s_axis_xge_rx_tdata, 
    input wire [(C_AXIS_TKEEP_WIDTH-1):0]        s_axis_xge_rx_tkeep,
    input wire [(C_AXIS_TUSER_WIDTH-1):0]        s_axis_xge_rx_tuser,
    input wire                               s_axis_xge_rx_tlast, 
    input wire                               s_axis_xge_rx_tvalid,   
    output wire                              s_axis_xge_rx_tready,
    
    //---------------------------------------------------------------------
    // SUME AXI-Lite interfaces
    //---------------------------------------------------------------------
    input  wire                              m_axi_lite_aclk,
    input  wire                              m_axi_lite_aresetn,
    
    input  wire                              m_axi_lite_arready,
    output wire                               m_axi_lite_arvalid,
    output wire [(C_M_AXI_LITE_ADDR_WIDTH-1):0] m_axi_lite_araddr,
    output wire [2:0]                         m_axi_lite_arprot,
    
    output wire                               m_axi_lite_rready,
    input wire                               m_axi_lite_rvalid,
    input wire [(C_M_AXI_LITE_DATA_WIDTH-1):0] m_axi_lite_rdata,
    input wire [1:0]                         m_axi_lite_rresp,
    
    input wire                               m_axi_lite_awready,
    output wire                               m_axi_lite_awvalid,
    output wire [(C_M_AXI_LITE_ADDR_WIDTH-1):0] m_axi_lite_awaddr,
    output wire [2:0]                         m_axi_lite_awprot,
    
    input wire                               m_axi_lite_wready,
    output wire                               m_axi_lite_wvalid,
    output wire [(C_M_AXI_LITE_DATA_WIDTH-1):0] m_axi_lite_wdata,
    output wire [(C_M_AXI_LITE_STRB_WIDTH-1):0] m_axi_lite_wstrb,
      
    output wire                               m_axi_lite_bready,
    input  wire                              m_axi_lite_bvalid,
    input  wire [1:0]                        m_axi_lite_bresp,
    
    // Signals for AXI_IP and IF_REG (Added for debug purposes)
        // Slave AXI Ports
        input      [C_S_AXI_ADDR_WIDTH-1 : 0]     s_axi_lite_awaddr,
        input                                     s_axi_lite_awvalid,
        input      [C_S_AXI_DATA_WIDTH-1 : 0]     s_axi_lite_wdata,
        input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   s_axi_lite_wstrb,
        input                                     s_axi_lite_wvalid,
        input                                     s_axi_lite_bready,
        input      [C_S_AXI_ADDR_WIDTH-1 : 0]     s_axi_lite_araddr,
        input                                     s_axi_lite_arvalid,
        input                                     s_axi_lite_rready,
        output                                    s_axi_lite_arready,
        output     [C_S_AXI_DATA_WIDTH-1 : 0]     s_axi_lite_rdata,
        output     [1 : 0]                        s_axi_lite_rresp,
        output                                    s_axi_lite_rvalid,
        output                                    s_axi_lite_wready,
        output     [1 :0]                         s_axi_lite_bresp,
        output                                    s_axi_lite_bvalid,
        output                                    s_axi_lite_awready,
    
    output wire                               md_error   
   );

   ////////////////////////////////////////////////////////////////////
   // localparams
   //////////////////////////////////////////////////////////////////// 
   // RIFFA CHNL[0] -> AXIS (Reference pipeline), 
   // RIFFA CHNL[1] -> AXI-Lite (Debug capabilities)  
   localparam axis_chnl_num_lp       = 0;
   localparam axi_lite_chnl_num_lp   = 1;
   
   ////////////////////////////////////////////////////////////////////
   // Signals
   ///////////////////////////////////////////////////////////////////
   // AXIS
    wire                                       m_axis_cq_tready_bit;
    wire                                       m_axis_rc_tready_bit;
    
    // RIFFA RX & TX                
    wire                                       rst_out; 
    
    wire [(C_NUM_CHNL-1):0]                      chnl_rx_clk;  
    wire [(C_NUM_CHNL-1):0]                      chnl_rx; 
    wire [(C_NUM_CHNL-1):0]                      chnl_rx_ack; 
    wire [(C_NUM_CHNL-1):0]                      chnl_rx_last; 
    wire [((C_NUM_CHNL*`SIG_CHNL_LENGTH_W)-1):0] chnl_rx_len; 
    wire [((C_NUM_CHNL*`SIG_CHNL_OFFSET_W)-1):0] chnl_rx_off; 
    wire [(C_NUM_CHNL*C_PCI_DATA_WIDTH)-1:0]   chnl_rx_data; 
    wire [(C_NUM_CHNL-1):0]                      chnl_rx_data_valid; 
    wire [(C_NUM_CHNL-1):0]                      chnl_rx_data_ren;

    wire [(C_NUM_CHNL-1):0]                      chnl_tx_clk; 
    wire [(C_NUM_CHNL-1):0]                      chnl_tx; 
    wire [(C_NUM_CHNL-1):0]                      chnl_tx_ack;
    wire [(C_NUM_CHNL-1):0]                      chnl_tx_last; 
    wire [((C_NUM_CHNL*`SIG_CHNL_LENGTH_W)-1):0] chnl_tx_len; 
    wire [((C_NUM_CHNL*`SIG_CHNL_OFFSET_W)-1):0] chnl_tx_off; 
    wire [((C_NUM_CHNL*C_PCI_DATA_WIDTH)-1):0]   chnl_tx_data; 
    wire [(C_NUM_CHNL-1):0]                      chnl_tx_data_valid; 
    wire [(C_NUM_CHNL-1):0]                      chnl_tx_data_ren;
 
    reg      [`REG_ID_BITS]    id_reg;
    reg      [`REG_VERSION_BITS]    version_reg;
    wire     [`REG_RESET_BITS]    reset_reg;
    reg      [`REG_FLIP_BITS]    ip2cpu_flip_reg;
    wire     [`REG_FLIP_BITS]    cpu2ip_flip_reg;
    reg      [`REG_DEBUG_BITS]    ip2cpu_debug_reg;
    wire     [`REG_DEBUG_BITS]    cpu2ip_debug_reg;
    reg      [`REG_RQPKT_BITS]    rqpkt_reg;
    wire                             rqpkt_reg_clear;
    reg      [`REG_RCPKT_BITS]    rcpkt_reg;
    wire                             rcpkt_reg_clear;
    reg      [`REG_CQPKT_BITS]    cqpkt_reg;
    wire                             cqpkt_reg_clear;
    reg      [`REG_CCPKT_BITS]    ccpkt_reg;
    wire                             ccpkt_reg_clear;
    reg      [`REG_XGETXPKT_BITS]    xgetxpkt_reg;
    wire                             xgetxpkt_reg_clear;
    reg      [`REG_XGERXPKT_BITS]    xgerxpkt_reg;
    wire                             xgerxpkt_reg_clear;
    reg      [`REG_PCIERQ_BITS]    pcierq_reg;
    reg      [`REG_PCIEPHY_BITS]    pciephy_reg;
    reg      [`REG_PCIECONFIG_BITS]    pcieconfig_reg;
    reg      [`REG_PCIECONFIG2_BITS]    pcieconfig2_reg;
    reg      [`REG_PCIEERROR_BITS]    pcieerror_reg;
    reg      [`REG_PCIEMISC_BITS]    pciemisc_reg;
    reg      [`REG_PCIETPH_BITS]    pcietph_reg;
    reg      [`REG_PCIEFC1_BITS]    pciefc1_reg;
    reg      [`REG_PCIEFC2_BITS]    pciefc2_reg;
    reg      [`REG_PCIEFC3_BITS]    pciefc3_reg;
    reg      [`REG_PCIEINTERRUPT_BITS]    pcieinterrupt_reg;
    reg      [`REG_PCIEMSIDATA_BITS]    pciemsidata_reg;
    reg      [`REG_PCIEMSIINT_BITS]    pciemsiint_reg;
    reg      [`REG_PCIEMSIPENDINGSTATUS_BITS]    pciemsipendingstatus_reg;
    reg      [`REG_PCIEMSIPENDINGSTATUS2_BITS]    pciemsipendingstatus2_reg;
    reg      [`REG_PCIEINTERRUPT2_BITS]    pcieinterrupt2_reg;

    wire     clear_counters;
    wire     reset_registers;

    genvar                                     chnl;

 ////////////////////////////
 /// assignments 
 assign m_axis_cq_tready =  {22{m_axis_cq_tready_bit}};
 assign m_axis_rc_tready =  {22{m_axis_rc_tready_bit}};

  // RIFFA Gen2x8 core
    riffa_wrapper_sume #(
        .C_LOG_NUM_TAGS                                     (C_LOG_NUM_TAGS),
        .C_NUM_CHNL                                         (C_NUM_CHNL),
        .C_PCI_DATA_WIDTH                                   (C_PCI_DATA_WIDTH),
        .C_MAX_PAYLOAD_BYTES                                (C_MAX_PAYLOAD_BYTES)
    ) riffa (
        // Outputs
        .M_AXIS_CQ_TREADY                                   (m_axis_cq_tready_bit), 
        .M_AXIS_RC_TREADY                                   (m_axis_rc_tready_bit), 
         
         .S_AXIS_CC_TVALID                                  (s_axis_cc_tvalid), 
         .S_AXIS_CC_TLAST                                   (s_axis_cc_tlast), 
         .S_AXIS_CC_TDATA                                   (s_axis_cc_tdata), 
         .S_AXIS_CC_TKEEP                                   (s_axis_cc_tkeep), 
         .S_AXIS_CC_TUSER                                   (s_axis_cc_tuser),
         
         .S_AXIS_RQ_TVALID                                  (s_axis_rq_tvalid),
         .S_AXIS_RQ_TLAST                                   (s_axis_rq_tlast), 
         .S_AXIS_RQ_TDATA                                   (s_axis_rq_tdata), 
         .S_AXIS_RQ_TKEEP                                   (s_axis_rq_tkeep), 
         .S_AXIS_RQ_TUSER                                   (s_axis_rq_tuser), 
         
         .USER_CLK                                          (user_clk), 
         .USER_RESET                                        (user_reset), 
         
         .CFG_INTERRUPT_INT                                 (cfg_interrupt_int[3:0]), 
         .CFG_INTERRUPT_PENDING                             (cfg_interrupt_pending[1:0]), 
         .CFG_INTERRUPT_MSI_SELECT                          (cfg_interrupt_msi_select[3:0]), 
         .CFG_INTERRUPT_MSI_INT                             (cfg_interrupt_msi_int[31:0]), 
         .CFG_INTERRUPT_MSI_PENDING_STATUS                  (cfg_interrupt_msi_pending_status[63:0]), 
         .CFG_INTERRUPT_MSI_ATTR                            (cfg_interrupt_msi_attr[2:0]), 
         .CFG_INTERRUPT_MSI_TPH_PRESENT                     (cfg_interrupt_msi_tph_present), 
         .CFG_INTERRUPT_MSI_TPH_TYPE                        (cfg_interrupt_msi_tph_type[1:0]), 
         .CFG_INTERRUPT_MSI_TPH_ST_TAG                      (cfg_interrupt_msi_tph_st_tag[8:0]), 
         .CFG_INTERRUPT_MSI_FUNCTION_NUMBER                 (cfg_interrupt_msi_function_number[2:0]),
         .CFG_FC_SEL                                        (cfg_fc_sel[2:0]),
         
         .PCIE_CQ_NP_REQ                                    (pcie_cq_np_req),
             
         .RST_OUT                                           (rst_out), 
                  
         .CHNL_RX                                           (chnl_rx), 
         .CHNL_RX_LAST                                      (chnl_rx_last),  
         .CHNL_RX_LEN                                       (chnl_rx_len), 
         .CHNL_RX_OFF                                       (chnl_rx_off), 
         .CHNL_RX_DATA                                      (chnl_rx_data), 
         .CHNL_RX_DATA_VALID                                (chnl_rx_data_valid), 
         .CHNL_TX_ACK                                       (chnl_tx_ack), 
         .CHNL_TX_DATA_REN                                  (chnl_tx_data_ren), 
         
         // Inputs
         .M_AXIS_CQ_TVALID                                  (m_axis_cq_tvalid), 
         .M_AXIS_CQ_TLAST                                   (m_axis_cq_tlast), 
         .M_AXIS_CQ_TDATA                                   (m_axis_cq_tdata), 
         .M_AXIS_CQ_TKEEP                                   (m_axis_cq_tkeep), 
         .M_AXIS_CQ_TUSER                                   (m_axis_cq_tuser), 
         
         .M_AXIS_RC_TVALID                                  (m_axis_rc_tvalid), 
         .M_AXIS_RC_TLAST                                   (m_axis_rc_tlast), 
         .M_AXIS_RC_TDATA                                   (m_axis_rc_tdata), 
         .M_AXIS_RC_TKEEP                                   (m_axis_rc_tkeep), 
         .M_AXIS_RC_TUSER                                   (m_axis_rc_tuser), 
         
         .S_AXIS_CC_TREADY                                  (s_axis_cc_tready), 
         .S_AXIS_RQ_TREADY                                  (s_axis_rq_tready), 
         
         .CFG_INTERRUPT_MSI_ENABLE                          (cfg_interrupt_msi_enable[1:0]), 
         .CFG_INTERRUPT_MSI_MASK_UPDATE                     (cfg_interrupt_msi_mask_update), 
         .CFG_INTERRUPT_MSI_DATA                            (cfg_interrupt_msi_data[31:0]), 
         .CFG_INTERRUPT_MSI_SENT                            (cfg_interrupt_msi_sent), 
         .CFG_INTERRUPT_MSI_FAIL                            (cfg_interrupt_msi_fail), 
         .CFG_FC_CPLH                                       (cfg_fc_cplh[7:0]), 
         .CFG_FC_CPLD                                       (cfg_fc_cpld[11:0]), 
         .CFG_NEGOTIATED_WIDTH                              (cfg_negotiated_width[3:0]),
         .CFG_CURRENT_SPEED                                 (cfg_current_speed[2:0]), 
         .CFG_MAX_PAYLOAD                                   (cfg_max_payload[2:0]), 
         .CFG_MAX_READ_REQ                                  (cfg_max_read_req[2:0]),
         .CFG_FUNCTION_STATUS                               (cfg_function_status[7:0]), 
         .CFG_RCB_STATUS                                    (cfg_rcb_status[1:0]), 
         
         .CHNL_RX_CLK                                       (chnl_rx_clk),
         .CHNL_RX_ACK                                       (chnl_rx_ack),
         .CHNL_RX_DATA_REN                                  (chnl_rx_data_ren),
         .CHNL_TX_CLK                                       (chnl_tx_clk),
         .CHNL_TX                                           (chnl_tx),
         .CHNL_TX_LAST                                      (chnl_tx_last),
         .CHNL_TX_LEN                                       (chnl_tx_len),
         .CHNL_TX_OFF                                       (chnl_tx_off),
         .CHNL_TX_DATA                                      (chnl_tx_data),
         .CHNL_TX_DATA_VALID                                (chnl_tx_data_valid)
         );

 // SUME AXIS attachment
 axis_sume_attachment_top #(
     .C_PCI_DATA_WIDTH                                      (C_PCI_DATA_WIDTH),     
     .C_AXIS_TDATA_WIDTH                                      (C_AXIS_TDATA_WIDTH),
     .C_AXIS_TKEEP_WIDTH                                      (C_AXIS_TKEEP_WIDTH),
     .C_AXIS_TUSER_WIDTH                                      (C_AXIS_TUSER_WIDTH),
     .C_PREAM_VALUE                                         (C_PREAM_VALUE)
 ) riffa_axis_attachment (
     // Riffa interfaces
     .CLK                                                   (user_clk),
     .RST                                                   (rst_out),
     
     .CHNL_RX_CLK                                           (chnl_rx_clk[axis_chnl_num_lp]), 
     .CHNL_RX                                               (chnl_rx[axis_chnl_num_lp]), 
     .CHNL_RX_ACK                                           (chnl_rx_ack[axis_chnl_num_lp]), 
     .CHNL_RX_LAST                                          (chnl_rx_last[axis_chnl_num_lp]), 
     .CHNL_RX_LEN                                           (chnl_rx_len[(`SIG_CHNL_LENGTH_W*axis_chnl_num_lp) +:32]), 
     .CHNL_RX_OFF                                           (chnl_rx_off[(`SIG_CHNL_OFFSET_W*axis_chnl_num_lp) +:31]), 
     .CHNL_RX_DATA                                          (chnl_rx_data[(C_PCI_DATA_WIDTH*axis_chnl_num_lp) +:C_PCI_DATA_WIDTH]), 
     .CHNL_RX_DATA_VALID                                    (chnl_rx_data_valid[axis_chnl_num_lp]), 
     .CHNL_RX_DATA_REN                                      (chnl_rx_data_ren[axis_chnl_num_lp]),
 
     .CHNL_TX_CLK                                           (chnl_tx_clk[axis_chnl_num_lp]), 
     .CHNL_TX                                               (chnl_tx[axis_chnl_num_lp]), 
     .CHNL_TX_ACK                                           (chnl_tx_ack[axis_chnl_num_lp]), 
     .CHNL_TX_LAST                                          (chnl_tx_last[axis_chnl_num_lp]), 
     .CHNL_TX_LEN                                           (chnl_tx_len[(`SIG_CHNL_LENGTH_W*axis_chnl_num_lp) +:32]), 
     .CHNL_TX_OFF                                           (chnl_tx_off[(`SIG_CHNL_OFFSET_W*axis_chnl_num_lp) +:31]), 
     .CHNL_TX_DATA                                          (chnl_tx_data[(C_PCI_DATA_WIDTH*axis_chnl_num_lp) +:C_PCI_DATA_WIDTH]), 
     .CHNL_TX_DATA_VALID                                    (chnl_tx_data_valid[axis_chnl_num_lp]), 
     .CHNL_TX_DATA_REN                                      (chnl_tx_data_ren[axis_chnl_num_lp]),  
 
     // XGE AXIS interfaces
    .m_axis_xge_tx_tdata                                    (m_axis_xge_tx_tdata),
    .m_axis_xge_tx_tkeep                                    (m_axis_xge_tx_tkeep), 
    .m_axis_xge_tx_tuser                                    (m_axis_xge_tx_tuser),
    .m_axis_xge_tx_tlast                                    (m_axis_xge_tx_tlast), 
    .m_axis_xge_tx_tvalid                                   (m_axis_xge_tx_tvalid), 
    .m_axis_xge_tx_tready                                   (m_axis_xge_tx_tready),            
    
    .s_axis_xge_rx_tdata                                    (s_axis_xge_rx_tdata), 
    .s_axis_xge_rx_tkeep                                    (s_axis_xge_rx_tkeep),
    .s_axis_xge_rx_tuser                                    (s_axis_xge_rx_tuser),
    .s_axis_xge_rx_tlast                                    (s_axis_xge_rx_tlast), 
    .s_axis_xge_rx_tvalid                                   (s_axis_xge_rx_tvalid),   
    .s_axis_xge_rx_tready                                   (s_axis_xge_rx_tready)
 );

//SUME AXI-Lite Attachment
riffa_axi_lite #(
    .C_PCI_DATA_WIDTH                                         (C_PCI_DATA_WIDTH),
    .C_M_AXI_LITE_ADDR_WIDTH                                  (C_M_AXI_LITE_ADDR_WIDTH),
    .C_M_AXI_LITE_DATA_WIDTH                                  (C_M_AXI_LITE_DATA_WIDTH),
    .C_M_AXI_LITE_STRB_WIDTH                                  (C_M_AXI_LITE_STRB_WIDTH)
) riffa_axi_lite_attachment (
    .CLK                                                      (user_clk),
    .RST                                                      (rst_out),
  
    .CHNL_RX_CLK                                              (chnl_rx_clk[axi_lite_chnl_num_lp]), 
    .CHNL_RX                                                  (chnl_rx[axi_lite_chnl_num_lp]), 
    .CHNL_RX_ACK                                              (chnl_rx_ack[axi_lite_chnl_num_lp]), 
    .CHNL_RX_LAST                                             (chnl_rx_last[axi_lite_chnl_num_lp]), 
    .CHNL_RX_LEN                                              (chnl_rx_len[(`SIG_CHNL_LENGTH_W*axi_lite_chnl_num_lp) +:32]), 
    .CHNL_RX_OFF                                              (chnl_rx_off[(`SIG_CHNL_OFFSET_W*axi_lite_chnl_num_lp) +:31]), 
    .CHNL_RX_DATA                                             (chnl_rx_data[(C_PCI_DATA_WIDTH*axi_lite_chnl_num_lp) +:C_PCI_DATA_WIDTH]), 
    .CHNL_RX_DATA_VALID                                       (chnl_rx_data_valid[axi_lite_chnl_num_lp]), 
    .CHNL_RX_DATA_REN                                         (chnl_rx_data_ren[axi_lite_chnl_num_lp]),
  
    .CHNL_TX_CLK                                              (chnl_tx_clk[axi_lite_chnl_num_lp]), 
    .CHNL_TX                                                  (chnl_tx[axi_lite_chnl_num_lp]), 
    .CHNL_TX_ACK                                              (chnl_tx_ack[axi_lite_chnl_num_lp]), 
    .CHNL_TX_LAST                                             (chnl_tx_last[axi_lite_chnl_num_lp]), 
    .CHNL_TX_LEN                                              (chnl_tx_len[(`SIG_CHNL_LENGTH_W*axi_lite_chnl_num_lp) +:32]), 
    .CHNL_TX_OFF                                              (chnl_tx_off[(`SIG_CHNL_OFFSET_W*axi_lite_chnl_num_lp) +:31]), 
    .CHNL_TX_DATA                                             (chnl_tx_data[(C_PCI_DATA_WIDTH*axi_lite_chnl_num_lp) +:C_PCI_DATA_WIDTH]), 
    .CHNL_TX_DATA_VALID                                       (chnl_tx_data_valid[axi_lite_chnl_num_lp]), 
    .CHNL_TX_DATA_REN                                         (chnl_tx_data_ren[axi_lite_chnl_num_lp]),
  
    //AXI-Lite interface 
    .m_axi_lite_aclk                                          (m_axi_lite_aclk),
    .m_axi_lite_aresetn                                       (m_axi_lite_aresetn),
  
    .m_axi_lite_arready                                       (m_axi_lite_arready),
    .m_axi_lite_arvalid                                       (m_axi_lite_arvalid),
    .m_axi_lite_araddr                                        (m_axi_lite_araddr),
    .m_axi_lite_arprot                                        (m_axi_lite_arprot),

    .m_axi_lite_rready                                        (m_axi_lite_rready),
    .m_axi_lite_rvalid                                        (m_axi_lite_rvalid),
    .m_axi_lite_rdata                                         (m_axi_lite_rdata),
    .m_axi_lite_rresp                                         (m_axi_lite_rresp),
      
    .m_axi_lite_awready                                       (m_axi_lite_awready),
    .m_axi_lite_awvalid                                       (m_axi_lite_awvalid),
    .m_axi_lite_awaddr                                        (m_axi_lite_awaddr),
    .m_axi_lite_awprot                                        (m_axi_lite_awprot),
  
    .m_axi_lite_wready                                        (m_axi_lite_wready),
    .m_axi_lite_wvalid                                        (m_axi_lite_wvalid),
    .m_axi_lite_wdata                                         (m_axi_lite_wdata),
    .m_axi_lite_wstrb                                         (m_axi_lite_wstrb),
    
    .m_axi_lite_bready                                        (m_axi_lite_bready),
    .m_axi_lite_bvalid                                        (m_axi_lite_bvalid),
    .m_axi_lite_bresp                                         (m_axi_lite_bresp),

    .md_error                                                 (md_error)
);


//Registers section
 nf_riffa_dma_cpu_regs 
 #(
     .C_BASE_ADDRESS        (C_BASEADDR ),
     .C_S_AXI_DATA_WIDTH    (C_S_AXI_DATA_WIDTH),
     .C_S_AXI_ADDR_WIDTH    (C_S_AXI_ADDR_WIDTH)
 ) nf_riffa_dma_cpu_regs_inst
 (   
   // General ports
    .clk                    (user_clk),
    .resetn                 (~user_reset),
   // AXI Lite ports
    .S_AXI_ACLK             (user_clk),
    .S_AXI_ARESETN          (~user_reset),
    .S_AXI_AWADDR           (s_axi_lite_awaddr),
    .S_AXI_AWVALID          (s_axi_lite_awvalid),
    .S_AXI_WDATA            (s_axi_lite_wdata),
    .S_AXI_WSTRB            (s_axi_lite_wstrb),
    .S_AXI_WVALID           (s_axi_lite_wvalid),
    .S_AXI_BREADY           (s_axi_lite_bready),
    .S_AXI_ARADDR           (s_axi_lite_araddr),
    .S_AXI_ARVALID          (s_axi_lite_arvalid),
    .S_AXI_RREADY           (s_axi_lite_rready),
    .S_AXI_ARREADY          (s_axi_lite_arready),
    .S_AXI_RDATA            (s_axi_lite_rdata),
    .S_AXI_RRESP            (s_axi_lite_rresp),
    .S_AXI_RVALID           (s_axi_lite_rvalid),
    .S_AXI_WREADY           (s_axi_lite_wready),
    .S_AXI_BRESP            (s_axi_lite_bresp),
    .S_AXI_BVALID           (s_axi_lite_bvalid),
    .S_AXI_AWREADY          (s_axi_lite_awready),
   
   // Register ports
   .id_reg          (id_reg),
   .version_reg          (version_reg),
   .reset_reg          (reset_reg),
   .ip2cpu_flip_reg          (ip2cpu_flip_reg),
   .cpu2ip_flip_reg          (cpu2ip_flip_reg),
   .ip2cpu_debug_reg          (ip2cpu_debug_reg),
   .cpu2ip_debug_reg          (cpu2ip_debug_reg),
   .rqpkt_reg          (rqpkt_reg),
   .rqpkt_reg_clear    (rqpkt_reg_clear),
   .rcpkt_reg          (rcpkt_reg),
   .rcpkt_reg_clear    (rcpkt_reg_clear),
   .cqpkt_reg          (cqpkt_reg),
   .cqpkt_reg_clear    (cqpkt_reg_clear),
   .ccpkt_reg          (ccpkt_reg),
   .ccpkt_reg_clear    (ccpkt_reg_clear),
   .xgetxpkt_reg          (xgetxpkt_reg),
   .xgetxpkt_reg_clear    (xgetxpkt_reg_clear),
   .xgerxpkt_reg          (xgerxpkt_reg),
   .xgerxpkt_reg_clear    (xgerxpkt_reg_clear),
   .pcierq_reg          (pcierq_reg),
   .pciephy_reg          (pciephy_reg),
   .pcieconfig_reg          (pcieconfig_reg),
   .pcieconfig2_reg          (pcieconfig2_reg),
   .pcieerror_reg          (pcieerror_reg),
   .pciemisc_reg          (pciemisc_reg),
   .pcietph_reg          (pcietph_reg),
   .pciefc1_reg          (pciefc1_reg),
   .pciefc2_reg          (pciefc2_reg),
   .pciefc3_reg          (pciefc3_reg),
   .pcieinterrupt_reg          (pcieinterrupt_reg),
   .pciemsidata_reg          (pciemsidata_reg),
   .pciemsiint_reg          (pciemsiint_reg),
   .pciemsipendingstatus_reg          (pciemsipendingstatus_reg),
   .pciemsipendingstatus2_reg          (pciemsipendingstatus2_reg),
   .pcieinterrupt2_reg          (pcieinterrupt2_reg),
   // Global Registers - user can select if to use
   .cpu_resetn_soft(),//software reset, after cpu module
   .resetn_soft    (),//software reset to cpu module (from central reset management)
   .resetn_sync    (resetn_sync)//synchronized reset, use for better timing
);


    assign     clear_counters = reset_reg[0];
    assign     reset_registers = reset_reg[4];


//registers logic, current logic is just a placeholder for initial compil, required to be changed by the user
always @(posedge user_clk)
	if (user_reset | reset_registers) begin
		id_reg <= #1    `REG_ID_DEFAULT;
		version_reg <= #1    `REG_VERSION_DEFAULT;
		ip2cpu_flip_reg <= #1    `REG_FLIP_DEFAULT;
		ip2cpu_debug_reg <= #1    `REG_DEBUG_DEFAULT;
		rqpkt_reg <= #1    `REG_RQPKT_DEFAULT;
		rcpkt_reg <= #1    `REG_RCPKT_DEFAULT;
		cqpkt_reg <= #1    `REG_CQPKT_DEFAULT;
		ccpkt_reg <= #1    `REG_CCPKT_DEFAULT;
		xgetxpkt_reg <= #1    `REG_XGETXPKT_DEFAULT;
		xgerxpkt_reg <= #1    `REG_XGERXPKT_DEFAULT;
		pcierq_reg <= #1    `REG_PCIERQ_DEFAULT;
		pciephy_reg <= #1    `REG_PCIEPHY_DEFAULT;
		pcieconfig_reg <= #1    `REG_PCIECONFIG_DEFAULT;
		pcieconfig2_reg <= #1    `REG_PCIECONFIG2_DEFAULT;
		pcieerror_reg <= #1    `REG_PCIEERROR_DEFAULT;
		pciemisc_reg <= #1    `REG_PCIEMISC_DEFAULT;
		pcietph_reg <= #1    `REG_PCIETPH_DEFAULT;
		pciefc1_reg <= #1    `REG_PCIEFC1_DEFAULT;
		pciefc2_reg <= #1    `REG_PCIEFC2_DEFAULT;
		pciefc3_reg <= #1    `REG_PCIEFC3_DEFAULT;
		pcieinterrupt_reg <= #1    `REG_PCIEINTERRUPT_DEFAULT;
		pciemsidata_reg <= #1    `REG_PCIEMSIDATA_DEFAULT;
		pciemsiint_reg <= #1    `REG_PCIEMSIINT_DEFAULT;
		pciemsipendingstatus_reg <= #1    `REG_PCIEMSIPENDINGSTATUS_DEFAULT;
		pciemsipendingstatus2_reg <= #1    `REG_PCIEMSIPENDINGSTATUS2_DEFAULT;
		pcieinterrupt2_reg <= #1    `REG_PCIEINTERRUPT2_DEFAULT;
	end
	else begin
		id_reg <= #1    `REG_ID_DEFAULT;
		version_reg <= #1    `REG_VERSION_DEFAULT;
		ip2cpu_flip_reg <= #1    ~cpu2ip_flip_reg;
		ip2cpu_debug_reg <= #1    `REG_DEBUG_DEFAULT+cpu2ip_debug_reg;
		              
		rqpkt_reg [`REG_RQPKT_WIDTH -2: 0] <= #1  clear_counters | rqpkt_reg_clear ? 'h0  : rqpkt_reg[`REG_RQPKT_WIDTH -2: 0] + (s_axis_rq_tlast && s_axis_rq_tvalid && s_axis_rq_tready) ;
		rqpkt_reg [`REG_RQPKT_WIDTH-1    ] <= #1  clear_counters | rqpkt_reg_clear ? 'h0  : rqpkt_reg[`REG_RQPKT_WIDTH-2:0] + (s_axis_rq_tlast && s_axis_rq_tvalid && s_axis_rq_tready)
				                                                     > {(`REG_RQPKT_WIDTH-1){1'b1}} ? 1'b1 : rqpkt_reg[`REG_RQPKT_WIDTH-1];
				                                                     
		rcpkt_reg [`REG_RCPKT_WIDTH -2: 0] <= #1  clear_counters | rcpkt_reg_clear ? 'h0  : rcpkt_reg[`REG_RCPKT_WIDTH -2: 0] + (m_axis_rc_tlast && m_axis_rc_tvalid && m_axis_rc_tready) ;
		rcpkt_reg [`REG_RCPKT_WIDTH-1    ] <= #1  clear_counters | rcpkt_reg_clear ? 'h0  : rcpkt_reg[`REG_RCPKT_WIDTH-2:0] + (m_axis_rc_tlast && m_axis_rc_tvalid && m_axis_rc_tready)
						                                                     > {(`REG_RCPKT_WIDTH-1){1'b1}} ? 1'b1 : rcpkt_reg[`REG_RCPKT_WIDTH-1];
						                                                     
		cqpkt_reg [`REG_CQPKT_WIDTH -2: 0] <= #1  clear_counters | cqpkt_reg_clear ? 'h0  : cqpkt_reg[`REG_CQPKT_WIDTH -2: 0] + (m_axis_cq_tlast && m_axis_cq_tvalid && m_axis_cq_tready) ;
		cqpkt_reg [`REG_CQPKT_WIDTH-1    ] <= #1  clear_counters | cqpkt_reg_clear ? 'h0  : cqpkt_reg[`REG_CQPKT_WIDTH-2:0] + (m_axis_cq_tlast && m_axis_cq_tvalid && m_axis_cq_tready)
						                                                     > {(`REG_CQPKT_WIDTH-1){1'b1}} ? 1'b1 : cqpkt_reg[`REG_CQPKT_WIDTH-1];
				                                                     
		ccpkt_reg [`REG_CCPKT_WIDTH -2: 0] <= #1  clear_counters | ccpkt_reg_clear ? 'h0  : ccpkt_reg[`REG_CCPKT_WIDTH -2: 0] + (s_axis_cc_tlast && s_axis_cc_tvalid && s_axis_cc_tready) ;
		ccpkt_reg [`REG_CCPKT_WIDTH-1    ] <= #1  clear_counters | ccpkt_reg_clear ? 'h0  : ccpkt_reg[`REG_CCPKT_WIDTH-2:0] + (s_axis_cc_tlast && s_axis_cc_tvalid && s_axis_cc_tready)
				                                                     > {(`REG_CCPKT_WIDTH-1){1'b1}} ? 1'b1 : ccpkt_reg[`REG_CCPKT_WIDTH-1];
	
		xgetxpkt_reg [`REG_XGETXPKT_WIDTH -2: 0] <= #1  clear_counters | xgetxpkt_reg_clear ? 'h0  : xgetxpkt_reg[`REG_XGETXPKT_WIDTH -2: 0] + (m_axis_xge_tx_tlast && m_axis_xge_tx_tvalid && m_axis_xge_tx_tready) ;
		xgetxpkt_reg [`REG_XGETXPKT_WIDTH-1    ] <= #1  clear_counters | xgetxpkt_reg_clear ? 'h0  : xgetxpkt_reg[`REG_XGETXPKT_WIDTH-2:0] + (m_axis_xge_tx_tlast && m_axis_xge_tx_tvalid && m_axis_xge_tx_tready) > {(`REG_XGETXPKT_WIDTH-1){1'b1}} ? 1'b1 : xgetxpkt_reg[`REG_XGETXPKT_WIDTH-1];
						                                                     
		xgerxpkt_reg [`REG_XGERXPKT_WIDTH -2: 0] <= #1  clear_counters | xgerxpkt_reg_clear ? 'h0  : xgerxpkt_reg[`REG_XGERXPKT_WIDTH -2: 0] + (s_axis_xge_rx_tlast && s_axis_xge_rx_tvalid && s_axis_xge_rx_tready) ;
		xgerxpkt_reg [`REG_XGERXPKT_WIDTH-1    ] <= #1  clear_counters | xgerxpkt_reg_clear ? 'h0  : xgerxpkt_reg[`REG_XGERXPKT_WIDTH-2:0] + (s_axis_xge_rx_tlast && s_axis_xge_rx_tvalid && s_axis_xge_rx_tready)> {(`REG_XGERXPKT_WIDTH-1){1'b1}} ? 1'b1 : xgerxpkt_reg[`REG_XGERXPKT_WIDTH-1];
						                                                     
		pcierq_reg [3:0]   <= #1    pcie_rq_seq_num_vld ? pcie_rq_seq_num : pcierq_reg [3:0];
		pcierq_reg [20:16] <= #1    pcie_rq_tag_vld ? pcie_rq_tag : pcierq_reg [20:16];
		
		pciephy_reg [2:0] <= #1   {cfg_phy_link_status,cfg_phy_link_down};
		pciephy_reg [19:16] <= #1   cfg_negotiated_width;
		
		pcieconfig_reg [2:0] <= #1     cfg_current_speed;
		pcieconfig_reg [6:4] <= #1     cfg_max_payload;
		pcieconfig_reg [10:8] <= #1     cfg_max_read_req;
		pcieconfig_reg [19:12] <= #1     cfg_function_status;
		pcieconfig_reg [25:20] <= #1     cfg_function_power_state;
		pcieconfig_reg [29:28] <= #1     cfg_link_power_state;
		
		pcieconfig2_reg [11:0] <= #1    cfg_vf_status;
		pcieconfig2_reg [29:12] <= #1    cfg_vf_power_state;		
		
		pcieerror_reg [0] <= #1    cfg_err_cor_out;
		pcieerror_reg [4] <= #1    cfg_err_nonfatal_out;
		pcieerror_reg [8] <= #1    cfg_err_fatal_out;

				
		pciemisc_reg [5:0]  <= #1    cfg_ltssm_state;
		pciemisc_reg [8]    <= #1    cfg_ltr_enable;
		pciemisc_reg [13:12]<= #1    cfg_rcb_status;		
		pciemisc_reg [17:16]<= #1    cfg_dpa_substate_change;
		pciemisc_reg [20]   <= #1    cfg_obff_enable;
		pciemisc_reg [24]   <= #1    cfg_pl_status_change;		
		
		pcietph_reg[1:0] <= #1    cfg_tph_requester_enable;
		pcietph_reg[7:2] <= #1    cfg_tph_st_mode;
		pcietph_reg[13:8] <= #1    cfg_vf_tph_requester_enable;
		pcietph_reg[31:14] <= #1    cfg_vf_tph_st_mode;					
		
		pciefc1_reg [7:0] <= #1    cfg_fc_ph;
		pciefc1_reg [19:8] <= #1    cfg_fc_pd;
		
		pciefc2_reg [7:0] <= #1    cfg_fc_nph;
		pciefc2_reg [19:8] <= #1    cfg_fc_npd;
		
		pciefc3_reg [7:0] <= #1    cfg_fc_cplh;
		pciefc3_reg [19:8] <= #1    cfg_fc_cpld;
		pciefc3_reg [22:20] <= #1    cfg_fc_sel;
		

		pcieinterrupt_reg [3:0] <= #1    cfg_interrupt_int;
		pcieinterrupt_reg [5:4] <= #1    cfg_interrupt_pending;
		pcieinterrupt_reg [8] <= #1    cfg_interrupt_sent;
		pcieinterrupt_reg [13:12] <= #1    cfg_interrupt_msi_enable;
		pcieinterrupt_reg [21:16] <= #1    cfg_interrupt_msi_vf_enable;
		pcieinterrupt_reg [29:24] <= #1    cfg_interrupt_msi_mmenable;
		pcieinterrupt_reg [31] <= #1    cfg_interrupt_msi_mask_update;
		
		pciemsidata_reg <= #1     cfg_interrupt_msi_data;
		
		pciemsiint_reg <= #1    cfg_interrupt_msi_int;
		
		pciemsipendingstatus_reg <= #1    cfg_interrupt_msi_pending_status[31:0];
		pciemsipendingstatus2_reg <= #1   cfg_interrupt_msi_pending_status[63:32];
		
		pcieinterrupt2_reg [3:0]  <= #1   cfg_interrupt_msi_select;
		pcieinterrupt2_reg [4]  <= #1   cfg_interrupt_msi_sent;
		pcieinterrupt2_reg [5]  <= #1   cfg_interrupt_msi_fail;
		pcieinterrupt2_reg [10:8]  <= #1   cfg_interrupt_msi_attr;
		pcieinterrupt2_reg [12]  <= #1   cfg_interrupt_msi_tph_present;
		pcieinterrupt2_reg [14:13]  <= #1   cfg_interrupt_msi_tph_type;
		pcieinterrupt2_reg [24:16]  <= #1   cfg_interrupt_msi_tph_st_tag;
		pcieinterrupt2_reg [30:28]  <= #1   cfg_interrupt_msi_function_number;
		
    end

    
endmodule
