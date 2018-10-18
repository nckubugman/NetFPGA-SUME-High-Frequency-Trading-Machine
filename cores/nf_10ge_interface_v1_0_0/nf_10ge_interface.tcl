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

# Set variables.

set design		 nf_10ge_interface
set device		 xc7vx690tffg1761-3
set proj_dir		 ./ip_proj
set repo_dir		 ../
set top_module_name  nf_10g_interface
set ip_version		 1.00
set lib_name		 NetFPGA

# CORE CONFIG parameters
set sharedLogic		"FALSE"
set tdataWidth		256

# Project setting.
create_project -name ${design} -force -dir "./${proj_dir}" -part ${device} 

set_property source_mgmt_mode All [current_project]  
set_property top ${top_module_name} [current_fileset]

# local IP repo
set_property ip_repo_paths $::env(SUME_FOLDER)/lib/hw/  [current_fileset]
update_ip_catalog

# IP build.
read_verilog "./hdl/nf_10g_interface_cpu_regs_defines.v"
read_verilog "./hdl/nf_10g_interface_cpu_regs.v"
read_verilog "./hdl/nf_10g_interface_block.v"
read_verilog "./hdl/nf_10g_interface.v"

update_compile_order -fileset sources_1

############## Package IP ######################

ipx::package_project

set_property name ${design} [ipx::current_core]
set_property vendor {NetFPGA} [ipx::current_core]
set_property library ${lib_name} [ipx::current_core]
set_property version ${ip_version} [ipx::current_core]
set_property display_name ${design} [ipx::current_core]
set_property description ${design} [ipx::current_core]
set_property taxonomy {{/NetFPGA/Data_Path}} [ipx::current_core]
set_property vendor_display_name {NetFPGA} [ipx::current_core]
set_property company_url {www.netfpga.org} [ipx::current_core]
set_property supported_families {{virtex7} {Production}} [ipx::current_core]

ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces m_axis -of_objects [ipx::current_core]]
ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axis -of_objects [ipx::current_core]]

#Add subcores
ipx::add_subcore xilinx.com:ip:axi_10g_ethernet:3.1 [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_subcore xilinx.com:ip:axi_10g_ethernet:3.1 [ipx::get_file_groups xilinx_anylanguagebehavioralsimulation -of_objects [ipx::current_core]]
 
ipx::add_subcore xilinx.com:ip:fifo_generator:13.1 [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_subcore xilinx.com:ip:fifo_generator:13.1 [ipx::get_file_groups xilinx_anylanguagebehavioralsimulation -of_objects [ipx::current_core]]

ipx::add_subcore xilinx.com:ip:util_vector_logic:2.0 [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_subcore xilinx.com:ip:util_vector_logic:2.0 [ipx::get_file_groups xilinx_anylanguagebehavioralsimulation -of_objects [ipx::current_core]]

ipx::add_subcore NetFPGA:NetFPGA:nf_axis_converter:1.00 [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_subcore NetFPGA:NetFPGA:nf_axis_converter:1.00 [ipx::get_file_groups xilinx_anylanguagebehavioralsimulation -of_objects [ipx::current_core]]

ipx::add_subcore NetFPGA:NetFPGA:nf_10g_attachment:1.0 [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_subcore NetFPGA:NetFPGA:nf_10g_attachment:1.0 [ipx::get_file_groups xilinx_anylanguagebehavioralsimulation -of_objects [ipx::current_core]]
 
ipx::add_subcore NetFPGA:NetFPGA:fallthrough_small_fifo:1.00 [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_subcore NetFPGA:NetFPGA:fallthrough_small_fifo:1.00 [ipx::get_file_groups xilinx_anylanguagebehavioralsimulation -of_objects [ipx::current_core]]

# auto infer params
ipx::infer_user_parameters [ipx::current_core]

# manually infer remaining
# Axis clk
ipx::add_bus_parameter ASSOCIATED_BUSIF [ipx::get_bus_interfaces core_clk -of_objects [ipx::current_core]]
set_property value m_axis:s_axis [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects [ipx::get_bus_interfaces core_clk -of_objects [ipx::current_core]]]


update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

ipx::merge_project_changes files [ipx::current_core]

ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]

close_project
exit

