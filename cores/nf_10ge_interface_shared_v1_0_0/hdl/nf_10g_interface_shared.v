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
// default top module for 10G interface with shared logic.

`uselib lib=proc_common_v3_00_a
`include "nf_10g_interface_shared_cpu_regs_defines.v"

module nf_10g_interface_shared #(
	parameter 				C_M_AXIS_DATA_WIDTH	= 256,
	parameter 				C_S_AXIS_DATA_WIDTH	= 256,
	parameter 				C_M_AXIS_TUSER_WIDTH	= 128,
	parameter 				C_S_AXIS_TUSER_WIDTH	= 128,
	parameter				C_BASE_ADDRESS		= 32'h00000000,
	parameter 				C_S_AXI_DATA_WIDTH	= 32,
	parameter 				C_S_AXI_ADDR_WIDTH	= 12
)(
	// Shared logic
	output 					areset_clk156_out,
	output 					clk156_out,
	output 					gtrxreset_out,
	output 					gttxreset_out,
	output 					qplllock_out,
	output 					qplloutclk_out,
	output 					qplloutrefclk_out,
	output 					txuserrdy_out,
	output 					txusrclk_out,
	output 					txusrclk2_out,
	output 					reset_counter_done_out,

	// Clocks and resets
	input 					core_clk,
	input [0:0]				core_resetn,
	input 					rst,
	input 					refclk_n,
	input 					refclk_p,

	// SFP Controls and indications
	output 					resetdone,
	input 					tx_fault,
	input 					tx_abs,
	output 					tx_disable,

	//Interface number
	input [7:0] 				interface_number,

	//AXI Interface 10GE -> DMA
	output [C_M_AXIS_DATA_WIDTH-1:0]	m_axis_tdata,
	output [(C_M_AXIS_DATA_WIDTH/8)-1:0]	m_axis_tkeep,
	output [C_M_AXIS_TUSER_WIDTH-1:0]	m_axis_tuser,
	output 					m_axis_tvalid,
	output 					m_axis_tlast,
	input 					m_axis_tready,

	// AXI Interface DMA -> 10GE
	input [C_S_AXIS_DATA_WIDTH-1:0]		s_axis_tdata,
	input [(C_S_AXIS_DATA_WIDTH/8)-1:0]	s_axis_tkeep,
	input 					s_axis_tlast,
	input [C_S_AXIS_TUSER_WIDTH-1:0]	s_axis_tuser,
	input 					s_axis_tvalid,
	output 					s_axis_tready,

	// Signals for AXI_IP and IF_REG (Added for debug purposes)
	// Slave AXI Ports
	input					S_AXI_ACLK,
	input					S_AXI_ARESETN,
	input	[C_S_AXI_ADDR_WIDTH-1 : 0]	S_AXI_AWADDR,
	input					S_AXI_AWVALID,
	input	[C_S_AXI_DATA_WIDTH-1 : 0]	S_AXI_WDATA,
	input	[C_S_AXI_DATA_WIDTH/8-1 : 0]	S_AXI_WSTRB,
	input					S_AXI_WVALID,
	input					S_AXI_BREADY,
	input	[C_S_AXI_ADDR_WIDTH-1 : 0]	S_AXI_ARADDR,
	input					S_AXI_ARVALID,
	input					S_AXI_RREADY,
	output					S_AXI_ARREADY,
	output	[C_S_AXI_DATA_WIDTH-1 : 0]	S_AXI_RDATA,
	output	[1 : 0]				S_AXI_RRESP,
	output					S_AXI_RVALID,
	output					S_AXI_WREADY,
	output	[1 :0]				S_AXI_BRESP,
	output					S_AXI_BVALID,
	output					S_AXI_AWREADY,

	 // Serial I/O from/to transceiver
	input 					rxn,
	input 					rxp,
	output 					txn,
	output 					txp
);

// Xilinx AXIS converter creates tuser width with
// respect to bits per data byte transmitted (tdata width in B);
// Current width per B is 16 -- depends on BD config;

