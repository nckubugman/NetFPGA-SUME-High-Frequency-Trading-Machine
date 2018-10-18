//
// Copyright (c) 2015 Gianni Antichi 
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
//
//

`timescale 1ns/1ps

module rx_axi_riffa #(
   parameter C_PCI_DATA_WIDTH = 128,
   parameter C_RIFFA_OFFSET   = 31'h0,
   parameter C_PREAM_VALUE    = 16'hCAFE 
)
(
   input    wire                             CLK, 
   input    wire                             RST,
   // RIFFA outputs
   output   reg                              CHNL_TX,
   output   reg   [C_PCI_DATA_WIDTH-1:0]     CHNL_TX_DATA,
   output   reg                              CHNL_TX_DATA_VALID, 
   output   reg                              CHNL_TX_LAST,
   output   reg   [31:0]                     CHNL_TX_LEN, 
   output   reg   [30:0]                     CHNL_TX_OFF,
   input    wire                             CHNL_TX_DATA_REN,
   input    wire                             CHNL_TX_ACK,
   // AXIS-Slave input 
   input    wire  [C_PCI_DATA_WIDTH-1:0]     tdata,
   input    wire  [C_PCI_DATA_WIDTH/8-1:0]   tkeep,
   input    wire  [127:0]                    tuser,
   input    wire                             tvalid,
   input    wire                             tlast,
   output                                    tready
);

function integer log2;
   input integer number;
   begin
      log2=0;
      while(2**log2<number) begin
         log2=log2+1;
      end
   end
endfunction

`define  AXIS_FIRST     0
`define  AXIS_PKT       1

`define  RIFFA_IDLE     0
`define  RIFFA_SEND     1
`define  RIFFA_RESET    2

localparam  MAX_PKT_SIZE = 2000; 
localparam  IN_FIFO_DEPTH_BIT = log2(MAX_PKT_SIZE/(C_PCI_DATA_WIDTH/8));

reg   [C_PCI_DATA_WIDTH:0]      fifo_in;
wire  [C_PCI_DATA_WIDTH:0]      fifo_out;
wire  [C_PCI_DATA_WIDTH:0]      fifo_first;

reg   fifo_wren, fifo_rden;
wire  fifo_nearly_full, fifo_empty;
reg [31:0] rlen, rlen_next;

wire [C_PCI_DATA_WIDTH-1:0]     tdata_fifo;
wire [C_PCI_DATA_WIDTH/8-1:0]   tkeep_fifo;
wire [C_PCI_DATA_WIDTH-1:0]     tuser_fifo;
wire                            tlast_fifo;
wire                            rx_riffa_nearly_full;
wire                            rx_riffa_empty;
reg                             rx_riffa_rd_en;

reg   [2:0]    axis_current_state, axis_next_state;
reg   [2:0]    riffa_current_state, riffa_next_state;

fallthrough_small_fifo #(
    .WIDTH            (2*C_PCI_DATA_WIDTH+1),
    .MAX_DEPTH_BITS   (10)
)
rx_riffa_fifo
(
  .clk              (CLK),
  .reset            (RST),
  .din              ({tdata,tuser,tlast}),
  .wr_en            (tvalid&~rx_riffa_nearly_full),
  .rd_en            (rx_riffa_rd_en),
  .dout             ({tdata_fifo,tuser_fifo,tlast_fifo}),
  .nearly_full      (rx_riffa_nearly_full),
  .empty            (rx_riffa_empty),
  .full             (),
  .prog_full        ()
);  

fallthrough_small_fifo #(
   .WIDTH            (  C_PCI_DATA_WIDTH+1   ),
   .MAX_DEPTH_BITS   (  IN_FIFO_DEPTH_BIT    )
)
axis_riffa_fifo
(
   .clk              (CLK),
   .reset            (RST),
   .din              (fifo_in),
   .wr_en            (fifo_wren),
   .rd_en            (fifo_rden),
   .dout             (fifo_out),
   .nearly_full      (fifo_nearly_full),
   .empty            (fifo_empty),
   .full             (),
   .prog_full        ()
);

assign fifo_first = {1'b0, tuser_fifo[64+:64], C_PREAM_VALUE, tuser_fifo[0+:16], 8'b0, tuser_fifo[24+:8], 8'b0, tuser_fifo[16+:8]};
assign tready = !rx_riffa_nearly_full;

always @(posedge CLK)
   if (RST) begin
      axis_current_state   <= `AXIS_FIRST;
   end
   else begin
      axis_current_state   <= axis_next_state;
   end

always @(*) begin
   fifo_in           = {tlast_fifo,tdata_fifo};
   fifo_wren         = 0;
   rx_riffa_rd_en    = 0;
   axis_next_state   = axis_current_state;

   case(axis_current_state)
      `AXIS_FIRST : begin
        if(!rx_riffa_empty && !fifo_nearly_full) begin
            fifo_in = fifo_first;
            fifo_wren = 1;
            axis_next_state = `AXIS_PKT;
          end    
      end
      `AXIS_PKT : begin
         if(!rx_riffa_empty && !fifo_nearly_full) begin
            fifo_wren = 1;
            rx_riffa_rd_en = 1;
            if(tlast_fifo)
                axis_next_state = `AXIS_FIRST;
        end
      end  
   endcase
end


always @(posedge CLK)
   if (RST) begin
      riffa_current_state  <= `RIFFA_IDLE;
      rlen                 <= 0;
   end
   else begin
      rlen                 <= rlen_next;
      riffa_current_state  <= riffa_next_state;
   end

always @(*) begin
   CHNL_TX              = 0;
   CHNL_TX_LAST         = 0;
   CHNL_TX_DATA         = 0;
   CHNL_TX_DATA_VALID   = 0;
   CHNL_TX_LEN          = 0;
   CHNL_TX_OFF          = 0;
   fifo_rden            = 0;
   riffa_next_state     = riffa_current_state;
   rlen_next            = rlen;

   case (riffa_current_state)

      `RIFFA_IDLE : begin
        if(!fifo_empty) begin
            CHNL_TX = 1;
            CHNL_TX_LAST = 1;
            rlen_next = (fifo_out[34+:14] + (|fifo_out[32+:2]) + 4);
            CHNL_TX_LEN = (fifo_out[34+:14] + (|fifo_out[32+:2]) + 4);
            if(CHNL_TX_ACK) begin
                CHNL_TX_DATA_VALID = 1;
                CHNL_TX_DATA = fifo_out[127:0];
                if(CHNL_TX_DATA_REN) begin
                  fifo_rden = 1;
                end  
                riffa_next_state = `RIFFA_SEND;
            end 
          end    
        end

      `RIFFA_SEND : begin
        CHNL_TX = 1;
        CHNL_TX_LAST = 1;
        CHNL_TX_LEN = rlen;
        if(!fifo_empty) begin
            CHNL_TX_DATA_VALID = 1;
            CHNL_TX_DATA = fifo_out[127:0];
            if(CHNL_TX_DATA_REN) begin
                fifo_rden = 1;
                if(fifo_out[128])
                    riffa_next_state = `RIFFA_RESET;
            end
        end
        end

        `RIFFA_RESET : begin
            CHNL_TX             = 0;
            CHNL_TX_LAST        = 0;
            CHNL_TX_DATA        = 0;
            CHNL_TX_DATA_VALID  = 0;
            CHNL_TX_LEN         = 0;
            CHNL_TX_OFF         = 0;
            riffa_next_state    = `RIFFA_IDLE;
        end


   endcase
end

endmodule
