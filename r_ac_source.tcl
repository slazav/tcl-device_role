######################################################################
# ac_source role

package require Itcl
package require Device2

namespace eval device_role::ac_source {

######################################################################
## Interface class. All driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage

  # methods which should be defined by driver:

  # Reconfigure output, set frequency, voltage, offset
  # If phase is not empty, set phase as well:
  method set_ac {freq volt {offs 0} {phase {}}} {};

  method get_volt  {} {};    # get voltage value
  method get_freq  {} {};    # get frequency value
  method get_offs  {} {};    # get offset value
  method get_phase {} {};    # get phase

  method set_volt {v}  {}
  method set_freq {v}  {}
  method set_offs {v}  {}
  method set_phase {v} {}

  method set_out {state} {};   # turn output on/off (without affecting other set/get commands)
  method get_out {} {}         # get output state

  # Set state of front-panel sync connector (1|0)
  # This may be useful for 2-channel devices where sync can follow
  # only one of the channels.
  method set_sync  {state} {}; # set state of front-panel sync connector

}

######################################################################
# TEST device. Does nothing.

itcl::class TEST {
  inherit interface
  proc test_id {id} {}
  variable freq
  variable volt
  variable offs
  variable phase
  variable onoff

  constructor {d ch id} {
    set freq 1000
    set volt 0.1
    set offs  0
    set phase 0
    set onoff 1
    set min_v 0
    set max_v 10
  }

  method set_ac {f v {o 0} {p {}}} {
    if {$v < $min_v} {set v $min_v}
    if {$v > $max_v} {set v $max_v}
    set freq $f
    set volt $v
    set offs $o
    if {$p ne {}} {set_phase $p}
  }

  method get_volt  {} { return $volt }
  method get_freq  {} { return $freq }
  method get_offs  {} { return $offs }
  method get_phase {} { return $phase }
  method get_out   {} { return onoff }

  method set_volt {v}  { set volt $v }
  method set_freq {v}  { set freq $v }
  method set_offs {v}  { set offs $v }
  method set_phase {v} { set phase $v }
  method set_out {v} { set onoff [eval {$v?1:0}] }

  method set_sync {state} { }
}

######################################################################
# Use HP/Agilent/Keysight 1- and 2-channel generators as an ac_source.
#
# 2-channel devices (Use channels 1 or 2 to set output):
# Agilent Technologies,33510B,MY52201807,3.05-1.19-2.00-52-00
# Agilent Technologies,33522A,MY50005619,2.03-1.19-2.00-52-00
#
# 1-channel devices (No channels supported):
#Agilent
#Technologies,33511B,MY52300310,2.03-1.19-2.00-52-00
#

itcl::class keysight {
  inherit keysight_gen interface
  proc test_id {id} {keysight_gen::test_id $id}
  # we use Device from keysight_gen class
  method get_device {} {return $keysight_gen::dev}

  constructor {d ch id} {keysight_gen::constructor $d $ch $id} {
    set max_v 20
    set min_v 0.002
    dev_set_par $dev "${sour_pref}BURST:STATE" "0"
    dev_set_par $dev "${sour_pref}VOLT:UNIT" "VPP"
    dev_set_par $dev "UNIT:ANGL"             "DEG"
    dev_set_par $dev "${sour_pref}FUNC"      "SIN"
    dev_set_par $dev "OUTP${chan}:LOAD"      "INF"
  }

  method set_ac {freq volt {offs 0} {phase {}}} {
    dev_err_clear $dev
    $dev cmd "${sour_pref}APPLY:SIN $freq,$volt,$offs"
    if {$phase ne {}} {set_phase $phase}
    dev_err_check $dev
  }

  method get_volt  {}  { return [$dev cmd "${sour_pref}VOLT?"] }
  method get_freq  {} { return [$dev cmd "${sour_pref}FREQ?"] }
  method get_offs  {} { return [$dev cmd "${sour_pref}VOLT:OFFS?"] }
  method get_phase {} { return [$dev cmd "${sour_pref}PHAS?"] }
  method get_out   {} { return [$dev cmd "OUTP${chan}?"] }

  method set_volt {v}  { dev_set_par $dev "${sour_pref}VOLT" $v }
  method set_freq {v}  { dev_set_par $dev "${sour_pref}FREQ" $v }
  method set_offs {v}  { dev_set_par $dev "${sour_pref}VOLT:OFFS" $v }
  method set_phase {v} {
    set v [expr $v-int($v/360.0)*360]
    dev_set_par $dev "${sour_pref}PHAS" $v
  }
  method set_out {v} {
  # For Keysight generators it maybe useful to switch to burst mode
  # to reduce signal leakage.
    dev_set_par $dev "OUTP${chan}" [expr {$v?1:0}]
  }

  method set_sync {state} {
    if {$chan != {}} {
      dev_set_par $dev "OUTP:SYNC:SOUR" "CH${chan}"
    }
    if {$state} { dev_set_par $dev "OUTP:SYNC" 1 }\
    else        { dev_set_par $dev "OUTP:SYNC" 0 }
  }
}

######################################################################
} # namespace