// NetFPGA's pipeline uses only first 128b of TUSER;

// check the block design configuration 
localparam tuser_bits_per_byte	= 16;
// current AXIS TDATA interface width in Bytes
localparam interface_byte_width	= C_M_AXIS_DATA_WIDTH/8;
// internal TUSER field in bits
localparam tuser_width_intern	= interface_byte_width * tuser_bits_per_byte;
// number of bits that are unused in TUSER field
localparam tuser_width_remain	=  tuser_width_intern - C_M_AXIS_TUSER_WIDTH; 


// conversion signals
// Convert Incoming TUSER of 128b into internal BD TUSER of "tuser_width_intern".
wire [tuser_width_intern-1:0]		s_axis_tuser_internal;
wire [tuser_width_intern-1:0]		m_axis_tuser_internal;

// 10GE block configuration
wire [535:0]				pcs_pma_config_vector;
wire [79:0]				mac_tx_config_vector;
wire [79:0]				mac_rx_config_vector;  

//10GE block status
wire [7:0] 				pcspma_status;
wire [1:0] 				mac_status_vector;
wire [447:0]				pcspma_status_vector;

//Registers signals
reg	[`REG_ID_BITS]				id_reg;
reg	[`REG_VERSION_BITS]			version_reg;
wire	[`REG_RESET_BITS]			reset_reg;
reg	[`REG_FLIP_BITS]			ip2cpu_flip_reg;
wire	[`REG_FLIP_BITS]			cpu2ip_flip_reg;
reg	[`REG_DEBUG_BITS]			ip2cpu_debug_reg;
wire	[`REG_DEBUG_BITS]			cpu2ip_debug_reg;
reg	[`REG_INTERFACEID_BITS]			interfaceid_reg;
reg	[`REG_PKTIN_BITS]			pktin_reg;
wire						pktin_reg_clear;
reg	[`REG_PKTOUT_BITS]			pktout_reg;
wire						pktout_reg_clear;
reg	[`REG_MACSTATUSVECTOR_BITS]		macstatusvector_reg;
reg	[`REG_PCSPMASTATUS_BITS]		pcspmastatus_reg;
reg	[`REG_PCSPMASTATUSVECTOR0_BITS]		pcspmastatusvector0_reg;
reg	[`REG_PCSPMASTATUSVECTOR1_BITS]		pcspmastatusvector1_reg;
reg	[`REG_PCSPMASTATUSVECTOR2_BITS]		pcspmastatusvector2_reg;
reg	[`REG_PCSPMASTATUSVECTOR3_BITS]		pcspmastatusvector3_reg;
reg	[`REG_PCSPMASTATUSVECTOR4_BITS]		pcspmastatusvector4_reg;
reg	[`REG_PCSPMASTATUSVECTOR5_BITS]		pcspmastatusvector5_reg;
reg	[`REG_PCSPMASTATUSVECTOR6_BITS]		pcspmastatusvector6_reg;
reg	[`REG_PCSPMASTATUSVECTOR7_BITS]		pcspmastatusvector7_reg;
reg	[`REG_PCSPMASTATUSVECTOR8_BITS]		pcspmastatusvector8_reg;
reg	[`REG_PCSPMASTATUSVECTOR9_BITS]		pcspmastatusvector9_reg;
reg	[`REG_PCSPMASTATUSVECTOR10_BITS]	pcspmastatusvector10_reg;
reg	[`REG_PCSPMASTATUSVECTOR11_BITS]	pcspmastatusvector11_reg;
reg	[`REG_PCSPMASTATUSVECTOR12_BITS]	pcspmastatusvector12_reg;
reg	[`REG_PCSPMASTATUSVECTOR13_BITS]	pcspmastatusvector13_reg;
wire						resetn_sync;

wire						clear_counters;
wire						reset_registers;

