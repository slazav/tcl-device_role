######################################################################
# HP/Agilent/Keysight 1- and 2-channel generators

package require Itcl
package require Device2
namespace eval device_role::dc_source {

itcl::class keysight_gen {
  inherit base
  proc test_id {id} { return [keysight_gen_model $id] }

  # we use Device from keysight_gen class
  method get_device {} {return $dev}

  variable chan
  variable spref
  constructor {d ch id} {
    set dev $d
    set chan $ch
    set max_v 10
    set min_v -10
    set min_v_step 0.001
    set model [keysight_gen_model $id]
    set spref [keysight_gen_spref $model $ch]
    dev_set_par $dev "${spref}BURST:STATE" "0"
    dev_set_par $dev "${spref}VOLT:UNIT" "VPP"
    dev_set_par $dev "OUTP${chan}:LOAD"  "INF"
    dev_set_par $dev "${spref}FUNC"      "DC"
  }

  method set_volt {val} {
    dev_set_par $dev "${spref}VOLT:OFFS" $val
    dev_set_par $dev "OUTP${chan}" "1"
  }
  method off {} {
    dev_set_par $dev "${spref}VOLT:OFFS" 0
    dev_set_par $dev "OUTP${chan}" "0"
  }
  method get_volt {} {
    if {[Device2::ask $dev "OUTP${chan}?"] == 0} {return 0}
    return [Device2::ask $dev "${spref}VOLT:OFFS? "]
  }
}

}; # namespace
