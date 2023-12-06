######################################################################
# HP/Agilent/Keysight 1- and 2-channel generators

package require Itcl
package require Device2
namespace eval device_role::dgen {

itcl::class keysight {
  inherit keysight_gen base
  proc test_id {id} { keysight_gen::test_id $id }

  # we use Device from keysight_gen class
  method get_device {} {return $keysight_gen::dev}

  variable dev_ac1
  variable dev_ac2

  constructor {d ch id} {
    # Get the model name from id (using test_id function).
    # Only two-channel models are supported.
    set model [test_id $id]
    if {$model != {33510B} &&\
        $model != {33522A}} {
      error "device_role::dgen::keysight not a 2-channel model: $model" }

    if {$ch != {}} {error "bad channel setting: $ch"}
    set dev $d

    set dev_ac1 [DeviceRole $dev:1 ac_source]
    set dev_ac2 [DeviceRole $dev:2 ac_source]
    # this is the only non-trivial setting:
    dev_set_par $dev "FREQ:COUP" "1"
  }

  # Frequencies are coupled, only one should be set:
  method set_freq {v}  { $dev_ac1 sel_freq $v}

}

}; # namespace
