######################################################################
# burst_source role

package require Itcl
package require Device2

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

itcl::class siglent {
  inherit interface
  proc test_id {id} {
    if {[regexp {,SDG1032X,} $id]} {return {SDG1032X}}
    if {[regexp {,SDG1062X,} $id]} {return {SDG1062X}}; # not tested
  }

  variable chan
  variable ch2sync 0; # use ch2 for TTL sync signal
  constructor {d ch id args} {
    set dev $d
    set max_v 20
    set min_v 0.002

    if {$ch!=1 && $ch!=2} { error "unsupported channel: $ch" }
    set chan $ch

    # basic sine output, HiZ
    $dev cmd "C${chan}:BSWV WVTP,SINE"
    $dev cmd "C${chan}:MDWV STATE,OFF"
    $dev cmd "C${chan}:SWWV STATE,OFF"
    $dev cmd "C${chan}:BTWV STATE,OFF"
    $dev cmd "C${chan}:ARWV STATE,OFF"
    $dev cmd "C${chan}:HARM HARMSTATE,OFF"
    $dev cmd "C${chan}:CMBN OFF"
    $dev cmd "C${chan}:INVT OFF"
    $dev cmd "C${chan}:OUTP LOAD,HZ"
    $dev cmd "C${chan}:OUTP PLRT,NOR"

    # set burst mode
    $dev cmd "C${chan}:BTWV CARR,WVTP,SIN"  # carrier waveform
    $dev cmd "C${chan}:BTWV GATE_NCYC,NCYC" # mode (GATE, NCYC)
    $dev cmd "C${chan}:BTWV TRSR,MAN" # trigger (EXT, INT, MAN)
    $dev cmd "C${chan}:BTWV DLAY,0"   # trigger delay,s
    $dev cmd "C${chan}:BTWV TRMD,RISE"  # Trigger out mode
    $dev cmd "C${chan}:BTWV STATE,ON"
  }

  method set_burst {fre amp ncyc {offs 0} {ph 0}} {
    $dev cmd "C${chan}:BTWV CARR,FRQ,$fre"  # carrier frequency
    $dev cmd "C${chan}:BTWV CARR,AMP,$amp"
    $dev cmd "C${chan}:BTWV CARR,OFST,$offs"
    $dev cmd "C${chan}:BTWV TIME,$ncyc"
    $dev cmd "C${chan}:BTWV STPS,$ph"
  }

  method do_burst {} {
    $dev cmd "C${chan}:BTWV MTRIG" # send manual trigger
  }

  method get_volt {}  {
    set l [$dev cmd "C${chan}:BTWV?"]
    regexp {,AMP,([0-9\.]+)V,} $l tmp v
    return $v
  }
  method get_freq {} {
    set l [$dev cmd "C${chan}:BTWV?"]
    regexp {,FRQ,([0-9\.]+)HZ,} $l tmp v
    return $v
  }
  method get_offs {} {
    set l [$dev cmd "C${chan}:BTWV?"]
    regexp {,OFST,([0-9\.]+)V,} $l tmp v
    return $v
  }
  method get_phase {} {
    set l [$dev cmd "C${chan}:BTWV?"]
    regexp {,STPS,([0-9\.]+)} $l tmp v
    return $v
  }
  method get_cycl {} {
    set l [$dev cmd "C${chan}:BTWV?"]
    regexp {,TIME,([0-9\.]+)} $l tmp v
    return $v
  }

  method set_volt {v} { $dev cmd "C${chan}:BTWV CARR,AMP,$v" }
  method set_freq {v} { $dev cmd "C${chan}:BTWV CARR,FRQ,$v" }
  method set_offs {v} { $dev cmd "C${chan}:BTWV CARR,OFST,$v" }
  method set_sycl {v} { $dev cmd "C${chan}:BTWV TIME,$v" }
  method set_phase {v} {
    set v [expr $v-int($v/360.0)*360]
    $dev cmd "C${chan}:BTWV STPS,$v"
  }

}

######################################################################
} # namespace
