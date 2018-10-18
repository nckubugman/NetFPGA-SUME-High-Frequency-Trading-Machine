#
# Copyright (c) 2015 University of Cambridge
# Modified by Salvator Galea
# All rights reserved.
#
# This software was developed by
# Stanford University and the University of Cambridge Computer Laboratory
# under National Science Foundation under Grant No. CNS-0855268,
# the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
# by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
# as part of the DARPA MRC research programme.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#

set device 		{xc7vx690tffg1761-3}
set ip_name 		{nf_riffa_dma}
set lib_name 		{NetFPGA}
set vendor_name 	{NetFPGA}
set ip_display_name 	{nf_riffa_dma}
set ip_description 	{RIFFA DMA engine for NetFPGA SUME}
set vendor_display_name {NetFPGA}
set vendor_company_url 	{http://www.netfpga.org}
set ip_version 		{1.0}


## Other 
set proj_dir 		./ip_proj
set repo_dir 		../

## include all .xci files
set xil_ip  		{axis_fifo_2clk_32d_4u}	
	
set axis_fifo_params [dict create CONFIG.INTERFACE_TYPE {AXI_STREAM} \
			 	  CONFIG.Clock_Type_AXI {Independent_Clock} \
			 	  CONFIG.TDATA_NUM_BYTES {4} \
		  		  CONFIG.FIFO_Implementation_axis {Independent_Clocks_Distributed_RAM} \
			 	  CONFIG.Input_Depth_axis {16} \
	  			  CONFIG.TSTRB_WIDTH {4} \
			 	  CONFIG.TKEEP_WIDTH {4} \
	  			  CONFIG.FIFO_Implementation_wach {Independent_Clocks_Distributed_RAM} \
	 			  CONFIG.Full_Threshold_Assert_Value_wach {15} \
				  CONFIG.Empty_Threshold_Assert_Value_wach {13} \
				  CONFIG.FIFO_Implementation_wdch {Independent_Clocks_Block_RAM} \
 			 	  CONFIG.Empty_Threshold_Assert_Value_wdch {1021} \
				  CONFIG.FIFO_Implementation_wrch {Independent_Clocks_Distributed_RAM} \
				  CONFIG.Full_Threshold_Assert_Value_wrch {15} \
  				  CONFIG.Empty_Threshold_Assert_Value_wrch {13} \
	  			  CONFIG.FIFO_Implementation_rach {Independent_Clocks_Distributed_RAM} \
				  CONFIG.Full_Threshold_Assert_Value_rach {15} \
				  CONFIG.Empty_Threshold_Assert_Value_rach {13} \
				  CONFIG.FIFO_Implementation_rdch {Independent_Clocks_Block_RAM} \
				  CONFIG.Empty_Threshold_Assert_Value_rdch {1021} \
	  			  CONFIG.Full_Threshold_Assert_Value_axis {15} \
		  		  CONFIG.Empty_Threshold_Assert_Value_axis {13}]

## # of added files
set_param project.singleFileAddWarning.Threshold 500


### SubCore Reference
set subcore_names {\
		fallthrough_small_fifo\
}
#### nf_axis_converter\

### Source Files List
# Here for all directory
set source_dir { \
		hdl\
}		

## quick way, there is a cleaner way
set VerilogFiles [list]
set VerilogFiles [concat \
			[glob -nocomplain hdl/sume/*]\
			[glob -nocomplain hdl/riffa/*]]

set rtl_dirs	[list]
set rtl_dirs	[concat \
			hdl/sume \
			hdl/riffa ]


# Top Module Name
set top_module_name {nf_riffa_dma}
set top_module_file ./hdl/sume/$top_module_name.v

puts "top_file: $top_module_file \n"

# Inferred Bus Interface
set bus_interfaces {\
	xilinx.com:interface:aximm_rtl:1.0\
	xilinx.com:interface:axis_rtl:1.0\
	xilinx.com:interface:pcie3_cfg_msi_rtl:1.0\
	xilinx.com:interface:pcie_cfg_fc_rtl:1.0\
	xilinx.com:interface:pcie3_cfg_status_rtl:1.0\
	xilinx.com:interface:pcie3_cfg_interrupt_rtl:1.0\
}

#############################################
# Create Project
#############################################
create_project -name ${ip_name} -force -dir "./${proj_dir}" -part ${device} 
set_property source_mgmt_mode All [current_project] 
set_property top $top_module_name [current_fileset]

# local IP repo
set_property ip_repo_paths $repo_dir [current_fileset]
update_ip_catalog

# include dirs
foreach rtl_dir $rtl_dirs {
        set_property include_dirs $rtl_dirs [current_fileset]
}

# Add verilog sources here
# Add Verilog Files to The IP Core
foreach verilog_file $VerilogFiles {
	add_files ${verilog_file}
}
#add_files -scan_for_includes -norecurse ${verilog_file}

# Generate Xilinx AXIS-FIFO (xci)
create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 -module_name ${xil_ip}
foreach item [dict keys $axis_fifo_params] {
	set val [dict get $axis_fifo_params $item]
	set_property $item $val [get_ips ${xil_ip}]
}
#puts "( $item , $val ) pair \n"
set xil_ip_xci [append xil_ip ".xci"]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

ipx::package_project -force -import_files $xil_ip_xci

# Create IP Information
set_property name 			${ip_name} [ipx::current_core]
set_property library 			${lib_name} [ipx::current_core]
set_property vendor_display_name 	${vendor_display_name} [ipx::current_core]
set_property company_url 		${vendor_company_url} [ipx::current_core]
set_property vendor 			${vendor_name} [ipx::current_core]
set_property supported_families 	{{virtex7} {Production}} [ipx::current_core]
set_property taxonomy 			{{/NetFPGA/Generic}} [ipx::current_core]
set_property version 			${ip_version} [ipx::current_core]
set_property display_name 		${ip_display_name} [ipx::current_core]
set_property description 		${ip_description} [ipx::current_core]

# Add SubCore Reference
foreach subcore ${subcore_names} {
	set subcore_regex NAME=~*$subcore*
	set subcore_ipdef [get_ipdefs -filter ${subcore_regex}]

	ipx::add_subcore ${subcore_ipdef} [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
	ipx::add_subcore ${subcore_ipdef}  [ipx::get_file_groups xilinx_anylanguagebehavioralsimulation -of_objects [ipx::current_core]]
	puts "Adding the following subcore: $subcore_ipdef \n"

}

# process verilog header files early
set_property processing_order early [ipx::get_files *.vh -of_objects [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]]
set_property processing_order early [ipx::get_files *.vh -of_objects [ipx::get_file_groups xilinx_anylanguagebehavioralsimulation -of_objects [ipx::current_core]]]


# Auto Generate Parameters
ipx::remove_all_hdl_parameter [ipx::current_core]
ipx::add_model_parameters_from_hdl [ipx::current_core] -top_level_hdl_file $top_module_file -top_module_name $top_module_name
ipx::infer_user_parameters [ipx::current_core]

# Add Ports
ipx::remove_all_port [ipx::current_core]
ipx::add_ports_from_hdl [ipx::current_core] -top_level_hdl_file $top_module_file -top_module_name $top_module_name

# Auto Infer Bus Interfaces
foreach bus_standard ${bus_interfaces} {
	ipx::infer_bus_interfaces ${bus_standard} [ipx::current_core]
}

# Manually infer the other interfaces
# interrupt vec
ipx::add_port_map INTx_VECTOR [ipx::get_bus_interfaces cfg_interrupt -of_objects [ipx::current_core]]
set_property physical_name cfg_interrupt_int [ipx::get_port_maps INTx_VECTOR -of_objects [ipx::get_bus_interfaces cfg_interrupt -of_objects [ipx::current_core]]]
# msi interrupt vector
ipx::add_port_map int_vector [ipx::get_bus_interfaces cfg_interrupt_msi -of_objects [ipx::current_core]]
set_property physical_name cfg_interrupt_msi_int [ipx::get_port_maps int_vector -of_objects [ipx::get_bus_interfaces cfg_interrupt_msi -of_objects [ipx::current_core]]]
update_compile_order -fileset sources_1

# cfg 
ipx::remove_bus_interface pcie [ipx::current_core]
ipx::add_port_map rq_seq_num [ipx::get_bus_interfaces cfg -of_objects [ipx::current_core]]
set_property physical_name pcie_rq_seq_num [ipx::get_port_maps rq_seq_num -of_objects [ipx::get_bus_interfaces cfg -of_objects [ipx::current_core]]]
ipx::add_port_map cq_np_req [ipx::get_bus_interfaces cfg -of_objects [ipx::current_core]]
set_property physical_name pcie_cq_np_req [ipx::get_port_maps cq_np_req -of_objects [ipx::get_bus_interfaces cfg -of_objects [ipx::current_core]]]
ipx::add_port_map cq_np_req_count [ipx::get_bus_interfaces cfg -of_objects [ipx::current_core]]
set_property physical_name pcie_cq_np_req_count [ipx::get_port_maps cq_np_req_count -of_objects [ipx::get_bus_interfaces cfg -of_objects [ipx::current_core]]]
ipx::add_port_map rq_seq_num_vld [ipx::get_bus_interfaces cfg -of_objects [ipx::current_core]]
set_property physical_name pcie_rq_seq_num_vld [ipx::get_port_maps rq_seq_num_vld -of_objects [ipx::get_bus_interfaces cfg -of_objects [ipx::current_core]]]
ipx::add_port_map rq_tag_vld [ipx::get_bus_interfaces cfg -of_objects [ipx::current_core]]
set_property physical_name pcie_rq_tag_vld [ipx::get_port_maps rq_tag_vld -of_objects [ipx::get_bus_interfaces cfg -of_objects [ipx::current_core]]]
ipx::add_port_map rq_tag [ipx::get_bus_interfaces cfg -of_objects [ipx::current_core]]
set_property physical_name pcie_rq_tag [ipx::get_port_maps rq_tag -of_objects [ipx::get_bus_interfaces cfg -of_objects [ipx::current_core]]]

# pcie clk & params 
ipx::add_bus_interface user_clk [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 [ipx::get_bus_interfaces user_clk -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:clock:1.0 [ipx::get_bus_interfaces user_clk -of_objects [ipx::current_core]]
ipx::add_port_map CLK [ipx::get_bus_interfaces user_clk -of_objects [ipx::current_core]]
set_property physical_name user_clk [ipx::get_port_maps CLK -of_objects [ipx::get_bus_interfaces user_clk -of_objects [ipx::current_core]]]
ipx::add_bus_parameter ASSOCIATED_BUSIF [ipx::get_bus_interfaces user_clk -of_objects [ipx::current_core]]
ipx::add_bus_parameter ASSOCIATED_RESET [ipx::get_bus_interfaces user_clk -of_objects [ipx::current_core]]
set_property value user_clk [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects [ipx::get_bus_interfaces user_clk -of_objects [ipx::current_core]]]
set_property value user_reset [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects [ipx::get_bus_interfaces user_clk -of_objects [ipx::current_core]]]

# pcie rst & params
ipx::add_bus_interface user_reset [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:signal:reset_rtl:1.0 [ipx::get_bus_interfaces user_reset -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:reset:1.0 [ipx::get_bus_interfaces user_reset -of_objects [ipx::current_core]]
ipx::add_port_map RST [ipx::get_bus_interfaces user_reset -of_objects [ipx::current_core]]
set_property physical_name user_reset [ipx::get_port_maps RST -of_objects [ipx::get_bus_interfaces user_reset -of_objects [ipx::current_core]]]
ipx::add_bus_parameter POLARITY [ipx::get_bus_interfaces user_reset -of_objects [ipx::current_core]]
set_property value ACTIVE_HIGH [ipx::get_bus_parameters POLARITY -of_objects [ipx::get_bus_interfaces user_reset -of_objects [ipx::current_core]]]

# axi_lite rst
set_property value ACTIVE_LOW [ipx::get_bus_parameters POLARITY -of_objects [ipx::get_bus_interfaces m_axi_lite_aresetn -of_objects [ipx::current_core]]]
set_property value ACTIVE_HIGH [ipx::get_bus_parameters POLARITY -of_objects [ipx::get_bus_interfaces user_reset -of_objects [ipx::current_core]]]


ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axi_lite -of_objects [ipx::current_core]]
set_property description {Clock frequency (Hertz)} [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces s_axi_lite -of_objects [ipx::current_core]]]

## other
ipx::add_bus_parameter ASSOCIATED_BUSIF [ipx::get_bus_interfaces user_clk -of_objects [ipx::current_core]]
set_property value user_clk [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects [ipx::get_bus_interfaces user_clk -of_objects [ipx::current_core]]]


## set bus parameters correctly
ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces m_axis_cq -of_objects [ipx::current_core]]
set_property description {Clock frequency (Hertz)} [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces m_axis_cq -of_objects [ipx::current_core]]]
set_property value 250000000 [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces m_axis_cq -of_objects [ipx::current_core]]]

ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces m_axis_rc -of_objects [ipx::current_core]]
set_property description {Clock frequency (Hertz)} [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces m_axis_rc -of_objects [ipx::current_core]]]
set_property value 250000000 [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces m_axis_rc -of_objects [ipx::current_core]]]

ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axis_cc -of_objects [ipx::current_core]]
set_property description {Clock frequency (Hertz)} [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces s_axis_cc -of_objects [ipx::current_core]]]
set_property value 250000000 [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces s_axis_cc -of_objects [ipx::current_core]]]

ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axis_rq -of_objects [ipx::current_core]]
set_property description {Clock frequency (Hertz)} [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces s_axis_rq -of_objects [ipx::current_core]]]
set_property value 250000000 [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces s_axis_rq -of_objects [ipx::current_core]]]

ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces m_axis_xge_tx -of_objects [ipx::current_core]]
set_property description {Clock frequency (Hertz)} [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces m_axis_xge_tx -of_objects [ipx::current_core]]]
set_property value 250000000 [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces m_axis_xge_tx -of_objects [ipx::current_core]]]

ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axis_xge_rx -of_objects [ipx::current_core]]
set_property description {Clock frequency (Hertz)} [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces s_axis_xge_rx -of_objects [ipx::current_core]]]
set_property value 250000000 [ipx::get_bus_parameters FREQ_HZ -of_objects [ipx::get_bus_interfaces s_axis_xge_rx -of_objects [ipx::current_core]]]

# Write IP Core xml to File system
ipx::check_integrity [ipx::current_core]
write_peripheral [ipx::current_core]

# Generate GUI Configuration Files
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

update_ip_catalog -rebuild -repo_path $repo_dir 

close_project
exit

