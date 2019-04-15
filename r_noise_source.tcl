######################################################################
# noise_source role

package require Itcl
package require Device

namespace eval device_role::noise_source {

######################################################################
## Interface class. All power_supply driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage

  # methods which should be defined by driver:
  method set_noise      {bw volt {offs 0}} {}; # set bandwidth, voltage and offset
  method get_volt  {} {};    # get voltage value
  method get_bw    {} {};    # get bandwidth value
  method get_offs  {} {};    # get bandwidth value
  method off       {} {};    # turn off the signal
}

######################################################################
# TEST device. Does nothing

itcl::class TEST {
  inherit interface
  proc test_id {id} {}
  variable volt
  variable bw
  variable offs

  constructor {d ch id} {
    set volt 0
    set bw 1000
    set offs 0
    set max_v 10
    set min_v 0
  }
  method set_noise {b v {o 0}} {
    if {$v < $min_v} {set v $min_v}
    if {$v > $max_v} {set v $max_v}
    set volt $v
    set offs $o
    set bw   $b
  }
  method get_volt {} { return $volt }
  method get_bw   {} { return $bw }
  method get_offs {} { return $offs }
}

######################################################################
# Use HP/Agilent/Keysight 1- and 2-channel generators as an ac_source.
itcl::class keysight_2ch {
  inherit keysight_gen interface
  proc test_id {id} {keysight_gen::test_id $id}
  # we use Device from keysight_gen class
  method get_device {} {return $keysight_gen::dev}

  constructor {d ch id} {keysight_gen::constructor $d $ch $id} {
    set max_v 20
    set min_v 0.002
    set_par "${sour_pref}BURST:STATE" "0"
    set_par "${sour_pref}VOLT:UNIT" "VPP"
    set_par "${sour_pref}FUNC"      "NOIS"
    set_par "OUTP${chan}:LOAD"      "INF"
  }

  method set_noise {bw volt {offs 0}} {
    set_par "${sour_pref}VOLT" $volt
    set_par "${sour_pref}VOLT:OFFS" $offs
    set_par "${sour_pref}FUNC:NOISE:BANDWIDTH" $bw
    set_par "OUTP${chan}" "1"
  }
  method off {} {
    set_par "${sour_pref}VOLT" $min_v
    set_par "${sour_pref}VOLT:OFFS" 0
    set_par "${sour_pref}FUNC:NOISE:BANDWIDTH" 10e6
    set_par "OUTP${chan}" "0"
  }
  method get_volt {} {
    if {[$dev cmd "OUTP${chan}?"] == 0} {return 0}
    return [$dev cmd "${sour_pref}VOLT?"]
  }
  method get_bw   {} {
    return [$dev cmd "${sour_pref}FUNC:NOISE:BANDWIDTH?"]
  }
  method get_offs {} {
    return [$dev cmd "${sour_pref}VOLT:OFFS?"]
  }
}


######################################################################
} # namespace
