//
// Copyright (c) 2015 James Hongyi Zeng, Yury Audzevich
// Copyright (c) 2016 Jong Hun Han
// All rights reserved.
// 
// Description:
//        10g ethernet tx queue with backpressure.
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

module tx_queue
 #(
    parameter AXI_DATA_WIDTH             = 64, //Only 64 is supported right now.
    parameter C_S_AXIS_TUSER_WIDTH       = 128
 
 )
 (
    // AXI side
    input                               clk,
    input                               reset,
      
    input [C_S_AXIS_TUSER_WIDTH-1:0]    i_tuser,
    input [AXI_DATA_WIDTH-1:0]          i_tdata,
    input [(AXI_DATA_WIDTH/8)-1:0]      i_tkeep,
    input                               i_tvalid,
    input                               i_tlast,
    output                              i_tready,
    
    // other
    output                              tx_dequeued_pkt,
    output reg                          be,  
    output reg                          tx_pkts_enqueued_signal,
    output reg [15:0]                   tx_bytes_enqueued,
       
     // MAC side
    input                               clk156,
   input                                areset_clk156,
    
    // AXI side output
    output [AXI_DATA_WIDTH-1:0]         o_tdata,
    output reg [(AXI_DATA_WIDTH/8)-1:0] o_tkeep,
    output reg                          o_tvalid,
    output reg                          o_tlast,
    output reg                          o_tuser,
    input                               o_tready   
 );
 
    localparam IDLE         = 2'd0;
    localparam SEND_PKT     = 2'd1;
 
    localparam METADATA     = 1'b0;
    localparam EOP          = 1'b1;
    
    wire [3:0]                          tkeep_encoded_o;
    reg  [7:0]                          tkeep_decoded_o;
    reg  [3:0]                          tkeep_encoded_i;
    wire                                tlast_axi_i;
    wire                                tlast_axi_o;
 
    wire                                fifo_almost_full, info_fifo_full;
    wire                                fifo_empty, info_fifo_empty;
    reg                                 fifo_rd_en, info_fifo_rd_en;
    reg                                 info_fifo_wr_en;
    wire                                fifo_wr_en;       
     
    reg                                 tx_dequeued_pkt_next;   

    reg  [2:0]                          state, state_next;
    reg                                 state1, state1_next;
   
    wire [2:0]                          zero_padding;

    ////////////////////////////////////////////////
    ////////////////////////////////////////////////
    assign fifo_wr_en  = (i_tvalid & i_tready);    
    assign i_tready    = ~fifo_almost_full & ~info_fifo_full;
    assign tlast_axi_i = i_tlast;

      		 
      // Instantiate clock domain crossing FIFO
      // 36Kb FIFO (First-In-First-Out) Block RAM Memory primitive V7  
      // IMPORTANT: RST should stay high for at least 5 clks, RDEN & WREN should stay 1'b0;
      FIFO36E1 #(        
        .ALMOST_FULL_OFFSET         (9'hA), 
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
      ) tx_fifo (
        .ALMOSTEMPTY                (),
        .ALMOSTFULL                 (fifo_almost_full),
        .EMPTY                      (fifo_empty),
        .FULL                       (),
               
        .DI                         (i_tdata),
        .DIP                        ({3'b0, tlast_axi_i , tkeep_encoded_i}),
        .WRCLK                      (clk),
        .WREN                       (fifo_wr_en),
        .WRCOUNT                    (),
        .WRERR                      (),    
                   
        .DO                         (o_tdata),
        .DOP                        ({zero_padding, tlast_axi_o, tkeep_encoded_o}),
        .RDCLK                      (clk156),
        .RDEN                       (fifo_rd_en),
        .RDCOUNT                    (),
        .RDERR                      (),
           
        .SBITERR                    (),
        .DBITERR                    (),
        .ECCPARITY                  (),
        .INJECTDBITERR              (),
        .INJECTSBITERR              (),    
      
        .RST                        (areset_clk156),
        .RSTREG                     (), 
        .REGCE                      ()     
      );
  	
	fifo_generator_1_9 tx_info_fifo (
		.din 			(1'b0							),	
		.wr_en			(info_fifo_wr_en					), //Only 1 cycle per packet!	
		.wr_clk			(clk							),
		
		.dout			(							),
		.rd_en			(info_fifo_rd_en					),
		.rd_clk			(clk156							),
		
		.full 			(info_fifo_full							),
		.empty 			(info_fifo_empty					),
 		.rst			(areset_clk156							)
	);	
	 

      // Encoder to map 8bit strobe to 4 bit
      // and vice versa.      
      always @(*) begin
          // encode FIFO IN (8b->4b)
          case (i_tkeep)
              8'h1:     tkeep_encoded_i = 4'h0;
              8'h3:     tkeep_encoded_i = 4'h1;
              8'h7:     tkeep_encoded_i = 4'h2;
              8'hF:     tkeep_encoded_i = 4'h3;
              8'h1F:    tkeep_encoded_i = 4'h4;
              8'h3F:    tkeep_encoded_i = 4'h5;
              8'h7F:    tkeep_encoded_i = 4'h6;
              8'hFF:    tkeep_encoded_i = 4'h7;
              default:  tkeep_encoded_i = 4'h8;
          endcase
      
          // decode FIFO OUT (4b->8b)   
          case (tkeep_encoded_o)
              4'h0:     tkeep_decoded_o = 8'h1;
              4'h1:     tkeep_decoded_o = 8'h3;
              4'h2:     tkeep_decoded_o = 8'h7;
              4'h3:     tkeep_decoded_o = 8'hF;
              4'h4:     tkeep_decoded_o = 8'h1F;
              4'h5:     tkeep_decoded_o = 8'h3F;
              4'h6:     tkeep_decoded_o = 8'h7F;
              4'h7:     tkeep_decoded_o = 8'hFF;
              default:  tkeep_decoded_o = 8'h0;
          endcase         
      end
 
      
          
      // Sideband INFO 
      // pkt enq FSM comb
      always @(*) begin 
          state1_next             = METADATA;
              
          tx_pkts_enqueued_signal = 0;
          tx_bytes_enqueued       = 0;
       
          case(state1)
              METADATA: begin
                  if(i_tvalid & i_tready) begin
                      tx_pkts_enqueued_signal = 1;
                      tx_bytes_enqueued       = i_tuser[15:0];
                      state1_next             = EOP;
                  end
              end
       
              EOP: begin
                  state1_next = EOP;
                  if(i_tvalid & i_tlast & i_tready) begin
                      state1_next = METADATA;
                  end
              end
                      
              default: begin 
                      state1_next = METADATA;
              end
           endcase     
      end
       
      // pkt enq FSM seq  
      always @(posedge clk) begin
           if (reset) state1 <= METADATA;
           else       state1 <= state1_next;
      end
           
      // write en on pkt
      always @(posedge clk)
         if (reset)
            info_fifo_wr_en   <= 0;
         else
            info_fifo_wr_en <= i_tlast & i_tvalid & i_tready;
        
 
      //////////////////////////////////////////////////////////
      //////////////////////////////////////////////////////////
      //////////////////////////////////////////////////////////
      
      // FIFO draining FSM comb  
      assign tx_dequeued_pkt = tx_dequeued_pkt_next; 

      always @(*) begin
          state_next            = IDLE;
          
          // axi
          o_tkeep               = tkeep_decoded_o;
          o_tuser               = 1'b0; // no underrun
          o_tvalid              = 1'b0;
          o_tlast               = 1'b0;
          
          // fifos
          fifo_rd_en            = 1'b0;
          info_fifo_rd_en       = 1'b0;
          
          //sideband          
          tx_dequeued_pkt_next  = 'b0;
          be                    = 'b0;
 
          case(state)
              IDLE: begin
                  o_tkeep = 8'b0;
                  if( ~info_fifo_empty & ~fifo_empty) begin
                      // pkt is stored already
                      info_fifo_rd_en = 1'b1;
                      be              = 'b0;                      
                      state_next      = SEND_PKT;                     
                  end
              end

              SEND_PKT: begin 
                // very important: 
                // tvalid to go first: pg157, v3.0, pp. 109.
                o_tvalid = 1'b1;
                state_next  = SEND_PKT;
                if (o_tready & ~fifo_empty) begin                
                    fifo_rd_en            = 1'b1;
                  
                    be                    = 1'b1;
                    tx_dequeued_pkt_next  = 1'b1; 
                                                         
                    if (tlast_axi_o) begin
                         o_tlast    = 1'b1;
                         be         = 1'b1;    
                         state_next = IDLE;                       
                    end               
                end                 
              end
          endcase
      end
 
      always @(posedge clk156) begin
          if(areset_clk156) state <= IDLE;
          else      state <= state_next;         
      end 
 endmodule
