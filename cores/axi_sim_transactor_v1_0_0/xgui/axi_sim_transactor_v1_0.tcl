# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "EXPECT_FILE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "LOG_FILE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "STIM_FILE" -parent ${Page_0}


}

proc update_PARAM_VALUE.EXPECT_FILE { PARAM_VALUE.EXPECT_FILE } {
	# Procedure called to update EXPECT_FILE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.EXPECT_FILE { PARAM_VALUE.EXPECT_FILE } {
	# Procedure called to validate EXPECT_FILE
	return true
}

proc update_PARAM_VALUE.LOG_FILE { PARAM_VALUE.LOG_FILE } {
	# Procedure called to update LOG_FILE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LOG_FILE { PARAM_VALUE.LOG_FILE } {
	# Procedure called to validate LOG_FILE
	return true
}

proc update_PARAM_VALUE.STIM_FILE { PARAM_VALUE.STIM_FILE } {
	# Procedure called to update STIM_FILE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.STIM_FILE { PARAM_VALUE.STIM_FILE } {
	# Procedure called to validate STIM_FILE
	return true
}


proc update_MODELPARAM_VALUE.STIM_FILE { MODELPARAM_VALUE.STIM_FILE PARAM_VALUE.STIM_FILE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.STIM_FILE}] ${MODELPARAM_VALUE.STIM_FILE}
}

proc update_MODELPARAM_VALUE.EXPECT_FILE { MODELPARAM_VALUE.EXPECT_FILE PARAM_VALUE.EXPECT_FILE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.EXPECT_FILE}] ${MODELPARAM_VALUE.EXPECT_FILE}
}

proc update_MODELPARAM_VALUE.LOG_FILE { MODELPARAM_VALUE.LOG_FILE PARAM_VALUE.LOG_FILE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LOG_FILE}] ${MODELPARAM_VALUE.LOG_FILE}
}

