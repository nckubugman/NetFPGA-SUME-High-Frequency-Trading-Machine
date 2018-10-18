# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "C_DEFAULT_DST_PORT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_DEFAULT_SRC_PORT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_DEFAULT_VALUE_ENABLE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_DPT_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_LEN_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_M_AXIS_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_M_AXIS_TUSER_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_SPT_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXIS_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S_AXIS_TUSER_WIDTH" -parent ${Page_0}


}

proc update_PARAM_VALUE.C_DEFAULT_DST_PORT { PARAM_VALUE.C_DEFAULT_DST_PORT } {
	# Procedure called to update C_DEFAULT_DST_PORT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_DEFAULT_DST_PORT { PARAM_VALUE.C_DEFAULT_DST_PORT } {
	# Procedure called to validate C_DEFAULT_DST_PORT
	return true
}

proc update_PARAM_VALUE.C_DEFAULT_SRC_PORT { PARAM_VALUE.C_DEFAULT_SRC_PORT } {
	# Procedure called to update C_DEFAULT_SRC_PORT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_DEFAULT_SRC_PORT { PARAM_VALUE.C_DEFAULT_SRC_PORT } {
	# Procedure called to validate C_DEFAULT_SRC_PORT
	return true
}

proc update_PARAM_VALUE.C_DEFAULT_VALUE_ENABLE { PARAM_VALUE.C_DEFAULT_VALUE_ENABLE } {
	# Procedure called to update C_DEFAULT_VALUE_ENABLE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_DEFAULT_VALUE_ENABLE { PARAM_VALUE.C_DEFAULT_VALUE_ENABLE } {
	# Procedure called to validate C_DEFAULT_VALUE_ENABLE
	return true
}

proc update_PARAM_VALUE.C_DPT_WIDTH { PARAM_VALUE.C_DPT_WIDTH } {
	# Procedure called to update C_DPT_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_DPT_WIDTH { PARAM_VALUE.C_DPT_WIDTH } {
	# Procedure called to validate C_DPT_WIDTH
	return true
}

proc update_PARAM_VALUE.C_LEN_WIDTH { PARAM_VALUE.C_LEN_WIDTH } {
	# Procedure called to update C_LEN_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_LEN_WIDTH { PARAM_VALUE.C_LEN_WIDTH } {
	# Procedure called to validate C_LEN_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M_AXIS_DATA_WIDTH { PARAM_VALUE.C_M_AXIS_DATA_WIDTH } {
	# Procedure called to update C_M_AXIS_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXIS_DATA_WIDTH { PARAM_VALUE.C_M_AXIS_DATA_WIDTH } {
	# Procedure called to validate C_M_AXIS_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_M_AXIS_TUSER_WIDTH { PARAM_VALUE.C_M_AXIS_TUSER_WIDTH } {
	# Procedure called to update C_M_AXIS_TUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXIS_TUSER_WIDTH { PARAM_VALUE.C_M_AXIS_TUSER_WIDTH } {
	# Procedure called to validate C_M_AXIS_TUSER_WIDTH
	return true
}

proc update_PARAM_VALUE.C_SPT_WIDTH { PARAM_VALUE.C_SPT_WIDTH } {
	# Procedure called to update C_SPT_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_SPT_WIDTH { PARAM_VALUE.C_SPT_WIDTH } {
	# Procedure called to validate C_SPT_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXIS_DATA_WIDTH { PARAM_VALUE.C_S_AXIS_DATA_WIDTH } {
	# Procedure called to update C_S_AXIS_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXIS_DATA_WIDTH { PARAM_VALUE.C_S_AXIS_DATA_WIDTH } {
	# Procedure called to validate C_S_AXIS_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S_AXIS_TUSER_WIDTH { PARAM_VALUE.C_S_AXIS_TUSER_WIDTH } {
	# Procedure called to update C_S_AXIS_TUSER_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXIS_TUSER_WIDTH { PARAM_VALUE.C_S_AXIS_TUSER_WIDTH } {
	# Procedure called to validate C_S_AXIS_TUSER_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.C_M_AXIS_DATA_WIDTH { MODELPARAM_VALUE.C_M_AXIS_DATA_WIDTH PARAM_VALUE.C_M_AXIS_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M_AXIS_DATA_WIDTH}] ${MODELPARAM_VALUE.C_M_AXIS_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXIS_DATA_WIDTH { MODELPARAM_VALUE.C_S_AXIS_DATA_WIDTH PARAM_VALUE.C_S_AXIS_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXIS_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S_AXIS_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M_AXIS_TUSER_WIDTH { MODELPARAM_VALUE.C_M_AXIS_TUSER_WIDTH PARAM_VALUE.C_M_AXIS_TUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_M_AXIS_TUSER_WIDTH}] ${MODELPARAM_VALUE.C_M_AXIS_TUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXIS_TUSER_WIDTH { MODELPARAM_VALUE.C_S_AXIS_TUSER_WIDTH PARAM_VALUE.C_S_AXIS_TUSER_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S_AXIS_TUSER_WIDTH}] ${MODELPARAM_VALUE.C_S_AXIS_TUSER_WIDTH}
}

proc update_MODELPARAM_VALUE.C_LEN_WIDTH { MODELPARAM_VALUE.C_LEN_WIDTH PARAM_VALUE.C_LEN_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_LEN_WIDTH}] ${MODELPARAM_VALUE.C_LEN_WIDTH}
}

proc update_MODELPARAM_VALUE.C_SPT_WIDTH { MODELPARAM_VALUE.C_SPT_WIDTH PARAM_VALUE.C_SPT_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_SPT_WIDTH}] ${MODELPARAM_VALUE.C_SPT_WIDTH}
}

proc update_MODELPARAM_VALUE.C_DPT_WIDTH { MODELPARAM_VALUE.C_DPT_WIDTH PARAM_VALUE.C_DPT_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_DPT_WIDTH}] ${MODELPARAM_VALUE.C_DPT_WIDTH}
}

proc update_MODELPARAM_VALUE.C_DEFAULT_VALUE_ENABLE { MODELPARAM_VALUE.C_DEFAULT_VALUE_ENABLE PARAM_VALUE.C_DEFAULT_VALUE_ENABLE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_DEFAULT_VALUE_ENABLE}] ${MODELPARAM_VALUE.C_DEFAULT_VALUE_ENABLE}
}

proc update_MODELPARAM_VALUE.C_DEFAULT_SRC_PORT { MODELPARAM_VALUE.C_DEFAULT_SRC_PORT PARAM_VALUE.C_DEFAULT_SRC_PORT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_DEFAULT_SRC_PORT}] ${MODELPARAM_VALUE.C_DEFAULT_SRC_PORT}
}

proc update_MODELPARAM_VALUE.C_DEFAULT_DST_PORT { MODELPARAM_VALUE.C_DEFAULT_DST_PORT PARAM_VALUE.C_DEFAULT_DST_PORT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_DEFAULT_DST_PORT}] ${MODELPARAM_VALUE.C_DEFAULT_DST_PORT}
}

