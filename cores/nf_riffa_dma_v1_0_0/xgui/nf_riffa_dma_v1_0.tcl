# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "C_AXIS_TDATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_AXIS_TKEEP_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_AXIS_TUSER_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_BASEADDR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_LOG_NUM_TAGS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_MAX_PAYLOAD_BYTES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_M_AXI_LITE_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_M_AXI_LITE_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_M_AXI_LITE_STRB_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_NUM_CHNL" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_PCI_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_PREAM_VALUE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXI_DATA_WIDTH" -parent ${Page_0}


}

proc update_PARAM_VALUE.C_AXIS_TDATA_WIDTH { PARAM_VALUE.C_AXIS_TDATA_WIDTH } {
	# Procedure called to update C_AXIS_TDATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIS_TDATA_WIDTH { PARAM_VALUE.C_AXIS_TDATA_WIDTH } {
	# Procedure called to validate C_AXIS_TDATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIS_TKEEP_WIDTH { PARAM_VALUE.C_AXIS_TKEEP_WIDTH } {
	# Procedure called to update C_AXIS_TKEEP_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIS_TKEEP_WIDTH { PARAM_VALUE.C_AXIS_TKEEP_WIDTH } {
	# Procedure called to validate C_AXIS_TKEEP_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXIS_TUSER_WIDTH { PARAM_VALUE.C_AXIS_TUSER_WIDTH } {
	# Procedure called to update C_AXIS_TUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXIS_TUSER_WIDTH { PARAM_VALUE.C_AXIS_TUSER_WIDTH } {
	# Procedure called to validate C_AXIS_TUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_BASEADDR { PARAM_VALUE.C_BASEADDR } {
	# Procedure called to update C_BASEADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_BASEADDR { PARAM_VALUE.C_BASEADDR } {
	# Procedure called to validate C_BASEADDR
	return true
}

proc update_PARAM_VALUE.C_LOG_NUM_TAGS { PARAM_VALUE.C_LOG_NUM_TAGS } {
	# Procedure called to update C_LOG_NUM_TAGS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_LOG_NUM_TAGS { PARAM_VALUE.C_LOG_NUM_TAGS } {
	# Procedure called to validate C_LOG_NUM_TAGS
	return true
}

proc update_PARAM_VALUE.C_MAX_PAYLOAD_BYTES { PARAM_VALUE.C_MAX_PAYLOAD_BYTES } {
	# Procedure called to update C_MAX_PAYLOAD_BYTES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_MAX_PAYLOAD_BYTES { PARAM_VALUE.C_MAX_PAYLOAD_BYTES } {
	# Procedure called to validate C_MAX_PAYLOAD_BYTES
	return true
}

proc update_PARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH { PARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH } {
	# Procedure called to update C_M_AXI_LITE_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH { PARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH } {
	# Procedure called to validate C_M_AXI_LITE_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH { PARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH } {
	# Procedure called to update C_M_AXI_LITE_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH { PARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH } {
	# Procedure called to validate C_M_AXI_LITE_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M_AXI_LITE_STRB_WIDTH { PARAM_VALUE.C_M_AXI_LITE_STRB_WIDTH } {
	# Procedure called to update C_M_AXI_LITE_STRB_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXI_LITE_STRB_WIDTH { PARAM_VALUE.C_M_AXI_LITE_STRB_WIDTH } {
	# Procedure called to validate C_M_AXI_LITE_STRB_WIDTH
	return true
}

proc update_PARAM_VALUE.C_NUM_CHNL { PARAM_VALUE.C_NUM_CHNL } {
	# Procedure called to update C_NUM_CHNL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_NUM_CHNL { PARAM_VALUE.C_NUM_CHNL } {
	# Procedure called to validate C_NUM_CHNL
	return true
}

proc update_PARAM_VALUE.C_PCI_DATA_WIDTH { PARAM_VALUE.C_PCI_DATA_WIDTH } {
	# Procedure called to update C_PCI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_PCI_DATA_WIDTH { PARAM_VALUE.C_PCI_DATA_WIDTH } {
	# Procedure called to validate C_PCI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_PREAM_VALUE { PARAM_VALUE.C_PREAM_VALUE } {
	# Procedure called to update C_PREAM_VALUE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_PREAM_VALUE { PARAM_VALUE.C_PREAM_VALUE } {
	# Procedure called to validate C_PREAM_VALUE
	return true
}

proc update_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to update C_S_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_ADDR_WIDTH { PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_S_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to update C_S_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_DATA_WIDTH { PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to validate C_S_AXI_DATA_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.C_NUM_CHNL { MODELPARAM_VALUE.C_NUM_CHNL PARAM_VALUE.C_NUM_CHNL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_NUM_CHNL}] ${MODELPARAM_VALUE.C_NUM_CHNL}
}

proc update_MODELPARAM_VALUE.C_PCI_DATA_WIDTH { MODELPARAM_VALUE.C_PCI_DATA_WIDTH PARAM_VALUE.C_PCI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_PCI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_PCI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_MAX_PAYLOAD_BYTES { MODELPARAM_VALUE.C_MAX_PAYLOAD_BYTES PARAM_VALUE.C_MAX_PAYLOAD_BYTES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_MAX_PAYLOAD_BYTES}] ${MODELPARAM_VALUE.C_MAX_PAYLOAD_BYTES}
}

proc update_MODELPARAM_VALUE.C_LOG_NUM_TAGS { MODELPARAM_VALUE.C_LOG_NUM_TAGS PARAM_VALUE.C_LOG_NUM_TAGS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_LOG_NUM_TAGS}] ${MODELPARAM_VALUE.C_LOG_NUM_TAGS}
}

proc update_MODELPARAM_VALUE.C_AXIS_TDATA_WIDTH { MODELPARAM_VALUE.C_AXIS_TDATA_WIDTH PARAM_VALUE.C_AXIS_TDATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIS_TDATA_WIDTH}] ${MODELPARAM_VALUE.C_AXIS_TDATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXIS_TKEEP_WIDTH { MODELPARAM_VALUE.C_AXIS_TKEEP_WIDTH PARAM_VALUE.C_AXIS_TKEEP_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIS_TKEEP_WIDTH}] ${MODELPARAM_VALUE.C_AXIS_TKEEP_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXIS_TUSER_WIDTH { MODELPARAM_VALUE.C_AXIS_TUSER_WIDTH PARAM_VALUE.C_AXIS_TUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXIS_TUSER_WIDTH}] ${MODELPARAM_VALUE.C_AXIS_TUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_PREAM_VALUE { MODELPARAM_VALUE.C_PREAM_VALUE PARAM_VALUE.C_PREAM_VALUE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_PREAM_VALUE}] ${MODELPARAM_VALUE.C_PREAM_VALUE}
}

proc update_MODELPARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH { MODELPARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH PARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_M_AXI_LITE_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH { MODELPARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH PARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH}] ${MODELPARAM_VALUE.C_M_AXI_LITE_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M_AXI_LITE_STRB_WIDTH { MODELPARAM_VALUE.C_M_AXI_LITE_STRB_WIDTH PARAM_VALUE.C_M_AXI_LITE_STRB_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M_AXI_LITE_STRB_WIDTH}] ${MODELPARAM_VALUE.C_M_AXI_LITE_STRB_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH PARAM_VALUE.C_S_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH PARAM_VALUE.C_S_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_BASEADDR { MODELPARAM_VALUE.C_BASEADDR PARAM_VALUE.C_BASEADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_BASEADDR}] ${MODELPARAM_VALUE.C_BASEADDR}
}

