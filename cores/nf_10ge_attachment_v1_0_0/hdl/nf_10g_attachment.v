//
// Copyright (c) 2015 James Hongyi Zeng, Yury Audzevich
// Copyright (c) 2016 Jong Hun Han
// All rights reserved.
// 
// Description:
//        10g ethernet attachment implements clock and data conversion
//        similarly to the nf10 (Virtex-5 based) interface.
//
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
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more
// contributor license agreements.  See the NOTICE file distributed with this
// work for additional information regarding copyright ownership.  NetFPGA
// licenses this file to you under the NetFPGA Hardware-Software License,
// Version 1.0 (the "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@


`timescale 1ps / 1ps

module nf_10g_attachment #(
    // Master AXI Stream Data Width    
    parameter C_M_AXIS_DATA_WIDTH       = 256,
    parameter C_S_AXIS_DATA_WIDTH       = 256,
    parameter C_M_AXIS_TUSER_WIDTH      = 128,
    parameter C_S_AXIS_TUSER_WIDTH      = 128,    
    parameter C_DEFAULT_VALUE_ENABLE    = 1,
    parameter C_DEFAULT_SRC_PORT        = 0,
    parameter C_DEFAULT_DST_PORT        = 0        
) (
  // 10GE block clk & rst 
  input                                 clk156, 
  input                                 areset_clk156, 
  
  // RX MAC 64b@clk156 (no backpressure) -> rx_queue 64b@axis_clk
  input [63:0]        			        m_axis_mac_tdata,
  input [7:0]    			            m_axis_mac_tkeep,
  input	                                m_axis_mac_tvalid, 
  input		                            m_axis_mac_tuser,       // valid frame
  input                                 m_axis_mac_tlast,
  

  // tx_queue 64b@axis_clk -> mac 64b@clk156
  output [63:0]       			        s_axis_mac_tdata,
  output [7:0]   			            s_axis_mac_tkeep,
  output                                s_axis_mac_tvalid,
  output                                s_axis_mac_tuser,      //underrun
  output                                s_axis_mac_tlast,	
  input                                 s_axis_mac_tready,
   
   
  // TX/RX DATA channels  
  input [7:0]                           interface_number,
  
  // SUME pipeline clk & rst 
  input                                 axis_aclk,
  input                                 axis_aresetn,
     
  // input from ref pipeline 256b -> MAC
  input [C_S_AXIS_DATA_WIDTH-1:0]       s_axis_pipe_tdata, 
  input [(C_S_AXIS_DATA_WIDTH/8)-1:0]   s_axis_pipe_tkeep, 
  input                                 s_axis_pipe_tlast, 
  input [C_S_AXIS_TUSER_WIDTH-1:0]      s_axis_pipe_tuser, 
  input                                 s_axis_pipe_tvalid,
  output                                s_axis_pipe_tready,
   
  // output to ref pipeline 256b -> DMA
  output [C_M_AXIS_DATA_WIDTH-1:0]      m_axis_pipe_tdata, 
  output [(C_M_AXIS_DATA_WIDTH/8)-1:0]  m_axis_pipe_tkeep, 
  output                                m_axis_pipe_tlast, 
  output [C_M_AXIS_TUSER_WIDTH-1:0]     m_axis_pipe_tuser, 
  output                                m_axis_pipe_tvalid,
  input                                 m_axis_pipe_tready
  
   
 );


 /////////////////////////////////////////////////////////////////////   
 // localparam 
 /////////////////////////////////////////////////////////////////////
 localparam C_M_AXIS_DATA_WIDTH_INTERNAL    = 64;
 localparam C_S_AXIS_DATA_WIDTH_INTERNAL    = 64;    
 
 localparam NUM_RW_REGS                     = 1;
 localparam NUM_RO_REGS                     = 17;
 
 // localparam for now, should be params
  // AXI Data Width
 localparam C_S_AXI_DATA_WIDTH              = 32;          
 localparam C_S_AXI_ADDR_WIDTH              = 32;          
 localparam C_USE_WSTRB                     = 0;
 
 /////////////////////////////////////////////////////////////////////
 // signals
 /////////////////////////////////////////////////////////////////////

 // rx_queue -> AXIS_converter
wire [C_M_AXIS_DATA_WIDTH_INTERNAL-1:0]        m_axis_fifo_tdata;
wire [(C_M_AXIS_DATA_WIDTH_INTERNAL/8)-1:0]    m_axis_fifo_tkeep;
wire                                           m_axis_fifo_tvalid;
wire                                           m_axis_fifo_tready;
wire                                           m_axis_fifo_tlast;  
  
 // AXIS_converter 64b@axis_clk -> tx_queue@axis_clk  
wire [C_S_AXIS_DATA_WIDTH_INTERNAL-1:0]        s_axis_fifo_tdata;
wire [(C_S_AXIS_DATA_WIDTH_INTERNAL/8)-1:0]    s_axis_fifo_tkeep;
wire [C_S_AXIS_TUSER_WIDTH-1:0]                s_axis_fifo_tuser;
wire                                           s_axis_fifo_tvalid;
wire                                           s_axis_fifo_tready;
wire                                           s_axis_fifo_tlast;   
  
 ////////////////////////////////////////////////////////////////
 // 10g interface statistics
 // TODO: Send through AXI-Lite interface
 //////////////////////////////////////////////////////////////// 
 
  // tx_queues  
  wire                                          tx_dequeued_pkt; //
  wire                                          tx_pkts_enqueued_signal;//
  wire [15:0]                                   tx_bytes_enqueued;//
  wire                                          be; //
   
   /////////////////////////////////////////////////////////////////////////////
   /////////////// DATA WIDTH conversion logic   ///////////////// 
   /////////////////////////////////////////////////////////////////////////////

   /////////////////////////////////////////////////////////////////////////////
   /////////////// RX SIDE MAC -> DMA: FIFO + AXIS_CONV         ///////////////// 
   /////////////////////////////////////////////////////////////////////////////
   // Internal FIFO resets for clk domain crossing 
   wire                                            areset_rx_fifo_extended;
   wire                                            areset_tx_fifo_extended; 	

   // FIFO36_72 primitive rst extension rx
   data_sync_block #(
     .C_NUM_SYNC_REGS                     (6)
   ) rx_fifo_rst (
     .clk                                 (axis_aclk),
     .data_in                             (~axis_aresetn),
     .data_out                            (areset_rx_fifo_extended)
   );
   
   // FIFO36_72 primitive rst extension tx
   data_sync_block #(
     .C_NUM_SYNC_REGS                     (6)
   ) tx_fifo_rst (
     .clk                                 (axis_aclk),
     .data_in                             (~axis_aresetn),
     .data_out                            (areset_tx_fifo_extended)
   );     

 
   //-------------------------------------------------------------------------
   // RX queue: 64b@clk ->64b@axis_clk conversion. 
   // Creates a backpressure to the interface (axi ethernet block doesn't have tready signal).
   // IMPORTANT: FIFO36_72 requires rst to be asserted for at least 5 clks. RDEN and WREN 
   // should be ONLY 1'b0 at that time. 
   //-------------------------------------------------------------------------  
   rx_queue #(
     .AXI_DATA_WIDTH                      (C_M_AXIS_DATA_WIDTH_INTERNAL)
    ) rx_fifo_intf (
    // MAC input 64b@clk156
    .clk156                               (clk156),
    .areset_clk156                        (areset_clk156),
       
    .i_tdata                              (m_axis_mac_tdata),
    .i_tkeep                              (m_axis_mac_tkeep),
    .i_tuser                              (m_axis_mac_tuser),
    .i_tvalid                             (m_axis_mac_tvalid),
    .i_tlast                              (m_axis_mac_tlast),
       
    // FIFO output 64b@axi_aclk
    .clk                                  (axis_aclk),
    .reset                                (areset_rx_fifo_extended), 
            
    .o_tdata                              (m_axis_fifo_tdata),
    .o_tkeep                              (m_axis_fifo_tkeep),
    .o_tvalid                             (m_axis_fifo_tvalid),
    .o_tlast                              (m_axis_fifo_tlast),
    .o_tready                             (m_axis_fifo_tready),
    
    // interface statistics
    .fifo_wr_en                           (fifo_wr_en),
    .rx_pkt_drop                          (rx_pkt_drop),
    .rx_bad_frame                         (rx_bad_frame), 
    .rx_good_frame                        (rx_good_frame)  
   ); 
   
   //--------------------------------------------------------------------------
   // 64b to 256b axis converter RX SIDE (rx_queue FIFO -> DMA): 
   // (AXIS mac_64b@axis_clk -> AXIS conv_256b@axis_clk with TUSER)  
   //--------------------------------------------------------------------------
   nf_axis_converter
   #(
    .C_M_AXIS_DATA_WIDTH                  (C_M_AXIS_DATA_WIDTH),
    .C_S_AXIS_DATA_WIDTH                  (C_M_AXIS_DATA_WIDTH_INTERNAL),  
    .C_M_AXIS_TUSER_WIDTH                 (C_M_AXIS_TUSER_WIDTH),
    .C_S_AXIS_TUSER_WIDTH                 (C_S_AXIS_TUSER_WIDTH), 
            
    .C_DEFAULT_VALUE_ENABLE               (C_DEFAULT_VALUE_ENABLE), // USE C_DEFAULT_VALUE_ENABLE = 1
    .C_DEFAULT_SRC_PORT                   (C_DEFAULT_SRC_PORT),
    .C_DEFAULT_DST_PORT                   (C_DEFAULT_DST_PORT)  
   ) converter_rx (     
    .axi_aclk                             (axis_aclk),
    .axi_resetn                           (~areset_rx_fifo_extended),
              
    .interface_number                     (interface_number),
      
    // Slave Ports (Input 64b from AXIS_FIFO)
    .s_axis_tdata                         (m_axis_fifo_tdata),
    .s_axis_tkeep                         (m_axis_fifo_tkeep),
    .s_axis_tvalid                        (m_axis_fifo_tvalid),
    .s_axis_tready                        (m_axis_fifo_tready), 
    .s_axis_tlast                         (m_axis_fifo_tlast),
    .s_axis_tuser                         (128'h0),            
      
    // Master Ports (Output 256b to outside)
    .m_axis_tdata                         (m_axis_pipe_tdata),
    .m_axis_tkeep                         (m_axis_pipe_tkeep),
    .m_axis_tvalid                        (m_axis_pipe_tvalid),
    .m_axis_tready                        (m_axis_pipe_tready), 
    .m_axis_tlast                         (m_axis_pipe_tlast),
    .m_axis_tuser                         (m_axis_pipe_tuser) // sideband tuser 128b 
   );

    /////////////////////////////////////////////////////////////////////////////
    /////////////// TX SIDE DMA -> MAC: AXIS_CONV + FIFO      ///////////////// 
    /////////////////////////////////////////////////////////////////////////////  
    
    //--------------------------------------------------------------------------
    // 256b to 64b axis converter TX SIDE (Outside -> AXIS_CONV):
    // (AXIS 256b@axi_aclk -> AXIS 64b@axis_aclk)
    // C_DEFAULT_VALUE_ENABLE = 0 -- bypass tuser field logic
    //--------------------------------------------------------------------------
    nf_axis_converter #(
     .C_M_AXIS_DATA_WIDTH                (C_S_AXIS_DATA_WIDTH_INTERNAL),
     .C_S_AXIS_DATA_WIDTH                (C_S_AXIS_DATA_WIDTH),
     .C_DEFAULT_VALUE_ENABLE             (1'b0) 
    ) converter_tx (    
     .axi_aclk                           (axis_aclk),
     .axi_resetn                         (~areset_tx_fifo_extended),
                
     .interface_number                   (interface_number),
            
     // Slave Ports (Input 256b from DMA)
     .s_axis_tdata                       (s_axis_pipe_tdata),
     .s_axis_tkeep                       (s_axis_pipe_tkeep),
     .s_axis_tvalid                      (s_axis_pipe_tvalid),
     .s_axis_tready                      (s_axis_pipe_tready),
     .s_axis_tlast                       (s_axis_pipe_tlast),
     .s_axis_tuser                       (s_axis_pipe_tuser),
            
     // Master Ports (Output 64b to AXIS_FIFO)
     .m_axis_tdata                       (s_axis_fifo_tdata),
     .m_axis_tkeep                       (s_axis_fifo_tkeep),
     .m_axis_tvalid                      (s_axis_fifo_tvalid),
     .m_axis_tready                      (s_axis_fifo_tready),
     .m_axis_tlast                       (s_axis_fifo_tlast),
     .m_axis_tuser                       (s_axis_fifo_tuser)        
    );
        
    //-------------------------------------------------------------------------
    // TX queue: 64b@axis_clk -> 64b@clk conversion. 
    // TODO : add FSM from the original block for AXI-Lite interfaces
    // IMPORTANT: FIFO36_72 requires rst to be asserted for at least 5 clks. 
    // RDEN and WREN should be ONLY 1'b0 at that time. 
    //------------------------------------------------------------------------- 
    tx_queue #(
     .AXI_DATA_WIDTH                     (C_S_AXIS_DATA_WIDTH_INTERNAL), 
     .C_S_AXIS_TUSER_WIDTH               (C_S_AXIS_TUSER_WIDTH)
    ) tx_fifo_intf (    
      // AXIS input 64b @axis_clk    
     .clk                                (axis_aclk),
     .reset                              (areset_tx_fifo_extended),
          
     .i_tuser                            (s_axis_fifo_tuser),
     .i_tdata                            (s_axis_fifo_tdata),
     .i_tkeep                            (s_axis_fifo_tkeep),
     .i_tvalid                           (s_axis_fifo_tvalid),
     .i_tlast                            (s_axis_fifo_tlast),
     .i_tready                           (s_axis_fifo_tready),
      
      // AXIS MAC output 64b @156MHz      
     .clk156                             (clk156),
    .areset_clk156                        (areset_clk156),
     
     .o_tdata                            (s_axis_mac_tdata),
     .o_tkeep                            (s_axis_mac_tkeep),
     .o_tvalid                           (s_axis_mac_tvalid),
     .o_tlast                            (s_axis_mac_tlast),
     .o_tuser                            (s_axis_mac_tuser),
     .o_tready                           (s_axis_mac_tready),
        
     // sideband data
     .tx_dequeued_pkt                    (tx_dequeued_pkt),
     .be                                 (be),  
     .tx_pkts_enqueued_signal            (tx_pkts_enqueued_signal),
     .tx_bytes_enqueued                  (tx_bytes_enqueued)      
     );
  
  //-------------------------------------------------------------------------
  // AXI-Lite registers 
  // TODO : AXI-lite slave interface (not ipif) 
  //------------------------------------------------------------------------- 
         
  
  //------------------------------------------------------------
  // 10g interface statistics
  //------------------------------------------------------------
 
  // ya -- registers are not used in current release ---//



endmodule
