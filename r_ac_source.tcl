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

  # Interface values: variables to hold values in the tk interface.
  # Should be filled in set/get methods!
  public variable volt
  public variable freq
  public variable offs
  public variable phase
  public variable out


  # methods which should be defined by driver:

  # Reconfigure output, set frequency, voltage, offset
  # If phase is not empty, set phase as well:
  method set_ac {f v {o 0} {p {}}} {
    set volt $v
    set freq $f
    set offs $o
    if {$p ne {}} {set phase $p}
  };

  method get_volt  {} {return $volt};  # get voltage value
  method get_freq  {} {return $freq};  # get frequency value
  method get_offs  {} {return $offs};  # get offset value
  method get_phase {} {return $phase}; # get phase
  method get_out   {} {return $out};   # get output state

  method set_volt {v}  {set volt $v}
  method set_freq {v}  {set freq $v}
  method set_offs {v}  {set offs $v}
  method set_phase {v} {set phase $v}
  method set_out {v}   {set out [expr {$v?1:0}]}; # turn output on/off (without affecting other set/get commands)


  # Non-zero AC shift. I use it to implement self-compensation
  # when using with Femto lock-ins + input transformers. 
  public variable ac_shift 0
  method get_ac_shift {v}  {return $ac_shift}
  method set_ac_shift {v}  {
    set ac_shift $v
    set volt  [get_volt]
  }

  # update/apply interface values
  method on_apply {} {
    set_ac  $freq $volt $offs $phase
    on_update
  }
  method on_update {} {
    set volt  [get_volt]
    set freq  [get_freq]
    set offs  [get_offs]
    set phase [get_phase]
    set out   [get_out]
  }

  # Set state of front-panel sync connector (1|0)
  # This may be useful for 2-channel devices where sync can follow
  # only one of the channels.
  method set_sync  {state} {}; # set state of front-panel sync connector

  ##############################################
  # Make Tk widget
  method make_widget {tkroot args} {
    # Parse options.
    set options [list \
      {-t -title}    title     {}\
      {-show_ac_shift}  show_ac_shift 0\
    ]
    xblt::parse_options "w_ac_source" $args $options

    # Main frame:
    set root $tkroot
    labelframe $root -text $title -font {-weight bold -size 10}

    # On/Off button, generator label
    checkbutton $root.out -text "Output ON"\
       -variable [itcl::scope out] -command "$this set_out $[itcl::scope out]"
    label $root.gen -text "Device: [get_device]"
    grid $root.out $root.gen -padx 5 -pady 2 -sticky w -columnspan 2

    # separator
    frame $root.sep -relief groove -borderwidth 1 -height 2
    grid $root.sep -padx 5 -pady 1 -columnspan 4 -sticky ew

    # Frequency/amplitude/offset/phase entries
    label $root.freq_l -text "freq,Hz:"
    entry $root.freq -width 10 -textvariable [itcl::scope freq]
    label $root.volt_l -text "volt,Vpp:"
    entry $root.volt -width 10 -textvariable [itcl::scope volt]
    grid $root.freq_l $root.freq $root.volt_l $root.volt -padx 2 -pady 1 -sticky e

    label $root.offs_l -text "offs,Vpp:"
    entry $root.offs -width 10 -textvariable [itcl::scope offs]
    label $root.phase_l -text "phase,d:"
    entry $root.phase -width 10 -textvariable [itcl::scope phase]
    grid $root.offs_l $root.offs $root.phase_l $root.phase -padx 2 -pady 1 -sticky e

    if {$show_ac_shift} {
      label $root.ac_shift_l -text "AC shift:"
      label $root.ac_shift -width 12 -textvariable [itcl::scope ac_shift]
      grid $root.ac_shift_l $root.ac_shift -padx 2 -pady 1 -sticky e
    }

    # Apply/Update buttons
    button $root.abtn -text "Apply"  -command "$this on_apply"
    button $root.ubtn -text "Update" -command "$this on_update"
    grid $root.abtn $root.ubtn -padx 1 -pady 1 -columnspan 2
    on_update
  }
  ##############################################

}

######################################################################
# TEST device. Does nothing.

itcl::class TEST {
  inherit interface
  proc test_id {id} {}
  variable onoff

  constructor {d ch id args} {
    set dev $d
    set freq 1000
    set volt 0.1
    set offs  0
    set phase 0
    set onoff 1
    set min_v 0
    set max_v 10
    set out 1
  }

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

  constructor {d ch id args} {keysight_gen::constructor $d $ch $id} {
    set max_v 20
    set min_v 0.002
    dev_set_par $dev "${sour_pref}BURST:STATE" "0"
    dev_set_par $dev "${sour_pref}VOLT:UNIT" "VPP"
    dev_set_par $dev "UNIT:ANGL"             "DEG"
    dev_set_par $dev "${sour_pref}FUNC"      "SIN"
    dev_set_par $dev "OUTP${chan}:LOAD"      "INF"
  }

  # get_* methods do NOT update interface.
  # If they are called regularly, it should not
  # prevent user from typing new values in the interface.
  method get_volt {}  {
    set v [expr [$dev cmd "${sour_pref}VOLT?"]]
    if {$ac_shift != 0} {set v [expr $v-$ac_shift]}
    return $v
  }
  method get_freq {} {
    return [expr [$dev cmd "${sour_pref}FREQ?"]]
  }
  method get_offs {} {
    return [expr [$dev cmd "${sour_pref}VOLT:OFFS?"]]
  }
  method get_phase {} {
    return [expr [$dev cmd "${sour_pref}PHAS?"]]
  }
  method get_out {} {
    return [$dev cmd "OUTP${chan}?"]
  }


  method set_ac {f v {o 0} {p {}}} {
    chain $f $v $o $p; # update interface
    dev_check $dev "${sour_pref}APPLY:SIN $f,[expr $v+$ac_shift],$o"
    if {$p ne {}} {set_phase $p}
  }
  method set_volt {v} {
    chain $v;  # set value in the base class (update interface)
    if {$ac_shift != 0} {set v [expr $v+$ac_shift]}
    dev_set_par $dev "${sour_pref}VOLT" $v
  }
  method set_freq {v} {
    dev_set_par $dev "${sour_pref}FREQ" $v
  }
  method set_offs {v}  {
    chain $v
    dev_set_par $dev "${sour_pref}VOLT:OFFS" $v
  }
  method set_phase {v} {
    chain $v
    set v [expr $v-int($v/360.0)*360]
    dev_set_par $dev "${sour_pref}PHAS" $v
  }
  method set_out {v} {
  # For Keysight generators it maybe useful to switch to burst mode
  # to reduce signal leakage.
    chain $v
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
