######################################################################
# HP/Agilent/Keysight 1- and 2-channel generators

package require Itcl
package require Device2
namespace eval device_role::dc_source {

itcl::class keysight_gen {
  inherit keysight_gen base
  proc test_id {id} {keysight_gen::test_id $id}
  # we use Device from keysight_gen class
  method get_device {} {return $keysight_gen::dev}

  constructor {d ch id} {keysight_gen::constructor $d $ch $id} {
    set max_v 10
    set min_v -10
    set min_v_step 0.001
    dev_set_par $dev "${sour_pref}BURST:STATE" "0"
    dev_set_par $dev "${sour_pref}VOLT:UNIT" "VPP"
    dev_set_par $dev "OUTP${chan}:LOAD"      "INF"
    dev_set_par $dev "${sour_pref}FUNC"      "DC"
  }

  method set_volt {val} {
    dev_set_par $dev "${sour_pref}VOLT:OFFS" $val
    dev_set_par $dev "OUTP${chan}" "1"
  }
  method off {} {
    dev_set_par $dev "${sour_pref}VOLT:OFFS" 0
    dev_set_par $dev "OUTP${chan}" "0"
  }
  method get_volt {} {
    if {[Device2::ask $dev "OUTP${chan}?"] == 0} {return 0}
    return [Device2::ask $dev "${sour_pref}VOLT:OFFS? "]
  }
}

}; # namespace
