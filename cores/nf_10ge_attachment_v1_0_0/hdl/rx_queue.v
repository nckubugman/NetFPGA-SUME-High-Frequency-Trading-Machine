//
// Copyright (c) 2015 James Hongyi Zeng, Yury Audzevich, Gianni Antichi, Neelakandan Manihatty Bojan
// Copyright (c) 2016 Jong Hun Han
// All rights reserved.
// 
// Description:
//        10g ethernet rx queue with backpressure.
//        ported from nf10 (Virtex-5 based) interface.
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

module rx_queue
#(
   parameter AXI_DATA_WIDTH = 64 //Only 64 is supported right now.
)
(
   // AXI side output
   input                                clk,
   input                                reset,
   
   output reg [AXI_DATA_WIDTH-1:0]      o_tdata,
   output reg [AXI_DATA_WIDTH/8-1:0]    o_tkeep,
   output reg                           o_tvalid,
   output reg                           o_tlast,
   input                                o_tready,

   // MAC side input
   input                                clk156,
   input                                areset_clk156,
   
   input [AXI_DATA_WIDTH-1:0]           i_tdata,
   input [AXI_DATA_WIDTH/8-1:0]         i_tkeep,
   input                                i_tuser,
   input                                i_tvalid,
   input                                i_tlast,
   
   // statistics
   output reg                           fifo_wr_en,
   output reg                           rx_pkt_drop,
   output                               rx_bad_frame, 
   output                               rx_good_frame
);

   // MAC -> FIFO FSM 
   localparam IDLE          = 0;
   localparam WAIT_FOR_EOP  = 1;
   localparam DROP          = 2;
   localparam BUBBLE        = 3;

   // FIFO -> OUT FSM 
   localparam ERR_IDLE      = 0;
   localparam ERR_WAIT      = 1;
   localparam ERR_BUBBLE    = 2;

   wire fifo_almost_full;
   wire fifo_empty;

    wire info_fifo_empty;
    wire info_fifo_full;
    reg  info_fifo_rd_en;
    reg  info_fifo_wr_en;
    wire rx_bad_frame_fifo;

    reg  rx_fifo_rd_en;

    reg [AXI_DATA_WIDTH-1:0]    tdata_rx_fifo;
    reg [AXI_DATA_WIDTH/8-1:0]  tkeep_rx_fifo;

    wire [AXI_DATA_WIDTH-1:0]  tdata_delay;
    wire [AXI_DATA_WIDTH/8-1:0]  tkeep_delay;

    reg  [3:0] state, state_next;
    reg  [2:0] err_state, err_state_next;
    reg  err_tvalid;

   // Instantiate clock domain crossing FIFO
   // 36Kb FIFO (First-In-First-Out) Block RAM Memory primitive V7  
   // IMPORTANT: RST should stay high for at least 5 clks, RDEN & WREN should stay 1'b0;
   FIFO36E1 #(        
    .ALMOST_FULL_OFFSET         (9'd300), // > Ethernet MAX length / 6 = 1516Byte/6 = 252
   	.ALMOST_EMPTY_OFFSET        (9'hA),
   	.DO_REG                     (1),
   	.EN_ECC_READ                ("FALSE"),
   	.EN_ECC_WRITE               ("FALSE"),
   	.EN_SYN                     ("FALSE"),
   	.FIRST_WORD_FALL_THROUGH    ("TRUE"),
   	.DATA_WIDTH                 (72),   	
   	.FIFO_MODE                  ("FIFO36_72"),
   	.INIT                       (72'h000000000000000000),
   	.SIM_DEVICE                 ("7SERIES"), 
   	.SRVAL                      (72'h000000000000000000)
   ) rx_fifo (
	.ALMOSTEMPTY                (),
	.ALMOSTFULL                 (fifo_almost_full),
	.EMPTY                      (fifo_empty),
    .FULL                       (),
			
	.DI                         (tdata_rx_fifo),
    .DIP                        (tkeep_rx_fifo),
    .WRCLK                      (clk156),
    .WREN                       (fifo_wr_en),
    .WRCOUNT                    (),
    .WRERR                      (),    
                
	.DO                         (tdata_delay),
	.DOP                        (tkeep_delay),
	.RDCLK                      (clk),
    .RDEN                       (rx_fifo_rd_en),
    .RDCOUNT                    (),
    .RDERR                      (),
		
	.SBITERR                    (),
	.DBITERR                    (),
	.ECCPARITY                  (),
	.INJECTDBITERR              (),
    .INJECTSBITERR              (),	

	.RST                       (areset_clk156),
	.RSTREG                    (), 
	.REGCE                     () 	
   	);
   	
	
	fifo_generator_1_9 rx_info_fifo (
		.din 			(rx_bad_frame),	
		.wr_en			(info_fifo_wr_en),	
		.wr_clk			(clk156),
		
		.dout			(rx_bad_frame_fifo),
		.rd_en			(info_fifo_rd_en),
		.rd_clk			(clk),
		
		.full 			(info_fifo_full),
		.empty 			(info_fifo_empty),
 		.rst			(areset_clk156)
	);
     
    ///////////////////////////////////////////////
    assign rx_good_frame = (i_tuser == 1'b1);
    assign rx_bad_frame  = (i_tvalid && i_tlast && !rx_good_frame); 
     
    // fifo feeding FSM comb
    always @ (*) begin
             state_next       = IDLE;
             tdata_rx_fifo    = i_tdata;
             tkeep_rx_fifo    = i_tkeep;
             fifo_wr_en       = 1'b0;
             info_fifo_wr_en  = 1'b0;
             rx_pkt_drop      = 1'b0; 
        
             case(state)
                 IDLE: begin
                     if(i_tvalid && (i_tkeep == 8'hFF)) begin
                         //info_fifo_wr_en = 1'b1;
                         if(~fifo_almost_full & ~info_fifo_full) begin
                             info_fifo_wr_en = 1'b1;
                             fifo_wr_en = 1'b1;
                             state_next = WAIT_FOR_EOP;
                         end
                         else begin
                             rx_pkt_drop = 1'b1;
                             state_next  = DROP;
                         end
                     end
                 end
    
                 WAIT_FOR_EOP: begin
                     state_next = WAIT_FOR_EOP;
                     if (i_tvalid) begin
                        fifo_wr_en = 1'b1;
                        if(i_tlast)
                            state_next = BUBBLE;
                     end        
                 end

                 BUBBLE: begin
                   fifo_wr_en = 1'b1;
                   tkeep_rx_fifo = 8'b0;
                   tdata_rx_fifo = 64'b0;
                   state_next = IDLE;
                 end  
    
                 DROP: begin
                     state_next = DROP;
                     if(i_tvalid && i_tlast) begin
                         state_next = IDLE;
                     end
                 end
             endcase
      end
     
      // fifo feeding FSM seq
      always @(posedge clk156) begin
              if(areset_clk156) begin
                  state         <= IDLE;
              end
              else begin
                  state         <= state_next;
              end
      end
    
    ///////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////// 
    ///////////////////////////////////////////////////////////////////////      
     // FIFO -> OUT
     always @(posedge clk) begin
         if(rx_fifo_rd_en) begin
             o_tdata <= tdata_delay;
             o_tkeep <= tkeep_delay;
         end
     end
 
     // fifo draining FSM 
     always @(*) begin
         info_fifo_rd_en = 0;
         err_state_next = ERR_BUBBLE;
         err_tvalid = 0;

         rx_fifo_rd_en = 0;
         o_tlast = 0;
         o_tvalid = 0;
        
         case(err_state)
             ERR_IDLE: begin
               err_state_next = ERR_IDLE;
                 rx_fifo_rd_en = (~fifo_empty & o_tready);
                 o_tvalid = (~fifo_empty);                 
                               
                 if (tkeep_delay == 8'h0 & ~fifo_empty) begin // end of the packet 
                     rx_fifo_rd_en = 0;
                     o_tvalid = 0;
                     err_state_next = ERR_WAIT;
                 end
             end
             ERR_WAIT: begin
               err_state_next = ERR_WAIT;
                 if(~info_fifo_empty) begin
                 	o_tlast = 1;
                 	o_tvalid = 1;
                 	if(o_tready) begin
                     	info_fifo_rd_en = 1;
                     	rx_fifo_rd_en = 1;
                     	err_tvalid = rx_bad_frame_fifo;
                     	err_state_next = ERR_BUBBLE;
                    end
                 end
             end
             ERR_BUBBLE: begin
               err_state_next =ERR_BUBBLE;
                 if(~fifo_empty) begin // Head of the packet
                     rx_fifo_rd_en = 1;
                     err_state_next = ERR_IDLE;
                 end
             end
         endcase
     end
    
    // seq
     always @(posedge clk) begin
       if(reset) begin
             err_state      <= ERR_BUBBLE;             
         end
         else begin
             err_state      <= err_state_next;             
         end
     end
endmodule
