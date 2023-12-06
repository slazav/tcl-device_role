######################################################################
# gauge interface

package require Itcl
namespace eval device_role::gauge {

itcl::class base {
  inherit device_role::base
  proc test_id {id} {}


  ##################
  # variables to be set in the driver:
  variable valnames; # Names of returned values (list)

  # Number of values returned by get command
  method get_val_num {} {
    return [llength valnames]
  }

  # Return text name of the n-th value
  # For lockin it can be X or Y,
  # For multi-channel ADC it could be CH1, CH2, etc.
  method get_val_name {n} {
    if {$n<0 || $n>=[llength valnames]} {
      error "get_val_name: value number $n is out of range 0..[llength valnames]"}
    return [lindex $valnames $n]
  }


  ##################
  # methods which should be defined by driver:
  method get {} {}; # do the measurement, return one or more numbers

  method get_auto {} {}; # set the range automatically, do the measurement

  method list_ranges  {} {}; # get list of possible range settings
  method list_tconsts {} {}; # get list of possible time constant settings

  method set_range  {val} {}; # set the range
  method set_tconst {val} {}; # set the time constant
  method get_range  {} {}; # get current range setting
  method get_tconst {} {}; # get current time constant setting

  method get_status {} {return ""}; # get current status
  method get_status_raw {} {return 0};
}
}; # namespace
