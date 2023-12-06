######################################################################
# LakeShore 370 DC outputs
# ID string:
#   LSCI,MODEL370,370A5K,04102008
#
# 1. Heater output.
#
# The device is a current source. You set up heater resistior in
# the channel setting and control voltage on the heater.
#
# Channel setting: HTR<range>:<heater_resistance_ohm>
#   range:
#   1 - 31.6 uA
#   2 - 100 uA
#   3 - 316 uA
#   4 - 1 mA
#   5 - 3.16 mA
#   6 - 10 mA
#   7 - 31.6 mA
#   8 - 100 mA
#
# Example: HTR8:150
#
# 2. Analog outputs 1 and 2, output 0..10V in unipolar mode,
#    -10..10V in bipolar mode
#
# Channel setting ANALOG<N>(u|b)
#
# Example: ANALOG1u -- analog output 1 in unipolar mode

package require Itcl
package require Device2
namespace eval device_role::dc_source {

itcl::class lsci370 {
  inherit base

  proc test_id {id} {
    if {[regexp {LSCI,MODEL370} $id]} {return 1}
  }

  variable chan;  # channel to use (1..2)
  variable res; # heater resistance
  variable rng; # heater curent range, A
  variable output; # H 1 2
  variable bipolar; # 0 1

  constructor {d ch id} {

    set dev $d

    ## Heater output
    if {[regexp {^HTR([1-8]):([0-9e.]+)$} $ch v rng_num res]} {

      switch -exact -- $rng_num {
        1 {set rng 3.16e-5}
        2 {set rng 1.00e-4}
        3 {set rng 3.16e-4}
        4 {set rng 1.00e-3}
        5 {set rng 3.16e-3}
        6 {set rng 1.00e-2}
        7 {set rng 3.16e-2}
        8 {set rng 1.00e-1}
      }
      set output "H"
      set min_v 0
      set max_v [expr $rng*$res]
      set min_v_step [expr 1e-5*$max_v]

      Device2::ask $dev HTRRNG $rng_num
      Device2::ask $dev CMODE  3
      return
    }

    ## Analog output
    if {[regexp {^ANALOG([12])([ub])$} $ch v output bipolar]} {
      set bipolar [expr {$bipolar == "u" ? 0:1}]

      set min_v [expr $bipolar? -10:0]
      set max_v 10.0
      set min_v_step [expr 1e-5*$max_v]
      set ret [Device2::ask $dev "ANALOG? $output"]
      set ret [split $ret ","]
      lset ret 0 $bipolar
      lset ret 1 2
      Device2::ask $dev "ANALOG $output,[join $ret {,}]"
      return
    }

    error "$this: bad channel setting: $ch"

  }

  method set_volt {volt} {
    if {$output == {H}} {
      # calculate heater output
      set v [expr 100*$volt/$max_v]
      if {$v > 100} {set v 100}
      if {$v < 0} {set v 0}
      Device2::ask $dev "MOUT $v"
    }\
    else {
      set v [expr 100.0*$volt/$max_v]
      if {$v > 100} {set v 100}
      if {$v < -100} {set v -100}
      if {!$bipolar && $v < 0} {set v 0}
      set ret [Device2::ask $dev "ANALOG? $output"]
      set ret [split $ret ","]
      lset ret 6 $v
      Device2::ask $dev "ANALOG $output,[join $ret {,}]"

    }
  }

  method off {} {
    set_volt 0
  }

  method get_volt {} {
    if {$output == {H}} {
      set v [Device2::ask $dev "MOUT?"]
      return [expr $v*$max_v/100.0]
    }\
    else {
      set ret [Device2::ask $dev "ANALOG? $output"]
      set ret [split $ret ","]
      set v [lindex $ret 6]
      return [expr $v*$max_v/100.0]
    }
  }
}

}; # namespace
