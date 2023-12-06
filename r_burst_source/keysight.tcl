######################################################################
# HP/Agilent/Keysight 1- and 2-channel generators

package require Itcl
package require Device2
namespace eval device_role::burst_source {

itcl::class keysight {
  inherit keysight_gen base
  proc test_id {id} {keysight_gen::test_id $id}
  # we use Device from keysight_gen class
  method get_device {} {return $keysight_gen::dev}

  constructor {d ch id}  {keysight_gen::constructor $d $ch $id} {
    set max_v 20
    set min_v 0.002
    ## Burst mode with BUS trigger.
    dev_set_par $dev "${sour_pref}FUNC"        "SIN"; # should be before switching to BURST mode
    dev_set_par $dev "${sour_pref}VOLT:UNIT"   "VPP"
    dev_set_par $dev "${sour_pref}PHASE"       0; # BURST mode requires zero phase!
    dev_set_par $dev "OUTP${chan}:LOAD"        "INF"
    dev_set_par $dev "TRIG:SOURCE"             "BUS"
    dev_set_par $dev "${sour_pref}BURST:STATE" "1"
    dev_set_par $dev "${sour_pref}BURST:MODE"  "TRIG"
    dev_set_par $dev "OUTP:SYNC"         1
    dev_set_par $dev "OUTP${chan}"       1
  }

  method set_burst {fre amp cyc {offs 0} {ph 0}} {
    dev_set_par $dev "${sour_pref}BURST:NCYC"  $cyc
    dev_set_par $dev "${sour_pref}FREQ"        $fre
    dev_set_par $dev "${sour_pref}VOLT"        $amp
    dev_set_par $dev "${sour_pref}VOLT:OFFS"   $offs
    dev_set_par $dev "${sour_pref}BURST:PHASE" $ph
  }

  method do_burst {} {
    Device2::ask $dev *TRG
  }

  method get_volt  {} { return [Device2::ask $dev "${sour_pref}VOLT?"] }
  method get_freq  {} { return [Device2::ask $dev "${sour_pref}FREQ?"] }
  method get_offs  {} { return [Device2::ask $dev "${sour_pref}VOLT:OFFS?"] }
  method get_cycl  {} { return [Device2::ask $dev "${sour_pref}BURST:NCYC?"] }
  method get_phase {} { return [Device2::ask $dev "${sour_pref}BURST:PHASE?"] }

  method set_volt  {v} { dev_set_par $dev "${sour_pref}VOLT" $v }
  method set_freq  {v} { dev_set_par $dev "${sour_pref}FREQ" $v }
  method set_offs  {v} { dev_set_par $dev "${sour_pref}VOLT:OFFS"  $v }
  method set_cycl  {v} { dev_set_par $dev "${sour_pref}BURST:NCYC" $v }
  method set_phase {v} { dev_set_par $dev "${sour_pref}BURST:PHASE" $v }
}

}; # namespace
