######################################################################
# burst_source role

package require Itcl
package require Device

namespace eval device_role::burst_source {

######################################################################
## Interface class. All driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage

  # methods which should be defined by driver:
  method set_burst      {freq volt cycles {offs 0} {ph 0}} {};
  method do_burst {} {};

  method set_volt  {v} {};    # set voltage value
  method set_freq  {v} {};    # set frequency value
  method set_offs  {v} {};    # set offset value
  method set_cycl  {v} {};    # set cycles value
  method set_phase {v} {};    # set phase value

  method get_volt  {} {};    # get voltage value
  method get_freq  {} {};    # get frequency value
  method get_offs  {} {};    # get offset value
  method get_cycl  {} {};    # get cycles value
  method get_phase {} {};    # get phase value
}

######################################################################
# Test device. Does nothing

itcl::class TEST {
  inherit interface
  proc test_id {id} {}
  variable fre
  variable amp
  variable cyc
  variable offs
  variable ph

  constructor {d ch id} {
    set fre 1000
    set amp 0.1
    set cyc 10
    set offs 0
    set ph   0
    set max_v 10
    set min_v 0
  }

  method set_burst {f a c {o 0} {p 0}} {
    if {$a < $min_v} {set a $min_v}
    if {$a > $max_v} {set a $max_v}
    set fre  $f
    set amp  $a
    set cyc  $c
    set offs $o
    set ph   $p
  }

  method do_burst {} {}

  method get_volt {} { return $amp }
  method get_freq {} { return $fre }
  method get_offs {} { return $offs }
  method get_cycl {} { return $cyc }
  method get_phase {} { return $ph }

  method set_volt  {v} { set amp  $v }
  method set_freq  {v} { set fre  $v }
  method set_offs  {v} { set offs $v }
  method set_cycl  {v} { set cyc  $v }
  method set_phase {v} { set ph   $v }
}

######################################################################
# Use HP/Agilent/Keysight 1- and 2-channel generators as a ac_source.

itcl::class keysight {
  inherit keysight_gen interface
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
    $dev cmd *TRG
  }

  method get_volt  {} { return [$dev cmd "${sour_pref}VOLT?"] }
  method get_freq  {} { return [$dev cmd "${sour_pref}FREQ?"] }
  method get_offs  {} { return [$dev cmd "${sour_pref}VOLT:OFFS?"] }
  method get_cycl  {} { return [$dev cmd "${sour_pref}BURST:NCYC?"] }
  method get_phase {} { return [$dev cmd "${sour_pref}BURST:PHASE?"] }

  method set_volt  {v} { dev_set_par $dev "${sour_pref}VOLT" $v }
  method set_freq  {v} { dev_set_par $dev "${sour_pref}FREQ" $v }
  method set_offs  {v} { dev_set_par $dev "${sour_pref}VOLT:OFFS"  $v }
  method set_cycl  {v} { dev_set_par $dev "${sour_pref}BURST:NCYC" $v }
  method set_phase {v} { dev_set_par $dev "${sour_pref}BURST:PHASE" $v }
}

######################################################################
} # namespace
