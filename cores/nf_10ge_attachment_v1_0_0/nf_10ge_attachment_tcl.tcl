# 
# Copyright (c) 2015 Yury Audzevich
# Modified by Salvator Galea
# All rights reserved.
# 
# Description:
#        10g ethernet attachment implements clock and data conversion
#        similarly to the nf10 (Virtex-5 based) interface.
#
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
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  NetFPGA
# licenses this file to you under the NetFPGA Hardware-Software License,
# Version 1.0 (the "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at:
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
set ip_name 		{nf_10g_attachment}
set lib_name 		{NetFPGA}
set vendor_name 	{NetFPGA}
set ip_display_name 	{nf_10g_attachment}
set ip_description 	{10G Ethernet attachment for NetFPGA SUME}
set vendor_display_name {NetFPGA}
set vendor_company_url 	{http://www.netfpga.org}
set ip_version 		{1.0}


## Other 
set proj_dir 		./ip_proj


## # of added files
set_param project.singleFileAddWarning.Threshold 500


### SubCore Reference
set subcore_names {\
		nf_axis_converter\
		fallthrough_small_fifo\
}

### Source Files List
# Here for all directory
set source_dir { \
		hdl\
}

## quick way, there is a cleaner way
set VerilogFiles [list]
set VerilogFiles [concat \
			[glob -nocomplain hdl]]

set rtl_dirs	[list]
set rtl_dirs	[concat \
			hdl]


# Top Module Name
set top_module_name {nf_10g_attachment}
set top_module_file ./hdl/$top_module_name.v

puts "top_file: $top_module_file \n"

# Inferred Bus Interface
set bus_interfaces {\
	xilinx.com:signal:clock:1.0\
	xilinx.com:signal:reset:1.0\	
	xilinx.com:interface:axis_rtl:1.0\
}

#############################################
# Create Project
#############################################
create_project -name ${ip_name} -force -dir "./${proj_dir}" -part ${device} 
set_property source_mgmt_mode All [current_project] 
set_property top $top_module_name [current_fileset]

# local IP repo
set_property ip_repo_paths $::env(SUME_FOLDER)/lib/hw/  [current_fileset]
update_ip_catalog

# include dirs
foreach rtl_dir $rtl_dirs {
        set_property include_dirs $rtl_dirs [current_fileset]
}


# Add verilog sources here
# Add Verilog Files to The IP Core
foreach verilog_file $VerilogFiles {
	add_files -norecurse ${verilog_file}
}
#read_verilog $VerilogFiles

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

## with fifo
#ipx::package_project -force -import_files $xil_ip_xci

## without fifo
ipx::package_project

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


# Auto Generate Parameters
ipx::remove_all_hdl_parameter [ipx::current_core]
ipx::add_model_parameters_from_hdl [ipx::current_core] -top_level_hdl_file $top_module_file -top_module_name $top_module_name
ipx::infer_user_parameters [ipx::current_core]

## manual 
set_property value_validation_type list [ipx::get_user_parameters C_M_AXIS_DATA_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_list {256 64} [ipx::get_user_parameters C_M_AXIS_DATA_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_type list [ipx::get_user_parameters C_S_AXIS_DATA_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_list {256 64} [ipx::get_user_parameters C_S_AXIS_DATA_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_type list [ipx::get_user_parameters C_DEFAULT_VALUE_ENABLE -of_objects [ipx::current_core]]
set_property value_validation_list {0 1} [ipx::get_user_parameters C_DEFAULT_VALUE_ENABLE -of_objects [ipx::current_core]]
set_property value_validation_type list [ipx::get_user_parameters C_M_AXIS_TUSER_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_list 128 [ipx::get_user_parameters C_M_AXIS_TUSER_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_type list [ipx::get_user_parameters C_S_AXIS_TUSER_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_list 128 [ipx::get_user_parameters C_S_AXIS_TUSER_WIDTH -of_objects [ipx::current_core]]

# Add Ports
ipx::remove_all_port [ipx::current_core]
ipx::add_ports_from_hdl [ipx::current_core] -top_level_hdl_file $top_module_file -top_module_name $top_module_name

# Auto Infer Bus Interfaces
foreach bus_standard ${bus_interfaces} {
	ipx::infer_bus_interfaces ${bus_standard} [ipx::current_core]
}

# manually infer the rest
# 156MHz clk
ipx::add_bus_interface clk156 [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:clock:1.0 [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]
set_property interface_mode slave [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]
ipx::add_port_map CLK [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]
set_property physical_name clk156 [ipx::get_port_maps CLK -of_objects [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]]
ipx::add_bus_parameter ASSOCIATED_BUSIF [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]
set_property value m_axis_mac:s_axis_mac [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects [ipx::get_bus_interfaces clk156 -of_objects [ipx::current_core]]]

# rst associated with 156MHz 
ipx::add_bus_interface areset_clk156 [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:signal:reset_rtl:1.0 [ipx::get_bus_interfaces areset_clk156 -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:reset:1.0 [ipx::get_bus_interfaces areset_clk156 -of_objects [ipx::current_core]]
set_property interface_mode slave [ipx::get_bus_interfaces areset_clk156 -of_objects [ipx::current_core]]
ipx::add_port_map RST [ipx::get_bus_interfaces areset_clk156 -of_objects [ipx::current_core]]
set_property physical_name areset_clk156 [ipx::get_port_maps RST -of_objects [ipx::get_bus_interfaces areset_clk156 -of_objects [ipx::current_core]]]
ipx::add_bus_parameter POLARITY [ipx::get_bus_interfaces areset_clk156 -of_objects [ipx::current_core]]
set_property value ACTIVE_HIGH [ipx::get_bus_parameters POLARITY -of_objects [ipx::get_bus_interfaces areset_clk156 -of_objects [ipx::current_core]]]

# axis clk - auto inferred as axis_signal_aclk -- bug of 2014.4
ipx::add_bus_parameter ASSOCIATED_BUSIF [ipx::get_bus_interfaces axis_aclk -of_objects [ipx::current_core]]
set_property value m_axis_pipe:s_axis_pipe [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects [ipx::get_bus_interfaces axis_aclk -of_objects [ipx::current_core]]]

# rst associated with axis clk - auto inferred

# BUS parameters
ipx::add_bus_parameter TDATA_NUM_BYTES [ipx::get_bus_interfaces m_axis_pipe -of_objects [ipx::current_core]]
set_property description {TDATA Width (bytes)} [ipx::get_bus_parameters TDATA_NUM_BYTES -of_objects [ipx::get_bus_interfaces m_axis_pipe -of_objects [ipx::current_core]]]
set_property value 32 [ipx::get_bus_parameters TDATA_NUM_BYTES -of_objects [ipx::get_bus_interfaces m_axis_pipe -of_objects [ipx::current_core]]]

# Write IP Core xml to File system
ipx::check_integrity [ipx::current_core]
write_peripheral [ipx::current_core]

# Generate GUI Configuration Files
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

close_project
exit
