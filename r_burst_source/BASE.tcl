######################################################################
# burst_source interface

package require Itcl
namespace eval device_role::burst_source {

itcl::class base {
  inherit device_role::base
  proc test_id {id} {}
  constructor {args} { chain {*}$args }

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage

  # methods which should be defined by driver:
  method set_burst      {freq volt cycles {offs 0} {ph 0}} {};
  method do_burst {} {};

  method set_volt  {v} {};    # set voltage value
  method set_freq  {v} {};    # set frequency value
  method set_offs  {v} {};    # set offset value
  method set_cycl  {v} {};    # set cycles value
  method set_phase {v} {};    # set phase value

  method get_volt  {} {};    # get voltage value
  method get_freq  {} {};    # get frequency value
  method get_offs  {} {};    # get offset value
  method get_cycl  {} {};    # get cycles value
  method get_phase {} {};    # get phase value
}

}; # namespace
