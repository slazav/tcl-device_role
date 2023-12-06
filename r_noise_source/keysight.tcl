######################################################################
# HP/Agilent/Keysight 1- and 2-channel generators
# see d_keysight_gen.tcl

package require Itcl
package require Device2
namespace eval device_role::noise_source {

itcl::class keysight {
  inherit base
  proc test_id {id} { return [keysight_gen_model $id] }

  method get_device {} {return $dev}

  variable chan
  variable spref
  constructor {d ch id} {
    set dev $d
    set chan $ch
    set max_v 20
    set min_v 0.002
    set model [keysight_gen_model $id]
    set spref [keysight_gen_spref $model $ch]
    dev_set_par $dev "${spref}BURST:STATE" "0"
    dev_set_par $dev "${spref}VOLT:UNIT" "VPP"
    dev_set_par $dev "${spref}FUNC"      "NOIS"
    dev_set_par $dev "OUTP${chan}:LOAD"  "INF"
  }

  method set_noise {bw volt {offs 0}} {
    dev_set_par $dev "${spref}VOLT" $volt
    dev_set_par $dev "${spref}VOLT:OFFS" $offs
    dev_set_par $dev "${spref}FUNC:NOISE:BANDWIDTH" $bw
    dev_set_par $dev "OUTP${chan}" "1"
  }
  method off {} {
#    dev_set_par $dev "${spref}VOLT" $min_v
#    dev_set_par $dev "${spref}VOLT:OFFS" 0
#    dev_set_par $dev "${spref}FUNC:NOISE:BANDWIDTH" 10e6
    dev_set_par $dev "OUTP${chan}" "0"
  }
  method on {} {
#    dev_set_par $dev "${spref}VOLT" $old_v
#    dev_set_par $dev "${spref}VOLT:OFFS" $old_offs
#    dev_set_par $dev "${spref}FUNC:NOISE:BANDWIDTH" $old_bw
    dev_set_par $dev "OUTP${chan}" "1"
  }
  method get_volt {} {
    if {[Device2::ask $dev "OUTP${chan}?"] == 0} {return 0}
    return [Device2::ask $dev "${spref}VOLT?"]
  }
  method get_bw   {} {
    return [Device2::ask $dev "${spref}FUNC:NOISE:BANDWIDTH?"]
  }
  method get_offs {} {
    return [Device2::ask $dev "${spref}VOLT:OFFS?"]
  }
}

}; # namespace
