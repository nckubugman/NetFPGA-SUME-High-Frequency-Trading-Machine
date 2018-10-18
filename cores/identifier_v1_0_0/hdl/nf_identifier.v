//
// Copyright (c) 2015 University of Cambridge All rights reserved.
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

`timescale 1ns/1ps

module nf_identifier
#(
   parameter   C_S_AXI_ADDR_WIDTH = 32,
   parameter   C_S_AXI_DATA_WIDTH = 32
)
(
   input                                     S_AXI_ACLK,
   input                                     S_AXI_ARESETN,
   input       [C_S_AXI_ADDR_WIDTH-1 : 0]    S_AXI_AWADDR,
   input                                     S_AXI_AWVALID,
   input       [C_S_AXI_DATA_WIDTH-1 : 0]    S_AXI_WDATA,
   input       [C_S_AXI_DATA_WIDTH/8-1 : 0]  S_AXI_WSTRB,
   input                                     S_AXI_WVALID,
   input                                     S_AXI_BREADY,
   input       [C_S_AXI_ADDR_WIDTH-1 : 0]    S_AXI_ARADDR,
   input                                     S_AXI_ARVALID,
   input                                     S_AXI_RREADY,
   output                                    S_AXI_ARREADY,
   output      [C_S_AXI_DATA_WIDTH-1 : 0]    S_AXI_RDATA,
   output      [1 : 0]                       S_AXI_RRESP,
   output                                    S_AXI_RVALID,
   output                                    S_AXI_WREADY,
   output      [1 :0]                        S_AXI_BRESP,
   output                                    S_AXI_BVALID,
   output                                    S_AXI_AWREADY
);

identifier_ip identifier_ip
(
    .s_aclk          (  S_AXI_ACLK        ),
    .s_aresetn       (  S_AXI_ARESETN     ),
    .s_axi_awaddr    (  S_AXI_AWADDR      ),
    .s_axi_awvalid   (  S_AXI_AWVALID     ),
    .s_axi_awready   (  S_AXI_AWREADY     ),
    .s_axi_wdata     (  S_AXI_WDATA       ),
    .s_axi_wstrb     (  S_AXI_WSTRB       ),
    .s_axi_wvalid    (  S_AXI_WVALID      ),
    .s_axi_wready    (  S_AXI_WREADY      ),
    .s_axi_bresp     (  S_AXI_BRESP       ),
    .s_axi_bvalid    (  S_AXI_BVALID      ),
    .s_axi_bready    (  S_AXI_BREADY      ),
    .s_axi_araddr    (  S_AXI_ARADDR      ),
    .s_axi_arvalid   (  S_AXI_ARVALID     ),
    .s_axi_arready   (  S_AXI_ARREADY     ),
    .s_axi_rdata     (  S_AXI_RDATA       ),
    .s_axi_rresp     (  S_AXI_RRESP       ),
    .s_axi_rvalid    (  S_AXI_RVALID      ),
    .s_axi_rready    (  S_AXI_RREADY      )
); 

endmodule
