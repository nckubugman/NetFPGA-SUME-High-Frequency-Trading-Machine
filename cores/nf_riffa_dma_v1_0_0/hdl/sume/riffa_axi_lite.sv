//-
// Copyright (c) 2015 Sergio Lopez-Buedo
// All rights reserved.
//
//  File:
//        axis_sume_attachment_top.v
//
//  Author: Sergio Lopez-Buedo
//
//  Description:
//  AXI-Lite attachment. 
//  Host application send Write and Read frames
//  of different length with tkeep length encoded.
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

//`default_nettype none
`define C_RD_REQ 1'b0
`define C_WR_REQ 1'b1

`define ADDR_RANGE 31:0
`define DATA_RANGE 63:32
`define TAG_RANGE 95:64
`define STRB_RANGE 99:96
`define REQ_TYPE_RANGE 100
`define RESP_RANGE 102:101


module riffa_axi_lite #(
  parameter integer C_PCI_DATA_WIDTH = 128,
  parameter integer C_M_AXI_LITE_ADDR_WIDTH = 32,
  parameter integer C_M_AXI_LITE_DATA_WIDTH = 32,
  parameter integer C_M_AXI_LITE_STRB_WIDTH = C_M_AXI_LITE_DATA_WIDTH/8
)
(
  input  wire                               CLK,
  input  wire                               RST,
  output wire                               CHNL_RX_CLK, 
  input  wire                               CHNL_RX, 
  output wire                               CHNL_RX_ACK, 
  input  wire                               CHNL_RX_LAST, 
  input  wire [31:0]                        CHNL_RX_LEN, 
  input  wire [30:0]                        CHNL_RX_OFF, 
  input  wire [C_PCI_DATA_WIDTH-1:0]        CHNL_RX_DATA, 
  input  wire                               CHNL_RX_DATA_VALID, 
  output wire                               CHNL_RX_DATA_REN,
  
  output wire                               CHNL_TX_CLK, 
  output wire                               CHNL_TX, 
  input  wire                               CHNL_TX_ACK, 
  output wire                               CHNL_TX_LAST, 
  output wire [31:0]                        CHNL_TX_LEN, 
  output wire [30:0]                        CHNL_TX_OFF, 
  output wire [C_PCI_DATA_WIDTH-1:0]        CHNL_TX_DATA, 
  output wire                               CHNL_TX_DATA_VALID, 
  input  wire                               CHNL_TX_DATA_REN,
  
  input  wire                               m_axi_lite_aclk,
  input  wire                               m_axi_lite_aresetn,
  // AXI4 Read Address Channel
  input  wire                               m_axi_lite_arready,
  output reg                                m_axi_lite_arvalid,
  output reg [C_M_AXI_LITE_ADDR_WIDTH-1:0]  m_axi_lite_araddr,
  output reg [2:0]                          m_axi_lite_arprot,

  // AXI4 Read Data Channel
  output reg                                m_axi_lite_rready,
  input  wire                               m_axi_lite_rvalid,
  input  wire [C_M_AXI_LITE_DATA_WIDTH-1:0] m_axi_lite_rdata,
  input  wire [1:0]                         m_axi_lite_rresp,
      
  // AXI4 Write Address Channel
  input  wire                               m_axi_lite_awready,
  output reg                                m_axi_lite_awvalid,
  output reg [C_M_AXI_LITE_ADDR_WIDTH-1:0]  m_axi_lite_awaddr,
  output reg [2:0]                          m_axi_lite_awprot,

  // AXI4 Write Data Channel
  input  wire                               m_axi_lite_wready,
  output reg                                m_axi_lite_wvalid,
  output reg [C_M_AXI_LITE_DATA_WIDTH-1:0]  m_axi_lite_wdata,
  output reg [C_M_AXI_LITE_STRB_WIDTH-1:0]  m_axi_lite_wstrb,
  
  // AXI4 Write Response Channel
  output reg                                m_axi_lite_bready,
  input  wire                               m_axi_lite_bvalid,
  input  wire [1:0]                         m_axi_lite_bresp,

  output reg                                md_error
);

  wire          reset_n;
  
  wire          w_s_tready;  
  reg           w_s_tvalid;  

  wire          aw_s_tready;
  reg           aw_s_tvalid;
  
  wire          ar_s_tready;
  reg           ar_s_tvalid;  
  
  wire          r_m_tvalid;
  reg           r_m_tready;
  wire [31:0]   r_m_tdata;
  wire [3:0]    r_m_tuser;
  
  reg           tag_s_tvalid;
  wire          tag_s_tready;
  wire [31:0]   tag_s_tdata;

  wire          tag_m_tvalid;
  reg           tag_m_tready;
  wire [31:0]   tag_m_tdata;

  reg [31:0]    req_addr;
  reg [31:0]    req_tag;
  reg [31:0]    req_data;
  reg [3:0]     req_strb;

  reg           valid_rd_req;
  reg           valid_wr_req; 
  reg           data_available;
  reg [127:0]   tx_data;

  wire [31:C_M_AXI_LITE_ADDR_WIDTH] dummy_awaddr;
  wire [31:C_M_AXI_LITE_ADDR_WIDTH] dummy_araddr;
  
  enum {S_RX_RESET, S_RX_WAIT_FOR_REQ, S_RX_STORE_RD_REQ, S_RX_STORE_WR_REQ} rx_state;  
  enum {S_TX_RESET, S_TX_WAIT_FOR_DATA, S_TX_SEND_HDR, S_TX_SEND_DATA} tx_state;
  
  /////////////
  //
  /////////////

  assign reset_n = ~RST;    

  always_comb begin
    m_axi_lite_arprot = 2'b0;
    m_axi_lite_awprot = 2'b0;
    m_axi_lite_bready = 1'b1;
    md_error = 1'b0;
  end
  
  assign CHNL_TX_CLK = CLK;
  assign CHNL_RX_CLK = CLK;  
   
  ////////////
  //
  /////////////
  
  assign CHNL_RX_ACK = 1'b1; 
  
  // Decode valid read and write requests
  always_comb begin

    valid_rd_req = 0;
    if ((CHNL_RX_DATA[`REQ_TYPE_RANGE] == `C_RD_REQ) && CHNL_RX_DATA_VALID) begin
      valid_rd_req = 1;
    end
    
    valid_wr_req = 0;
    if ((CHNL_RX_DATA[`REQ_TYPE_RANGE] == `C_WR_REQ) && CHNL_RX_DATA_VALID) begin
      valid_wr_req = 1;
    end
  end
  
  // 
  always_ff @(posedge CLK, negedge reset_n) begin
    if (!reset_n) begin
      rx_state <= S_RX_RESET;
    end else begin
      case (rx_state)      
        // 
        S_RX_RESET: begin
          rx_state <= S_RX_WAIT_FOR_REQ;
        end
        //
        S_RX_WAIT_FOR_REQ: begin
          if (valid_rd_req) begin
            rx_state <= S_RX_STORE_RD_REQ;
          end else if (valid_wr_req) begin
            rx_state <= S_RX_STORE_WR_REQ;
          end
        end
        // 
        S_RX_STORE_WR_REQ: begin
          if (aw_s_tready && w_s_tready) begin
            rx_state <= S_RX_WAIT_FOR_REQ;
          end
        end  
        // 
        S_RX_STORE_RD_REQ: begin
          if (ar_s_tready && tag_s_tready) begin
            rx_state <= S_RX_WAIT_FOR_REQ;
          end
        end
        //           
      endcase
    end
  end

  assign CHNL_RX_DATA_REN = (rx_state==S_RX_WAIT_FOR_REQ) ? 1 : 0;
  
  always_ff @(posedge CLK) begin
    if ((rx_state==S_RX_WAIT_FOR_REQ) && (valid_rd_req || valid_wr_req)) begin
      req_addr = CHNL_RX_DATA[`ADDR_RANGE];
      req_data = CHNL_RX_DATA[`DATA_RANGE];
      req_tag = CHNL_RX_DATA[`TAG_RANGE];
      req_strb = CHNL_RX_DATA[`STRB_RANGE];
    end
  end
    
  always_comb begin
    //
    aw_s_tvalid = 0;
    w_s_tvalid = 0;
    if (rx_state==S_RX_STORE_WR_REQ) begin
      aw_s_tvalid = 1;
      w_s_tvalid = 1;
    end  
    //
    ar_s_tvalid = 0;
    tag_s_tvalid = 0;
    if (rx_state==S_RX_STORE_RD_REQ) begin
      ar_s_tvalid = 1;
      tag_s_tvalid = 1;
    end     
  end

  assign tag_s_tdata = req_tag;

  
  ////////////////////////
  //
  ////////////////////////
  
  always_comb begin
    data_available = 0;
    if (r_m_tvalid && tag_m_tvalid) begin
      data_available = 1;
    end
  end  
  
  always_ff @(posedge CLK, negedge reset_n) begin
    if (!reset_n) begin
      tx_state <= S_TX_RESET;
    end else begin
      case (tx_state)       
        //
        S_TX_RESET: begin
          tx_state <= S_TX_WAIT_FOR_DATA;
        end
        //
        S_TX_WAIT_FOR_DATA: begin
          if (data_available) begin
            tx_state <= S_TX_SEND_HDR;
          end
        end
        //
        S_TX_SEND_HDR: begin
          if (CHNL_TX_ACK) begin
            tx_state <= S_TX_SEND_DATA;
          end
        end
        //
        S_TX_SEND_DATA: begin
          if (CHNL_TX_DATA_REN) begin
            tx_state <= S_TX_WAIT_FOR_DATA;
          end
        end
      endcase
    end
  end    
  
  always_comb begin
    r_m_tready = 0;
    tag_m_tready = 0;
    if (data_available) begin
      r_m_tready = 1;
      tag_m_tready = 1;
    end
  end

  assign CHNL_TX = (tx_state==S_TX_SEND_HDR) ? 1 : 0;
  assign CHNL_TX_LAST = 1'b1; 
  assign CHNL_TX_LEN = 32'd4;
  assign CHNL_TX_OFF = 31'd0;

  assign CHNL_TX_DATA_VALID = (tx_state==S_TX_SEND_DATA) ? 1 : 0;
  
  always_ff @(posedge CLK) begin
    if ((tx_state==S_TX_WAIT_FOR_DATA) && data_available) begin
      tx_data = 128'b0;
      tx_data[`RESP_RANGE] = r_m_tuser[1:0];
      tx_data[`TAG_RANGE] = tag_m_tdata;
      tx_data[`DATA_RANGE] = r_m_tdata;
    end
  end

  assign CHNL_TX_DATA = tx_data;
  
  ///////////
  // FIFOs //
  ///////////
  
  axis_fifo_2clk_32d_4u aw_fifo (
    .s_aclk           (CLK),                                // input
    .s_aresetn        (reset_n),                            // input
    .s_axis_tvalid    (aw_s_tvalid),                        // input
    .s_axis_tready    (aw_s_tready),                        // output
    .s_axis_tdata     (req_addr),                           // input [31:0]
    .s_axis_tuser     (4'b0),                               // input [3:0]

    .m_aclk           (m_axi_lite_aclk),                    // input
    .m_axis_tvalid    (m_axi_lite_awvalid),                 // output
    .m_axis_tready    (m_axi_lite_awready),                 // input
    .m_axis_tdata     ({dummy_awaddr,m_axi_lite_awaddr}),   // output [31:0]
    .m_axis_tuser     ()                                    // output [3:0]
  );
  
  axis_fifo_2clk_32d_4u w_fifo (
    .s_aclk           (CLK),                                // input
    .s_aresetn        (reset_n),                            // input
    .s_axis_tvalid    (w_s_tvalid),                         // input
    .s_axis_tready    (w_s_tready),                         // output
    .s_axis_tdata     (req_data),                           // input [31:0]
    .s_axis_tuser     (req_strb),                           // input [3:0]

    .m_aclk           (m_axi_lite_aclk),                    // input
    .m_axis_tvalid    (m_axi_lite_wvalid),                  // output
    .m_axis_tready    (m_axi_lite_wready),                  // input
    .m_axis_tdata     (m_axi_lite_wdata),                   // output [31:0]
    .m_axis_tuser     (m_axi_lite_wstrb)                    // output [3:0]
  );
  
  axis_fifo_2clk_32d_4u ar_fifo (
    .s_aclk           (CLK),                                // input
    .s_aresetn        (reset_n),                            // input
    .s_axis_tvalid    (ar_s_tvalid),                        // input
    .s_axis_tready    (ar_s_tready),                        // output
    .s_axis_tdata     (req_addr),                           // input [31:0]
    .s_axis_tuser     (4'b0),                               // input [3:0]

    .m_aclk           (m_axi_lite_aclk),                    // input
    .m_axis_tvalid    (m_axi_lite_arvalid),                 // output
    .m_axis_tready    (m_axi_lite_arready),                 // input
    .m_axis_tdata     ({dummy_araddr,m_axi_lite_araddr}),   // output [31:0]
    .m_axis_tuser     ()                                    // output [3:0]
  );
  
  axis_fifo_2clk_32d_4u r_fifo (
    .s_aclk           (m_axi_lite_aclk),                    // input
    .s_aresetn        (m_axi_lite_aresetn),                 // input
    .s_axis_tvalid    (m_axi_lite_rvalid),                  // input
    .s_axis_tready    (m_axi_lite_rready),                  // output
    .s_axis_tdata     (m_axi_lite_rdata),                   // input [31:0]
    .s_axis_tuser     ({2'b0,m_axi_lite_rresp}),            // input [3:0]

    .m_aclk           (CLK),                                // input
    .m_axis_tvalid    (r_m_tvalid),                         // output
    .m_axis_tready    (r_m_tready),                         // input
    .m_axis_tdata     (r_m_tdata),                          // output [31:0]
    .m_axis_tuser     (r_m_tuser)                           // output [3:0]
  );
  
  axis_fifo_2clk_32d_4u tag_fifo (
    .s_aclk           (CLK),                                // input
    .s_aresetn        (reset_n),                            // input
    .s_axis_tvalid    (tag_s_tvalid),                       // input
    .s_axis_tready    (tag_s_tready),                       // output
    .s_axis_tdata     (tag_s_tdata),                        // input [31:0]
    .s_axis_tuser     (4'b0),

    .m_aclk           (CLK),                                // input
    .m_axis_tvalid    (tag_m_tvalid),                       // output
    .m_axis_tready    (tag_m_tready),                       // input
    .m_axis_tdata     (tag_m_tdata),                        // output [31:0]
    .m_axis_tuser     ()                                    // output [3:0]
  );

endmodule
