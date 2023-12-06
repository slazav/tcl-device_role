######################################################################
# HP/Agilent/Keysight 1- and 2-channel generators

package require Itcl
package require Device2
namespace eval device_role::dgen {

itcl::class keysight {
  inherit base
  proc test_id {id} { return [keysight_gen_model $id] }

  method get_device {} {return $dev_name}

  variable dev_ac1
  variable dev_ac2

  constructor {args} {
    chain {*}$args

    # Only two-channel models are supported.
    if {$dev_model != {33510B} &&\
        $dev_model != {33522A}} {
      error "device_role::dgen::keysight not a 2-channel model: $dev_model" }

    if {$dev_chan != {}} {error "bad channel setting: $dev_chan"}

    set dev_ac1 [DeviceRole $dev_name:1 ac_source]
    set dev_ac2 [DeviceRole $dev_name:2 ac_source]
    # this is the only non-trivial setting:
    dev_set_par $dev_name "FREQ:COUP" "1"
  }

  # Frequencies are coupled, only one should be set:
  method set_freq {v}  { $dev_ac1 set_freq $v}

}

}; # namespace
