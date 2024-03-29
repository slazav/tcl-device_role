######################################################################
# Siglent SDG 2-channel generators
#
# Siglent Technologies,SDG1032X,SDG1XDCC6R1389,1.01.01.33R1B10
#
# Channels: "", 1, 2
# If channel is empty, use channel 1 for signal, channel 2 for sync.
# This could be useful because rear-panel sync only produce 50ns pulses
# and only for f<10MHz.

package require Itcl
package require Device2
namespace eval device_role::ac_source {

itcl::class siglent {
  inherit base
  proc test_id {id} {
    if {[regexp {,SDG1032X,} $id]} {return {SDG1032X}}
    if {[regexp {,SDG1062X,} $id]} {return {SDG1062X}}; # not tested
  }

  variable ch2sync 0; # use ch2 for TTL sync signal
  constructor {args} {
    chain {*}$args
    set max_v 20
    set min_v 0.002
    if {$dev_chan=={}} {
      set dev_chan 1
      set ch2sync 1
    }

    if {$dev_chan!=1 && $dev_chan!=2} { error "unsupported channel: $dev_chan" }

    # basic sine output, HiZ
    Device2::ask $dev_name "C${dev_chan}:BSWV WVTP,SINE"
    Device2::ask $dev_name "C${dev_chan}:MDWV STATE,OFF"
    Device2::ask $dev_name "C${dev_chan}:SWWV STATE,OFF"
    Device2::ask $dev_name "C${dev_chan}:BTWV STATE,OFF"
    Device2::ask $dev_name "C${dev_chan}:ARWV STATE,OFF"
    Device2::ask $dev_name "C${dev_chan}:HARM HARMSTATE,OFF"
    Device2::ask $dev_name "C${dev_chan}:CMBN OFF"
    Device2::ask $dev_name "C${dev_chan}:INVT OFF"
    Device2::ask $dev_name "C${dev_chan}:OUTP LOAD,HZ"
    Device2::ask $dev_name "C${dev_chan}:OUTP PLRT,NOR"

    # use chan2 as 5V square sync signal
    if {$ch2sync} {
      Device2::ask $dev_name "C2:MDWV STATE,OFF"
      Device2::ask $dev_name "C2:SWWV STATE,OFF"
      Device2::ask $dev_name "C2:BTWV STATE,OFF"
      Device2::ask $dev_name "C2:ARWV STATE,OFF"
      Device2::ask $dev_name "C2:HARM HARMSTATE,OFF"
      Device2::ask $dev_name "C2:CMBN OFF"
      Device2::ask $dev_name "C2:INVT OFF"
      Device2::ask $dev_name "C2:OUTP LOAD,HZ"
      Device2::ask $dev_name "C2:OUTP PLRT,NOR"
      # 0->5V square
      Device2::ask $dev_name "C2:BSWV WVTP,SQUARE"
      Device2::ask $dev_name "C2:BSWV AMP,2.5"
      Device2::ask $dev_name "C2:BSWV OFST,2.5"
      Device2::ask $dev_name "C2:BSWV DUTY,50"
      Device2::ask $dev_name "C2:BSWV PHSE,0"
      # channel coupling
      Device2::ask $dev_name "COUP TRACE,OFF"
      Device2::ask $dev_name "COUP STATE,ON"
      Device2::ask $dev_name "COUP FCOUP,ON"
      Device2::ask $dev_name "COUP FDEV,0"
      Device2::ask $dev_name "COUP FRAT,1"
      Device2::ask $dev_name "COUP PCOUP,OFF"
      Device2::ask $dev_name "COUP ACOUP,OFF"
      # output on
      Device2::ask $dev_name "C2:OUTP ON"
    }
  }


  # get_* methods do NOT update interface.
  # If they are called regularly, it should not
  # prevent user from typing new values in the interface.
  method get_volt {}  {
    set l [Device2::ask $dev_name "C${dev_chan}:BSWV?"]
    regexp {,AMP,([0-9\.]+)V,} $l tmp v
    if {$ac_shift != 0} {set v [expr $v-$ac_shift]}
    return $v
  }
  method get_freq {} {
    set l [Device2::ask $dev_name "C${dev_chan}:BSWV?"]
    regexp {,FRQ,([0-9\.]+)HZ,} $l tmp v
    return $v
  }
  method get_offs {} {
    set l [Device2::ask $dev_name "C${dev_chan}:BSWV?"]
    regexp {,OFST,([0-9\.]+)V,} $l tmp v
    return $v
  }
  method get_phase {} {
    set l [Device2::ask $dev_name "C${dev_chan}:BSWV?"]
    regexp {,PHSE,([0-9\.]+)} $l tmp v
    return $v
  }
  method get_out {} {
    set l [Device2::ask $dev_name "C${dev_chan}:OUTP?"]
    regexp {OUTP (ON|OFF),} $l tmp v
    return [expr {$v eq {ON}}]
  }


  method set_ac {f v {o 0} {p {}}} {
    chain $f $v $o $p; # call method from base class to update interface
    if {$ac_shift != 0} {set v [expr $v+$ac_shift]}
    Device2::ask $dev_name "C${dev_chan}:BSWV FRQ,$f"
    Device2::ask $dev_name "C${dev_chan}:BSWV AMP,$v"
    Device2::ask $dev_name "C${dev_chan}:BSWV OFST,$o"
    if {$p ne {}} {
      set phse [expr $p-int($p/360.0)*360]
      Device2::ask $dev_name "C${dev_chan}:BSWV PHSE,$phse"
    }
    if {! [get_out]} { Device2::ask $dev_name "C${dev_chan}:OUTP ON" }
  }
  method set_volt {v} {
    chain $v
    if {$ac_shift != 0} {set v [expr $v+$ac_shift]}
    Device2::ask $dev_name "C${dev_chan}:BSWV AMP,$v"
  }
  method set_freq {v} {
    chain $v
    Device2::ask $dev_name "C${dev_chan}:BSWV FRQ,$v"
  }
  method set_offs {v}  {
    chain $v
    Device2::ask $dev_name "C${dev_chan}:BSWV OFST,$v"
  }
  method set_phase {v} {
    chain $v
    set v [expr $v-int($v/360.0)*360]
    Device2::ask $dev_name "C${dev_chan}:BSWV PHSE,$v"
  }
  method set_out {v} {
  # switch to burst mode to reduce signal leakage?
    chain $v
    Device2::ask $dev_name "C${dev_chan}:OUTP [expr {$v?{ON}:{OFF}}]"
  }

  method set_sync {v} {
    if {$ch2sync} {
      Device2::ask $dev_name "C2:OUT [expr {$v?{ON}:{OFF}}]"
    }\
    else {
      Device2::ask $dev_name "C${dev_chan}:SYNC [expr {$v?{ON}:{OFF}}]"
    }
  }
}

}; # namespace
