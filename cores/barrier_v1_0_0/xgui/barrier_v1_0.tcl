# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "INACTIVITY_TIMEOUT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "NUM_PORTS" -parent ${Page_0}


}

proc update_PARAM_VALUE.INACTIVITY_TIMEOUT { PARAM_VALUE.INACTIVITY_TIMEOUT } {
	# Procedure called to update INACTIVITY_TIMEOUT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.INACTIVITY_TIMEOUT { PARAM_VALUE.INACTIVITY_TIMEOUT } {
	# Procedure called to validate INACTIVITY_TIMEOUT
	return true
}

proc update_PARAM_VALUE.NUM_PORTS { PARAM_VALUE.NUM_PORTS } {
	# Procedure called to update NUM_PORTS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.NUM_PORTS { PARAM_VALUE.NUM_PORTS } {
	# Procedure called to validate NUM_PORTS
	return true
}


proc update_MODELPARAM_VALUE.NUM_PORTS { MODELPARAM_VALUE.NUM_PORTS PARAM_VALUE.NUM_PORTS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.NUM_PORTS}] ${MODELPARAM_VALUE.NUM_PORTS}
}

proc update_MODELPARAM_VALUE.INACTIVITY_TIMEOUT { MODELPARAM_VALUE.INACTIVITY_TIMEOUT PARAM_VALUE.INACTIVITY_TIMEOUT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.INACTIVITY_TIMEOUT}] ${MODELPARAM_VALUE.INACTIVITY_TIMEOUT}
}

