######################################################################
# HP/Agilent/Keysight 1- and 2-channel generators

package require Itcl
package require Device2
namespace eval device_role::burst_source {

itcl::class keysight {
  inherit base
  proc test_id {id} { return [keysight_gen_model $id] }
 
  method get_device {} {return $dev_name}

  variable spref
  constructor {args} {
    chain {*}$args
    set max_v 20
    set min_v 0.002
    set spref [keysight_gen_spref $dev_model $dev_chan]

    ## Burst mode with BUS trigger.
    dev_set_par $dev_name "${spref}FUNC"         "SIN"; # should be before switching to BURST mode
    dev_set_par $dev_name "${spref}VOLT:UNIT"    "VPP"
    dev_set_par $dev_name "${spref}PHASE"        0; # BURST mode requires zero phase!
    dev_set_par $dev_name "OUTP${dev_chan}:LOAD" "INF"
    dev_set_par $dev_name "TRIG:SOURCE"          "BUS"
    dev_set_par $dev_name "${spref}BURST:STATE"  "1"
    dev_set_par $dev_name "${spref}BURST:MODE"   "TRIG"
    dev_set_par $dev_name "OUTP:SYNC"            1
    dev_set_par $dev_name "OUTP${dev_chan}"      1
  }

  method set_burst {fre amp cyc {offs 0} {ph 0}} {
    dev_set_par $dev_name "${spref}BURST:NCYC"  $cyc
    dev_set_par $dev_name "${spref}FREQ"        $fre
    dev_set_par $dev_name "${spref}VOLT"        $amp
    dev_set_par $dev_name "${spref}VOLT:OFFS"   $offs
    dev_set_par $dev_name "${spref}BURST:PHASE" $ph
  }

  method do_burst {} {
    Device2::ask $dev_name *TRG
  }

  method get_volt  {} { return [Device2::ask $dev_name "${spref}VOLT?"] }
  method get_freq  {} { return [Device2::ask $dev_name "${spref}FREQ?"] }
  method get_offs  {} { return [Device2::ask $dev_name "${spref}VOLT:OFFS?"] }
  method get_cycl  {} { return [Device2::ask $dev_name "${spref}BURST:NCYC?"] }
  method get_phase {} { return [Device2::ask $dev_name "${spref}BURST:PHASE?"] }

  method set_volt  {v} { dev_set_par $dev_name "${spref}VOLT" $v }
  method set_freq  {v} { dev_set_par $dev_name "${spref}FREQ" $v }
  method set_offs  {v} { dev_set_par $dev_name "${spref}VOLT:OFFS"  $v }
  method set_cycl  {v} { dev_set_par $dev_name "${spref}BURST:NCYC" $v }
  method set_phase {v} { dev_set_par $dev_name "${spref}BURST:PHASE" $v }
}

}; # namespace
