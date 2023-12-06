######################################################################
# HP/Agilent/Keysight 1- and 2-channel generators
# see d_keysight_gen.tcl

package require Itcl
package require Device2
namespace eval device_role::noise_source {

itcl::class keysight {
  inherit keysight_gen base
  proc test_id {id} {keysight_gen::test_id $id}
  # we use Device from keysight_gen class
  method get_device {} {return $keysight_gen::dev}

  constructor {d ch id} {keysight_gen::constructor $d $ch $id} {
    set max_v 20
    set min_v 0.002
    dev_set_par $dev "${sour_pref}BURST:STATE" "0"
    dev_set_par $dev "${sour_pref}VOLT:UNIT" "VPP"
    dev_set_par $dev "${sour_pref}FUNC"      "NOIS"
    dev_set_par $dev "OUTP${chan}:LOAD"      "INF"
  }

  method set_noise {bw volt {offs 0}} {
    dev_set_par $dev "${sour_pref}VOLT" $volt
    dev_set_par $dev "${sour_pref}VOLT:OFFS" $offs
    dev_set_par $dev "${sour_pref}FUNC:NOISE:BANDWIDTH" $bw
    dev_set_par $dev "OUTP${chan}" "1"
  }
  method off {} {
#    dev_set_par $dev "${sour_pref}VOLT" $min_v
#    dev_set_par $dev "${sour_pref}VOLT:OFFS" 0
#    dev_set_par $dev "${sour_pref}FUNC:NOISE:BANDWIDTH" 10e6
    dev_set_par $dev "OUTP${chan}" "0"
  }
  method on {} {
#    dev_set_par $dev "${sour_pref}VOLT" $old_v
#    dev_set_par $dev "${sour_pref}VOLT:OFFS" $old_offs
#    dev_set_par $dev "${sour_pref}FUNC:NOISE:BANDWIDTH" $old_bw
    dev_set_par $dev "OUTP${chan}" "1"
  }
  method get_volt {} {
    if {[Device2::ask $dev "OUTP${chan}?"] == 0} {return 0}
    return [Device2::ask $dev "${sour_pref}VOLT?"]
  }
  method get_bw   {} {
    return [Device2::ask $dev "${sour_pref}FUNC:NOISE:BANDWIDTH?"]
  }
  method get_offs {} {
    return [Device2::ask $dev "${sour_pref}VOLT:OFFS?"]
  }
}

}; # namespace
