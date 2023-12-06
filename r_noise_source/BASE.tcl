######################################################################
# noise_source interface

package require Itcl
namespace eval device_role::noise_source {

itcl::class base {
  inherit ::device_role::base
  proc test_id {id} {}

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage

  # methods which should be defined by driver:
  method set_noise {bw volt {offs 0}} {}; # set bandwidth, voltage and offset
  method get_volt  {} {};    # get voltage value
  method get_bw    {} {};    # get bandwidth value
  method get_offs  {} {};    # get bandwidth value
  method off       {} {};    # turn off the signal
  method on        {} {};    # turn on the signal
}

}; # namespace
