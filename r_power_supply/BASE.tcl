######################################################################
# power_supply OBinterface

package require Itcl
namespace eval device_role::power_supply {

itcl::class base {
  inherit device_role::base
  proc test_id {id} {}
  constructor {args} { chain {*}$args }

  # variables which should be filled by driver:
  public variable max_i; # max current
  public variable min_i; # min current
  public variable max_v; # max voltage
  public variable min_v; # min voltage
  public variable min_i_step; # min step in current
  public variable min_v_step; # min step in voltage
  public variable i_prec; # current precision
                          # (how measured value can deviate from set value)

  # methods which should be defined by driver:
  method set_volt {val} {}; # set maximum voltage
  method set_curr {val} {}; # set current
  method set_ovp  {val} {}; # set/unset overvoltage protaction
  method set_ocp  {val} {}; # set/unset overcurrent protection
  method get_curr {} {};    # measure actual value of voltage
  method get_volt {} {};    # measure actual value of current

  ## cc_reset -- bring the device into a controlled state in a constant current mode.
  # If device in constant current mode it should do nothing.
  # If OVP is triggered, then set current to actial current value,
  # reset the OVP condition and and turn the output on.
  # This function should not do any current jumps.
  method cc_reset {} {}

  # same for CV mode
  method cv_reset {} {}

  # turn output off
  method off {} {}

  # get_stat -- get device status (short string to be shown in the interface).
  # Can have different values, depending on the device:
  #  CV  - constant voltage mode
  #  CC  - constant current mode
  #  OFF - turned off
  #  OV  - overvoltage protection triggered
  #  OC  - overcurent protection triggered
  # ...
  method get_stat {} {};
}

}; # namespace
