######################################################################
# dc_source interface

package require Itcl
namespace eval device_role::dc_source {

itcl::class base {
  inherit device_role::base
  proc test_id {id} {}
  constructor {args} { chain {*}$args }

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage
  public variable min_v_step; # min step in voltage

  # methods which should be defined by driver:
  method set_volt {val} {}; # set voltage
  method get_volt {} {};    # measure actual voltage value
}

}; # namespace
