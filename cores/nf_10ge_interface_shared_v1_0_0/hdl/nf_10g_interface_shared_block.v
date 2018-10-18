//
// Copyright (c) 2015 University of Cambridge
// Modified by Salvator Galea
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


`timescale 1ns/1ps
// wrapper module for 10G interface with shared logic.

module nf_10g_interface_shared_block #(
	parameter 			C_M_AXIS_DATA_WIDTH		= 256,
	parameter 			C_S_AXIS_DATA_WIDTH		= 256,
	parameter 			C_AXIS_DATA_INTERNAL_WIDTH	= 64,
	parameter 			C_M_AXIS_TUSER_WIDTH		= 128,
	parameter 			C_S_AXIS_TUSER_WIDTH		= 128
)(
	// Shared logic
	output 				areset_clk156_out,
	output 				clk156_out,
	output 				gtrxreset_out,
	output 				gttxreset_out,
	output 				qplllock_out,
	output 				qplloutclk_out,
	output 				qplloutrefclk_out,
	output 				txuserrdy_out,
	output 				txusrclk_out,
	output 				txusrclk2_out,
	output 				reset_counter_done_out,

	// Clocks and resets
	input 				core_clk,
	input [0:0]			core_resetn,
	input 				reset,
	input 				refclk_n,
	input 				refclk_p,

	// SFP Controls and indications
	output 				resetdone,
	input 				tx_fault,
	input 				tx_abs,
	output 				tx_disable,

	//MAC configuration & status
	input [79:0] 			mac_tx_configuration_vector,
	input [79:0] 			mac_rx_configuration_vector,
	input [535:0]			pcs_pma_configuration_vector,
	output reg [7:0] 		pcspma_status,
	output reg [1:0] 		mac_status_vector,
	output reg [447:0]		pcs_pma_status_vector,

	// Interface number
	input [7:0] 			interface_number,

	// AXI Interface 10GE -> DMA
	output [C_M_AXIS_DATA_WIDTH-1:0]	m_axis_tdata,
	output [(C_M_AXIS_DATA_WIDTH/8)-1:0]	m_axis_tkeep,
	output [4*C_M_AXIS_TUSER_WIDTH-1:0]	m_axis_tuser,
	output 					m_axis_tvalid,
	output 					m_axis_tlast,
	input 					m_axis_tready,

	// AXI Interface DMA -> 10GE
	input [C_S_AXIS_DATA_WIDTH-1:0]		s_axis_tdata,
	input [(C_S_AXIS_DATA_WIDTH/8)-1:0]	s_axis_tkeep,
	input 					s_axis_tlast,
	input [4*C_S_AXIS_TUSER_WIDTH-1:0]	s_axis_tuser,
	input 					s_axis_tvalid,
	output 					s_axis_tready,

	// Serial I/O from/to transceiver
	input 					rxn,
	input 					rxp,
	output 					txn,
	output 					txp
);

wire [C_AXIS_DATA_INTERNAL_WIDTH-1:0]		s_axis_tx_tdata;
wire [(C_AXIS_DATA_INTERNAL_WIDTH/8)-1:0]	s_axis_tx_tkeep;
wire 						s_axis_tx_tlast;
wire [0:0]					s_axis_tx_tuser;
wire 						s_axis_tx_tvalid;
wire 						s_axis_tx_tready;

wire [C_AXIS_DATA_INTERNAL_WIDTH-1:0]		m_axis_rx_tdata;
wire [(C_AXIS_DATA_INTERNAL_WIDTH/8)-1:0]	m_axis_rx_tkeep;
wire 						m_axis_rx_tlast;
wire [0:0]					m_axis_rx_tuser;
wire 						m_axis_rx_tvalid;


wire [C_M_AXIS_TUSER_WIDTH-1:0]			m_axis_tuser_128;
wire [C_S_AXIS_TUSER_WIDTH-1:0]			s_axis_tuser_128;

wire						signal_detect;
wire						areset_clk156_out_n;

wire [7:0] 					pcspma_status_internal;
wire [2:0] 					mac_status_vector_internal;
wire [447:0] 					pcs_pma_status_vector_internal;
wire [457:0] 					status_vector_internal;

wire [7 : 0] 					tx_ifg_delay;
wire [15 : 0] 					s_axis_pause_tdata;
wire 						s_axis_pause_tvalid;
wire 						sim_speedup_control;

wire [25:0] 					tx_statistics_vector;
wire [29:0] 					rx_statistics_vector;
wire [31:0] 					axis_data_count;
wire [31:0] 					axis_wr_data_count;
wire [31:0] 					axis_rd_data_count;


assign sim_speedup_control	= 1'b0;
assign s_axis_pause_tvalid	= 1'b0;
assign s_axis_pause_tdata	= 16'b0;
assign tx_ifg_delay		= 8'b0;
assign status_vector_internal	= {pcs_pma_status_vector_internal,mac_status_vector_internal[1:0],pcspma_status_internal};

axi_10g_ethernet_shared axi_10g_ethernet_i (
	.tx_axis_aresetn		(areset_clk156_out_n),                            
	.rx_axis_aresetn		(areset_clk156_out_n),                            
	.tx_ifg_delay			(tx_ifg_delay),                                  
	.dclk				(clk156_out),                                            
	.txp				(txp),                                                    
	.txn				(txn),                                                    
	.rxp				(rxp),                                                    
	.rxn				(rxn),                                                    
	.signal_detect			(signal_detect),                                
	.tx_fault			(tx_fault),                                          
	.tx_disable			(tx_disable),                                      
	.pcspma_status			(pcspma_status_internal),                                
	.sim_speedup_control		(sim_speedup_control),                    
	.mac_tx_configuration_vector	(mac_tx_configuration_vector),    
	.mac_rx_configuration_vector	(mac_rx_configuration_vector),    
	.mac_status_vector		(mac_status_vector_internal),                        
	.pcs_pma_configuration_vector	(pcs_pma_configuration_vector),  
	.pcs_pma_status_vector		(pcs_pma_status_vector_internal),                
	.txusrclk_out			(txusrclk_out),                                  
	.txusrclk2_out			(txusrclk2_out),                                
	.gttxreset_out			(gttxreset_out),                                
	.gtrxreset_out			(gtrxreset_out),                                
	.txuserrdy_out			(txuserrdy_out),                                
	.coreclk_out			(clk156_out),		// Ports Changed in v3.0, clk156_out -> coreclk_out
	.areset_datapathclk_out		(areset_clk156_out),	// Ports Changed in v3.0, areset_clk156_out -> areset_datapathclk_out
	.resetdone_out			(resetdone),		// Ports Changed in v3.0, resetdone -> resetdone_out
	.reset_counter_done_out		(reset_counter_done_out),              
	.qplllock_out			(qplllock_out),                                  
	.qplloutclk_out			(qplloutclk_out),                              
	.qplloutrefclk_out		(qplloutrefclk_out),                        
	.refclk_p			(refclk_p),                                          
	.refclk_n			(refclk_n),                                          
	.reset				(reset),                                                
	.s_axis_tx_tdata		(s_axis_tx_tdata),                            
	.s_axis_tx_tkeep		(s_axis_tx_tkeep),                            
	.s_axis_tx_tlast		(s_axis_tx_tlast),                            
	.s_axis_tx_tready		(s_axis_tx_tready),                          
	.s_axis_tx_tuser		(s_axis_tx_tuser),                            
	.s_axis_tx_tvalid		(s_axis_tx_tvalid),  
       
	.s_axis_pause_tdata		(s_axis_pause_tdata),                      
	.s_axis_pause_tvalid		(s_axis_pause_tvalid),                    

	.m_axis_rx_tdata		(m_axis_rx_tdata),                            
	.m_axis_rx_tkeep		(m_axis_rx_tkeep),                            
	.m_axis_rx_tlast		(m_axis_rx_tlast),                            
	.m_axis_rx_tuser		(m_axis_rx_tuser),                            
	.m_axis_rx_tvalid		(m_axis_rx_tvalid), 
       
	.tx_statistics_valid		(tx_statistics_valid),                    
	.tx_statistics_vector		(tx_statistics_vector),                  
	.rx_statistics_valid		(rx_statistics_valid),                    
	.rx_statistics_vector		(rx_statistics_vector)                  
);

////////////////////////////////////////////////////////////////////////////////////////////////

inverter_0 tx_abs_inverter_shared_i (
	.Op1				(tx_abs),  
	.Res				(signal_detect)  
);

inverter_0 areset_inverter_shared_i (
	.Op1				(areset_clk156_out),  
	.Res				(areset_clk156_out_n)  
);


// tuser specifics
assign m_axis_tuser	= { {3{128'b0}}, m_axis_tuser_128 };
assign s_axis_tuser_128	= s_axis_tuser[0 +:C_S_AXIS_TUSER_WIDTH];

nf_10g_attachment #(
	.C_M_AXIS_DATA_WIDTH	(C_M_AXIS_DATA_WIDTH),
	.C_S_AXIS_DATA_WIDTH	(C_S_AXIS_DATA_WIDTH),
	.C_M_AXIS_TUSER_WIDTH	(C_M_AXIS_TUSER_WIDTH),
	.C_S_AXIS_TUSER_WIDTH	(C_S_AXIS_TUSER_WIDTH),    
	.C_DEFAULT_VALUE_ENABLE	(1),
	.C_DEFAULT_SRC_PORT	(0),
	.C_DEFAULT_DST_PORT	(0)        
) xge_attachment (
	.clk156 		(clk156_out), 
	.areset_clk156 		(areset_clk156_out), 

	// RX MAC 64b@clk156 (no backpressure) -> rx_queue 64b@axis_clk
	.m_axis_mac_tdata 		(m_axis_rx_tdata),
	.m_axis_mac_tkeep 		(m_axis_rx_tkeep),
	.m_axis_mac_tvalid 		(m_axis_rx_tvalid), 
	.m_axis_mac_tuser 		(m_axis_rx_tuser),	// valid frame
	.m_axis_mac_tlast 		(m_axis_rx_tlast),

	// tx_queue 64b@axis_clk -> mac 64b@clk156
	.s_axis_mac_tdata 		(s_axis_tx_tdata),
	.s_axis_mac_tkeep 		(s_axis_tx_tkeep),
	.s_axis_mac_tvalid 		(s_axis_tx_tvalid),
	.s_axis_mac_tuser 		(s_axis_tx_tuser),	//underrun
	.s_axis_mac_tlast 		(s_axis_tx_tlast),
	.s_axis_mac_tready 		(s_axis_tx_tready),

	// TX/RX DATA channels  
	.interface_number  		(interface_number),

	// SUME pipeline clk & rst 
	.axis_aclk			(core_clk),
	.axis_aresetn			(core_resetn),

	// input from ref pipeline 256b -> MAC
	.s_axis_pipe_tdata		(s_axis_tdata), 
	.s_axis_pipe_tkeep		(s_axis_tkeep), 
	.s_axis_pipe_tlast		(s_axis_tlast), 
	.s_axis_pipe_tuser		(s_axis_tuser_128), 
	.s_axis_pipe_tvalid		(s_axis_tvalid),
	.s_axis_pipe_tready		(s_axis_tready),

	// output to ref pipeline 256b -> DMA
	.m_axis_pipe_tdata		(m_axis_tdata), 
	.m_axis_pipe_tkeep		(m_axis_tkeep), 
	.m_axis_pipe_tlast		(m_axis_tlast), 
	.m_axis_pipe_tuser		(m_axis_tuser_128), 
	.m_axis_pipe_tvalid		(m_axis_tvalid),
	.m_axis_pipe_tready		(m_axis_tready)
);


wire status_full, status_empty;
wire [457:0] status_vector_out;
 
fifo_generator_status fifo_generator_shared_status_i (
	.wr_clk		(clk156_out),  
	.rd_clk		(core_clk),  
	.din		(status_vector_internal),        
	.wr_en		(!status_full),    
	.rd_en		(!status_empty),   
	.dout		(status_vector_out),      
	.full		(status_full),      
	.empty		(status_empty)    
);

always@(posedge core_clk) begin
	if (!core_resetn)
	begin
		pcs_pma_status_vector	<= #1 'b0;
		mac_status_vector	<= #1 'b0;
		pcspma_status		<= #1 'b0;
	end
	else
	begin
		pcs_pma_status_vector	<= #1 status_empty ? pcs_pma_status_vector	: status_vector_out[457:10];
		mac_status_vector	<= #1 status_empty ? mac_status_vector		: status_vector_out[9:8];
		pcspma_status		<= #1 status_empty ? pcspma_status		: status_vector_out[7:0];
	end
end

endmodule
