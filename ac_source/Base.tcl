######################################################################
# A ac_source role

package require Itcl
package require Device

namespace eval device_role::ac_source {

  ## Interface class. All power_supply driver classes are children of it
  itcl::class interface {
    inherit device_role::base_interface

    # variables which should be filled by driver:
    public variable max_v; # max voltage
    public variable min_v; # min voltage

    # methods which should be defined by driver:
    method set_ac {freq volt {offs 0}} {};      # reconfigure output, set frequency, voltage, offset
    method set_ac_fast {freq volt {offs 0}} {}; # set frequency, voltage, offset
    method off       {} {};    # turn off the signal

    method get_volt  {} {};    # get voltage value
    method get_freq  {} {};    # get frequency value
    method get_offs  {} {};    # get offset value
    method get_phase {} {};    # get phase

    method set_volt {v}  {}
    method set_freq {v}  {}
    method set_offs {v}  {}
    method set_phase {v} {}

    method set_sync  {state} {}; # set state of front-panel sync connector

  }
}