/////////////////////////////////////
// BD instantiation
/////////////////////////////////////
nf_10g_interface_shared_block nf_10g_interface_shared_i (

	.areset_clk156_out		(areset_clk156_out),
	.clk156_out			(clk156_out),
	.gtrxreset_out			(gtrxreset_out),
	.gttxreset_out			(gttxreset_out),
	.qplllock_out			(qplllock_out),
	.qplloutclk_out			(qplloutclk_out),
	.qplloutrefclk_out		(qplloutrefclk_out),
	.txuserrdy_out			(txuserrdy_out),
	.txusrclk2_out			(txusrclk2_out),
	.txusrclk_out			(txusrclk_out),
	.reset_counter_done_out		(reset_counter_done_out),

	.core_clk			(core_clk),
	.core_resetn			(core_resetn),
	.refclk_n			(refclk_n),
	.refclk_p			(refclk_p),
	.reset				(rst),

	.resetdone			(resetdone),
	.tx_abs				(tx_abs),
	.tx_disable			(tx_disable),
	.tx_fault			(tx_fault),

	.pcs_pma_configuration_vector	(pcs_pma_config_vector),
	.mac_tx_configuration_vector	(mac_tx_config_vector),
	.mac_rx_configuration_vector	(mac_rx_config_vector),  

	.pcspma_status			(pcspma_status),
	.mac_status_vector		(mac_status_vector),
	.pcs_pma_status_vector		(pcspma_status_vector),

	.interface_number		(interface_number),  

	.m_axis_tdata			(m_axis_tdata),
	.m_axis_tkeep			(m_axis_tkeep),
	.m_axis_tlast			(m_axis_tlast),
	.m_axis_tready			(m_axis_tready),
	.m_axis_tuser			(m_axis_tuser_internal),
	.m_axis_tvalid			(m_axis_tvalid),
	 
	.s_axis_tdata			(s_axis_tdata),
	.s_axis_tkeep			(s_axis_tkeep),
	.s_axis_tlast			(s_axis_tlast),
	.s_axis_tready			(s_axis_tready),
	.s_axis_tuser			(s_axis_tuser_internal),
	.s_axis_tvalid			(s_axis_tvalid),

	.rxn				(rxn),
	.rxp				(rxp),
	.txn				(txn),
	.txp				(txp)  
);


