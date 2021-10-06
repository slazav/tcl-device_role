######################################################################
# dc_source role

package require Itcl
package require Device2

namespace eval device_role::dc_source {

######################################################################
## Interface class. All driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage
  public variable min_v_step; # min step in voltage

  # methods which should be defined by driver:
  method set_volt {val} {}; # set voltage
  method get_volt {} {};    # measure actual voltage value
}

######################################################################
# TEST device. Does nothing
itcl::class TEST {
  inherit interface
  proc test_id {id} {}
  variable volt

  constructor {d ch id} {
    set volt  0
    set max_v 10
    set min_v -10
    set min_v_step 0.01
  }

  method set_volt {v}      {
    if {$v < $min_v} {set v $min_v}
    if {$v > $max_v} {set v $max_v}
    set volt $v
  }
  method off {}            { set volt 0  }
  method get_volt {}       { return $volt }
}

######################################################################
# Use HP/Agilent/Keysight 1- and 2-channel generators as a DC source.

itcl::class keysight {
  inherit keysight_gen interface
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
    if {[$dev cmd "OUTP${chan}?"] == 0} {return 0}
    return [$dev cmd "${sour_pref}VOLT:OFFS? "]
  }
}
######################################################################
# Use LakeShore 370 outputs as dc sources.
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


itcl::class LSCI370 {
  inherit interface

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

      $dev cmd HTRRNG $rng_num
      $dev cmd CMODE  3
      return
    }

    ## Analog output
    if {[regexp {^ANALOG([12])([ub])$} $ch v output bipolar]} {
      set bipolar [expr {$bipolar == "u" ? 0:1}]

      set min_v [expr $bipolar? -10:0]
      set max_v 10.0
      set min_v_step [expr 1e-5*$max_v]
      set ret [$dev cmd "ANALOG? $output"]
      set ret [split $ret ","]
      lset ret 0 $bipolar
      lset ret 1 2
      $dev cmd "ANALOG $output,[join $ret {,}]"
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
      $dev cmd "MOUT $v"
    }\
    else {
      set v [expr 100.0*$volt/$max_v]
      if {$v > 100} {set v 100}
      if {$v < -100} {set v -100}
      if {!$bipolar && $v < 0} {set v 0}
      set ret [$dev cmd "ANALOG? $output"]
      set ret [split $ret ","]
      lset ret 6 $v
      $dev cmd "ANALOG $output,[join $ret {,}]"

    }
  }

  method off {} {
    set_volt 0
  }

  method get_volt {} {
    if {$output == {H}} {
      set v [$dev cmd "MOUT?"]
      return [expr $v*$max_v/100.0]
    }\
    else {
      set ret [$dev cmd "ANALOG? $output"]
      set ret [split $ret ","]
      set v [lindex $ret 6]
      return [expr $v*$max_v/100.0]
    }
  }
}

######################################################################
# Use Lockin SR844 auxilary outputs as a voltage_suply.
#
# ID string:
#   Stanford_Research_Systems,SR844,s/n50066,ver1.006
#
# Use channels 1 or 2 to set auxilary output

itcl::class sr844 {
  inherit interface
  proc test_id {id} {
    if {[regexp {,SR844,} $id]} {return 1}
  }

  variable chan;  # channel to use (1..2)
  constructor {d ch id} {
    if {$ch!=1 && $ch!=2} {
      error "$this: bad channel setting: $ch"}
    set chan $ch

    set dev $d
    set max_v +10.5
    set min_v -10.5
    set min_v_step 0.001
  }
  method set_volt {val} {
    $dev cmd "AUXO${chan},$val"
  }
  method off {} {
    set_volt 0
  }
  method get_volt {} { return [$dev cmd "AUXO?${chan}"] }
}

######################################################################
# Use Korad/Velleman/Tenma device in a voltage_suply.
itcl::class tenma {
  inherit tenma_ps interface
  proc test_id {id} {tenma_ps::test_id $id}
  # we use Device from tenma_ps class
  method get_device {} {return $tenma_ps::dev}

  constructor {d ch id} {tenma_ps::constructor $d $ch $id} {
    # set max current
    tenma_ps::set_curr $max_i
    $dev cmd "OVP0";  # clear OVP/OCP
    $dev cmd "OCP0";  #
    $dev cmd "BEEP1"; # beep off
  }
  method set_volt {val} {
    tenma_ps::set_volt $val
    if {[tenma_ps::get_stat] == {OFF}} { $dev cmd "OUT1" }
  }
  method off {} {
    $dev cmd "OUT0"
  }
  method get_volt {} { tenma_ps::get_volt }
}

######################################################################
# Use Keithley SorceMeter device as a dc source.
#
# ID string:
#   KEITHLEY INSTRUMENTS INC.,MODEL 2400,1197778,C30 Mar 17 2006 09:29:29/A02 /K/J
#
# ranges:
#   -- current 1uA..1A;
#   -- voltage 200mV..200V;
# limits:
#   --current -1.05 to 1.05 (A)
#   --voltage -210 to 210 (V)
# overvoltage protection:
#     20 40 60 80 100 120 160 V
itcl::class sm2400 {
  inherit interface
  proc test_id {id} {
    if {[regexp {,MODEL 2400,} $id]} {return 1}
  }

  variable chan;  # channel to use (1..2)
  constructor {d ch id} {
    switch -exact -- $ch {
      DCV {  set cmd ":sour:func volt"; set cmd "sour:volt:range:auto on" }
      DCI {  set cmd ":sour:func curr"; set cmd "sour:curr:range:auto on" }
      default {
        error "$this: bad channel setting: $ch"
        return
      }
    }
    set chan $ch
    set dev $d
  }
  method set_volt {val} {
    $dev cmd ":sour:volt:lev $val"
  }
  method set_curr {val} {
    $dev cmd ":sour:curr:lev $val"
  }

  method set_volt_range {val} {
    $dev cmd ":sour:volt:range $val"
  }
  method set_curr_range {val} {
    $dev cmd ":sour:curr:range $val"
  }

  method get_volt {} {
    $dev cmd ":sour:volt:lev?"
  }
  method get_curr {} {
    $dev cmd ":sour:curr:lev?"
  }

  method get_volt_range {} {
    $dev cmd ":sour:volt:range?"
  }
  method get_curr_range {} {
    $dev cmd ":sour:curr:range?"
  }

  method on {} {
    $dev cmd ":outp on"
  }
  method off {} {
    $dev cmd ":outp off"
  }
}

######################################################################
} # namespace
