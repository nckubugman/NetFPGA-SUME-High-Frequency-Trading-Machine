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
//  Description:
//  AXIS XGE && AXI4-Lite Attachement to RIFFA DMA. 
//  Uses two channels for transactions:
//  CHNL0: AXIS converter tx/rx, scans for metadata; converts it into tuser and
//  vice versa.
//  CHNL1: AXI-Lite, uses a specific field to distinguish bw wr/rd.
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

`timescale 1ns/1ns
//`default_nettype none  //ya
module axis_sume_attachment_top #(
    parameter C_PCI_DATA_WIDTH  = 128, 	
    parameter C_AXIS_TDATA_WIDTH = 128,
    parameter C_AXIS_TKEEP_WIDTH = (C_AXIS_TDATA_WIDTH/8),
    parameter C_AXIS_TUSER_WIDTH = 128,
    parameter C_PREAM_VALUE	    = 32'hCAFE	

)(

    // RIFFA interfaces
	input wire                              CLK,
	input wire                              RST,

	output wire                             CHNL_RX_CLK,            
    input wire                              CHNL_RX,                
	output wire                             CHNL_RX_ACK,            
	input wire                              CHNL_RX_LAST,            
	input wire [31:0]                       CHNL_RX_LEN,            
	input wire [30:0]                       CHNL_RX_OFF,                
	input wire [(C_PCI_DATA_WIDTH-1):0]     CHNL_RX_DATA,           
	input wire                              CHNL_RX_DATA_VALID,     
	output wire                             CHNL_RX_DATA_REN,       	
	output wire                             CHNL_TX_CLK, 
	output wire                             CHNL_TX, 
	input wire                              CHNL_TX_ACK, 
	output wire                             CHNL_TX_LAST, 
	output wire [31:0]                      CHNL_TX_LEN, 
	output wire [30:0]                      CHNL_TX_OFF, 
	output wire [(C_PCI_DATA_WIDTH-1):0]    CHNL_TX_DATA, 
	output wire                             CHNL_TX_DATA_VALID, 
   	input wire                              CHNL_TX_DATA_REN,


    // XGE AXIS interfaces
  	output wire [(C_AXIS_TDATA_WIDTH-1):0]  m_axis_xge_tx_tdata,
  	output wire [(C_AXIS_TKEEP_WIDTH-1):0]  m_axis_xge_tx_tkeep, 
  	output wire [(C_AXIS_TUSER_WIDTH-1):0]  m_axis_xge_tx_tuser,
  	output wire                             m_axis_xge_tx_tlast, 
  	output wire                             m_axis_xge_tx_tvalid, 
  	input wire                              m_axis_xge_tx_tready,			

	input wire [(C_AXIS_TDATA_WIDTH-1):0]   s_axis_xge_rx_tdata, 
  	input wire [(C_AXIS_TKEEP_WIDTH-1):0]   s_axis_xge_rx_tkeep,
  	input wire [(C_AXIS_TUSER_WIDTH-1):0]   s_axis_xge_rx_tuser,
  	input wire  		                    s_axis_xge_rx_tlast, 
  	input wire                              s_axis_xge_rx_tvalid,   
  	output wire                             s_axis_xge_rx_tready
);

////// RIFFA INTERFACE DESC (please see, riffa.ucsd.edu) //////
//CHNL_RX_CLK  (O) - Provide the clock signal to read data from the incoming FIFO.
//CHNL_RX      (I) - Goes high to signal incoming data. Will remain high until all 
//                   incoming data is written to the FIFO.
//CHNL_RX_ACK  (O) - Must be pulsed high for at least 1 cycle to acknowledge the 
//                   incoming data transaction.
//CHNL_RX_LAST (I) - High indicates this is the last receive transaction in a sequence.
//CHNL_RX_LEN  (I) - Length of receive transaction in 4 byte words.
//CHNL_RX_OFF  (I) - Offset in 4 byte words indicating where to start storing received 
//                   data (if applicable in design).
//CHNL_RX_DATA (I) - Receive data.
//CHNL_RX_DATA_VALID (I) - High if the data on CHNL_RX_DATA is valid.
//CHNL_RX_DATA_REN (O) -   When high and CHNL_RX_DATA_VALID is high, consumes the data 
//                         currently available on CHNL_RX_DATA.
//
//CHNL_TX_CLK  (O) - Provide the clock signal to write data to the outgoing FIFO. 
//CHNL_TX      (O) - Set high to signal a transaction. Keep high until all outgoing 
//                   data is written to the FIFO.
//CHNL_TX_ACK  (I) - Will be pulsed high for at least 1 cycle to acknowledge the transaction.
//CHNL_TX_LAST (O) - High indicates this is the last send transaction in a sequence.
//CHNL_TX_LEN] (O) - Length of send transaction in 4 byte words. 
//CHNL_TX_OFF  (O) - Offset in 4 byte words indicating where to start storing sent data in 
//                   the PC thread's receive buffer.
//CHNL_TX_DATA (O) - Send data.
//CHNL_TX_DATA_VALID (O) - Set high when the data on CHNL_TX_DATA valid. Update when 
//                         CHNL_TX_DATA is consumed.
//CHNL_TX_DATA_REN   (I) - When high and CHNL_TX_DATA_VALID is high, consumes the data currently 
//                         available on CHNL_TX_DATA.
////////

//////////////////////////////////////////////////////
// functions
//////////////////////////////////////////////////////


//////////////////////////////////////////////////////
// localparams
//////////////////////////////////////////////////////
localparam C_M_AXIS_DATA_WIDTH_INTERNAL	= C_PCI_DATA_WIDTH;
localparam C_M_AXIS_DATA_WIDTH		    = C_AXIS_TDATA_WIDTH;
localparam C_M_AXIS_TUSER_WIDTH		    = C_AXIS_TUSER_WIDTH;