// Assignments
// slave
//assign s_axis_tuser_internal = {{tuser_width_remain{1'b0}}, s_axis_tuser};
assign s_axis_tuser_internal = {C_S_AXIS_TUSER_WIDTH{1'b0}};
// master
assign m_axis_tuser          = m_axis_tuser_internal[C_M_AXIS_TUSER_WIDTH-1:0];

// 10GE block static config
assign pcs_pma_config_vector = 'b0;
assign mac_tx_config_vector  = 'd2;
assign mac_rx_config_vector  = 'd2; 

// Registers section
nf_10g_interface_shared_cpu_regs 
#(
	.C_BASE_ADDRESS        (C_BASE_ADDRESS    ),
	.C_S_AXI_DATA_WIDTH    (C_S_AXI_DATA_WIDTH),
	.C_S_AXI_ADDR_WIDTH    (C_S_AXI_ADDR_WIDTH)
 ) nf_10g_interface_shared_cpu_regs_inst
 (   
	// General ports
	.clk                    (core_clk),
	.resetn                 (core_resetn),
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
	.id_reg				(id_reg),
	.version_reg			(version_reg),
	.reset_reg			(reset_reg),
	.ip2cpu_flip_reg		(ip2cpu_flip_reg),
	.cpu2ip_flip_reg		(cpu2ip_flip_reg),
	.ip2cpu_debug_reg		(ip2cpu_debug_reg),
	.cpu2ip_debug_reg		(cpu2ip_debug_reg),
	.interfaceid_reg		(interfaceid_reg),
	.pktin_reg			(pktin_reg),
	.pktin_reg_clear		(pktin_reg_clear),
	.pktout_reg			(pktout_reg),
	.pktout_reg_clear		(pktout_reg_clear),
	.macstatusvector_reg		(macstatusvector_reg),
	.pcspmastatus_reg		(pcspmastatus_reg),
	.pcspmastatusvector0_reg	(pcspmastatusvector0_reg),
	.pcspmastatusvector1_reg	(pcspmastatusvector1_reg),
	.pcspmastatusvector2_reg	(pcspmastatusvector2_reg),
	.pcspmastatusvector3_reg	(pcspmastatusvector3_reg),
	.pcspmastatusvector4_reg	(pcspmastatusvector4_reg),
	.pcspmastatusvector5_reg	(pcspmastatusvector5_reg),
	.pcspmastatusvector6_reg	(pcspmastatusvector6_reg),
	.pcspmastatusvector7_reg	(pcspmastatusvector7_reg),
	.pcspmastatusvector8_reg	(pcspmastatusvector8_reg),
	.pcspmastatusvector9_reg	(pcspmastatusvector9_reg),
	.pcspmastatusvector10_reg	(pcspmastatusvector10_reg),
	.pcspmastatusvector11_reg	(pcspmastatusvector11_reg),
	.pcspmastatusvector12_reg	(pcspmastatusvector12_reg),
	.pcspmastatusvector13_reg	(pcspmastatusvector13_reg),
	// Global Registers - user can select if to use
	.cpu_resetn_soft		(),		//software reset, after cpu module
	.resetn_soft			(),		//software reset to cpu module (from central reset management)
	.resetn_sync			(resetn_sync)	//synchronized reset, use for better timing
);


// Registers logic, current logic is just a placeholder for initial compil, required to be changed by the user
wire [31:0]	id_default;

assign id_default	= `REG_ID_DEFAULT;
assign clear_counters	= reset_reg[0];
assign reset_registers	= reset_reg[4];

always @(posedge core_clk)
	if (~resetn_sync | reset_registers) begin
		id_reg			<= #1 `REG_ID_DEFAULT;
		version_reg		<= #1 `REG_VERSION_DEFAULT;
		ip2cpu_flip_reg		<= #1 `REG_FLIP_DEFAULT;
		ip2cpu_debug_reg	<= #1 `REG_DEBUG_DEFAULT;
		interfaceid_reg		<= #1 `REG_INTERFACEID_DEFAULT;
		pktin_reg		<= #1 `REG_PKTIN_DEFAULT;
		pktout_reg		<= #1 `REG_PKTOUT_DEFAULT;
		macstatusvector_reg	<= #1 `REG_MACSTATUSVECTOR_DEFAULT;
		pcspmastatus_reg	<= #1 `REG_PCSPMASTATUS_DEFAULT;
		pcspmastatusvector0_reg	<= #1 `REG_PCSPMASTATUSVECTOR0_DEFAULT;
		pcspmastatusvector1_reg	<= #1 `REG_PCSPMASTATUSVECTOR1_DEFAULT;
		pcspmastatusvector2_reg	<= #1 `REG_PCSPMASTATUSVECTOR2_DEFAULT;
		pcspmastatusvector3_reg	<= #1 `REG_PCSPMASTATUSVECTOR3_DEFAULT;
		pcspmastatusvector4_reg	<= #1 `REG_PCSPMASTATUSVECTOR4_DEFAULT;
		pcspmastatusvector5_reg	<= #1 `REG_PCSPMASTATUSVECTOR5_DEFAULT;
		pcspmastatusvector6_reg	<= #1 `REG_PCSPMASTATUSVECTOR6_DEFAULT;
		pcspmastatusvector7_reg	<= #1 `REG_PCSPMASTATUSVECTOR7_DEFAULT;
		pcspmastatusvector8_reg	<= #1 `REG_PCSPMASTATUSVECTOR8_DEFAULT;
		pcspmastatusvector8_reg	<= #1 `REG_PCSPMASTATUSVECTOR8_DEFAULT;
		pcspmastatusvector9_reg	<= #1 `REG_PCSPMASTATUSVECTOR9_DEFAULT;
		pcspmastatusvector10_reg<= #1 `REG_PCSPMASTATUSVECTOR10_DEFAULT;
		pcspmastatusvector11_reg<= #1 `REG_PCSPMASTATUSVECTOR11_DEFAULT;
		pcspmastatusvector12_reg<= #1 `REG_PCSPMASTATUSVECTOR12_DEFAULT;
		pcspmastatusvector13_reg<= #1 `REG_PCSPMASTATUSVECTOR13_DEFAULT;
	end
	else begin
		id_reg		<= #1    {4'h01,4'h0,interface_number,id_default[15:0]};//ID decoding: 4'01 - shared logic, 0, 8bit port number, 16bit block id
		version_reg	<= #1    `REG_VERSION_DEFAULT;
		ip2cpu_flip_reg	<= #1    ~cpu2ip_flip_reg;
		ip2cpu_debug_reg<= #1    `REG_DEBUG_DEFAULT+cpu2ip_debug_reg;
		interfaceid_reg	<= #1    {24'h0,interface_number};
		pktin_reg[`REG_PKTIN_WIDTH -2: 0]	<= #1  clear_counters | pktin_reg_clear ? 'h0  : pktin_reg[`REG_PKTIN_WIDTH-2:0] + (m_axis_tlast && m_axis_tvalid && m_axis_tready)  ;
        	pktin_reg[`REG_PKTIN_WIDTH-1]		<= #1  clear_counters | pktin_reg_clear ? 1'h0 : pktin_reg[`REG_PKTIN_WIDTH-2:0] + (m_axis_tlast && m_axis_tvalid && m_axis_tready)  > {(`REG_PKTIN_WIDTH-1){1'b1}} ? 1'b1 : pktin_reg[`REG_PKTIN_WIDTH-1];
		pktout_reg [`REG_PKTOUT_WIDTH-2:0]	<= #1  clear_counters | pktout_reg_clear ? 'h0  : pktout_reg [`REG_PKTOUT_WIDTH-2:0] + (s_axis_tvalid && s_axis_tlast && s_axis_tready);
                pktout_reg [`REG_PKTOUT_WIDTH-1]	<= #1  clear_counters | pktout_reg_clear ? 'h0  : pktout_reg [`REG_PKTOUT_WIDTH-2:0] + (s_axis_tvalid && s_axis_tlast && s_axis_tready) > {(`REG_PKTOUT_WIDTH-1){1'b1}} ? 1'b1 : pktout_reg [`REG_PKTOUT_WIDTH-1];
		macstatusvector_reg	<= #1    mac_status_vector;
		pcspmastatus_reg	<= #1    pcspma_status;
		pcspmastatusvector0_reg	<= #1    pcspma_status_vector[ 31:0 ];
		pcspmastatusvector1_reg	<= #1    pcspma_status_vector[ 63:32 ];
		pcspmastatusvector2_reg	<= #1    pcspma_status_vector[ 95:64 ];
		pcspmastatusvector3_reg	<= #1    pcspma_status_vector[127:96 ];
		pcspmastatusvector4_reg	<= #1    pcspma_status_vector[159:128 ];
		pcspmastatusvector5_reg	<= #1    pcspma_status_vector[191:160 ];
		pcspmastatusvector6_reg	<= #1    pcspma_status_vector[223:192 ];
		pcspmastatusvector7_reg	<= #1    pcspma_status_vector[255:224 ];
		pcspmastatusvector8_reg	<= #1    pcspma_status_vector[287:256 ];
		pcspmastatusvector9_reg	<= #1    pcspma_status_vector[319:288 ];
		pcspmastatusvector10_reg<= #1   pcspma_status_vector[351:320 ];
		pcspmastatusvector11_reg<= #1   pcspma_status_vector[383:352 ];
		pcspmastatusvector12_reg<= #1   pcspma_status_vector[415:384 ];
		pcspmastatusvector13_reg<= #1   pcspma_status_vector[447:416 ];
	end
endmodule