localparam C_S_AXIS_DATA_WIDTH_INTERNAL	= C_PCI_DATA_WIDTH;
localparam C_S_AXIS_DATA_WIDTH		    = C_AXIS_TDATA_WIDTH;
localparam C_S_AXIS_TUSER_WIDTH		    = C_AXIS_TUSER_WIDTH;

/////////////////////////////////////////////////////
// signals
/////////////////////////////////////////////////////
// 128b AXIS @ riffa_clk: -> 256b AXIS @ riffa_clk
wire [(C_M_AXIS_DATA_WIDTH_INTERNAL-1):0]   	    m_axis_tdata_128;
wire [(C_M_AXIS_DATA_WIDTH_INTERNAL/8)-1:0]   	m_axis_tkeep_128;
wire [(C_M_AXIS_TUSER_WIDTH-1):0]   		        m_axis_tuser_128;
wire		               			            m_axis_tvalid_128;
wire		               			            m_axis_tready_128;
wire  			       			                m_axis_tlast_128;


// 256b AXIS @ riffa_clk -> 128b AXIS @ riffa_clk
wire [(C_S_AXIS_DATA_WIDTH_INTERNAL-1):0]   	s_axis_tdata_128;
wire [((C_S_AXIS_DATA_WIDTH_INTERNAL/8)-1):0]   s_axis_tkeep_128;
wire [(C_S_AXIS_TUSER_WIDTH-1):0]   		    s_axis_tuser_128;
wire		               			            s_axis_tvalid_128;
wire		               		                s_axis_tready_128;
wire  			       		            	s_axis_tlast_128;

/////////////////////////////////////////////////////
// assignments
///////////////////////////////////////////////////// 
assign CHNL_RX_CLK = CLK;
assign CHNL_TX_CLK = CLK;

///////////////////////////////////////////////////////
// RIFFA -> AXIS (TX)
///////////////////////////////////////////////////////
tx_riffa_axi 
#(
  .C_PCI_DATA_WIDTH         (C_PCI_DATA_WIDTH),
  .C_PREAM_VALUE            (C_PREAM_VALUE)
) riffa_to_axis_conv (
  .CLK                      (CLK),
  .RST                      (RST),

  .CHNL_RX                  (CHNL_RX),
  .CHNL_RX_DATA             (CHNL_RX_DATA),
  .CHNL_RX_DATA_VALID       (CHNL_RX_DATA_VALID),
  .CHNL_RX_LAST             (CHNL_RX_LAST),
  .CHNL_RX_LEN              (CHNL_RX_LEN),
  .CHNL_RX_OFF              (CHNL_RX_OFF),
  .CHNL_RX_DATA_REN         (CHNL_RX_DATA_REN),
  .CHNL_RX_ACK              (CHNL_RX_ACK),

  .tdata                    (m_axis_tdata_128),
  .tkeep                    (m_axis_tkeep_128),
  .tuser                    (m_axis_tuser_128),
  .tvalid                   (m_axis_tvalid_128),
  .tlast                    (m_axis_tlast_128),
  .tready                   (m_axis_tready_128)  
);

assign m_axis_xge_tx_tdata = m_axis_tdata_128;
assign m_axis_xge_tx_tkeep = m_axis_tkeep_128; 
assign m_axis_xge_tx_tuser = m_axis_tuser_128;
assign m_axis_xge_tx_tlast = m_axis_tlast_128; 
assign m_axis_xge_tx_tvalid = m_axis_tvalid_128;
assign m_axis_tready_128 = m_axis_xge_tx_tready;

//////////////////////////////
// AXIS -> RIFFA (RX)
//////////////////////////////

// AXIS -> RIFFA
rx_axi_riffa 
#(
  .C_PCI_DATA_WIDTH         (C_PCI_DATA_WIDTH),
  .C_RIFFA_OFFSET           (31'd0),
  .C_PREAM_VALUE            (C_PREAM_VALUE)
) axis_to_riffa_conv (
  .CLK                      (CLK),
  .RST                      (RST),

  .CHNL_TX                  (CHNL_TX),
  .CHNL_TX_DATA             (CHNL_TX_DATA),
  .CHNL_TX_DATA_VALID       (CHNL_TX_DATA_VALID),
  .CHNL_TX_LAST             (CHNL_TX_LAST),
  .CHNL_TX_LEN              (CHNL_TX_LEN),
  .CHNL_TX_OFF              (CHNL_TX_OFF),
  .CHNL_TX_DATA_REN         (CHNL_TX_DATA_REN),
  .CHNL_TX_ACK              (CHNL_TX_ACK),

  .tdata                    (s_axis_tdata_128),
  .tkeep                    (s_axis_tkeep_128),
  .tuser                    (s_axis_tuser_128),
  .tvalid                   (s_axis_tvalid_128),
  .tlast                    (s_axis_tlast_128),
  .tready                   (s_axis_tready_128)
);

///////////////////////////////////////////////////
///////////////////////////////////////////////////
assign s_axis_tdata_128 = s_axis_xge_rx_tdata;
assign s_axis_tkeep_128 = s_axis_xge_rx_tkeep;
assign s_axis_tuser_128 = s_axis_xge_rx_tuser;
assign s_axis_tvalid_128 = s_axis_xge_rx_tvalid;
assign s_axis_tlast_128 = s_axis_xge_rx_tlast;
assign s_axis_xge_rx_tready = s_axis_tready_128;

endmodule
