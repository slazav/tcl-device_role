######################################################################
# lock-in role

package require Itcl
package require Device2

namespace eval device_role::lock-in {

######################################################################
## Interface class.
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}

  ##################
  # variables to hold measured values (for interface)
  variable X
  variable Y
  variable M; # max value for X and Y
  variable status {OK}; # status

  ##################
  # methods which should be defined by driver:
  method get {} {}; # do the measurement, return two numbers, X and Y, Vrms
  method get_tconst {} {return 0};      # Time constant, in seconds!
  method get_range  {} {return M};      # Range in Vrms, same units as X,Y

  # Device status. For some devices $status variable is updated
  # during get command. Use get_status after get to get correct status of
  # the last operation.
  method get_status {} {return $status}; # Device status (text)

  ##################
  # Role-specific Tk widget.
  # It can be modified/replaced in drivers if needed.

  variable root {}
  variable xy_i
  variable bar_w
  variable bar_h

  # widget parameters
  variable widget_options [list\
      {-bar_w}       bar_w    200\
      {-bar_h}       bar_h    10\
      {-title}       title    {Lock-in:}
  ]

  # creat widget
  method make_widget {tkroot args} {
    xblt::parse_options "lock-in widget" $args $widget_options

    # Main frame:
    set root $tkroot
    labelframe $root -text $title -font {-weight bold -size 10}

    # Device
    label $root.dev_l -text "Device: ${dev}"
    grid $root.dev_l -columnspan 2 -padx 5 -pady 2 -sticky w

    # Measurement result
    label $root.xy -textvariable [itcl::scope xy_i] -font {-weight bold -size 10}
    grid $root.xy -columnspan 2 -padx 5 -pady 2 -sticky w

    # Measurement bar
    set w1 [expr $bar_w+1]
    set w2 [expr $bar_w/2+1]
    set h1 [expr $bar_h+1]
    set h2 [expr $bar_h/2+1]
    canvas $root.bar -width $w1 -height $h1
    $root.bar create rectangle 1 1 $w1 $h1 -fill white -outline grey
    $root.bar create polygon $w2 1 $w2 $h1 -outline grey
    $root.bar create polygon 1 $h2 $w1 $h2 -outline grey
    grid $root.bar -padx 5 -pady 2 -sticky we -columnspan 2

    # Status text
    label $root.status -textvariable [itcl::scope status] -font {-weight bold -size 10}
    grid $root.status -columnspan 2 -padx 5 -pady 2 -sticky w
  }

  # is the widget used?
  method has_widget {} {
    return [expr {$root ne {} && [winfo exists $root.bar]}]
  }

  # this should be called in the get command
  method update_interface {} {
    if {![has_widget]} return

    set w0 [expr $bar_w/2+1]
    set wx [expr int((1.0+$X/$M)*0.5*$bar_w)]
    set wy [expr int((1.0+$Y/$M)*0.5*$bar_w)]
    set h1 [expr $bar_h+1]
    set h2 [expr $bar_h/2+1]
    $root.bar delete data
    $root.bar create rectangle $w0 2   $wx [expr $bar_h/2+1]\
              -fill darkgreen -width 0 -tags data
    $root.bar create rectangle $w0 [expr $bar_h/2+2] $wy $h1\
              -fill darkcyan -width 0 -tags data
    # Format values for the interface
    set xy_i [format "%8.3e, %8.3e Vrms" $X $Y]

    $root.status configure -fg [expr {$status eq "OK"? "darkgreen":"red"}]
  }

}

######################################################################
# TEST class

itcl::class TEST {
  inherit interface
  proc test_id {id} {}

  constructor {d ch id args} {
    set dev "TEST"
    set M 1
  }
  destructor {}

  ############################
  method get {} {
    set X [expr rand()]
    set Y [expr rand()]
    update_interface
    return [list $X $Y]
  }
  method get_tconst {} {return 1}
}


######################################################################
# Use Femto lock-in + PicoADC.
#
# Usage:
#   DeviceRole <name> lock-in [options]
#
# Options:
#   -x -chan_x   -- X channel (default: 1)
#   -x -chan_y   -- Y channel (default: 2)
#   -s -single   -- single/differential mode (1|0, default: 1)
#   -r -range    -- range (default: 2500)
#   -t -tconv    -- conversion time (default: 60)
#   -d -divider  -- divider (default: 1)
#   -show_adc    -- Show ADC settings in the interface (0 or 1, default: 0)
#   -use_femto      -- Use Femto locking (0 or 1, default: 1)
#   -femto_editable -- Editable Femto parameters in the interface (0 or 1, default: 0)
#   -femto_s1       -- Position of Femto S1 switch (0 or 1, default: 0)
#   -femto_range    -- Position of Femto range switch (default: 4)
#   -femto_tconst   -- Position of Femto tconst switch (default: 6)
#
itcl::class femto_pico {
  inherit interface
  proc test_id {id} {
    if {[regexp {pico_adc} $id]} {return 1}
  }

  variable chan_x;   # X channel
  variable chan_y;   # Y channel
  variable single;   # single/differential
  variable range;    # range
  variable tconv;    # conversion time
  variable divider;  # adc divider (1:<V>)

  variable ranges {}; # list of ranges
  variable tconvs {}; # list of conversion times
  variable show_adc;  # Show ADC settings

  # femto controls
  variable use_femto;    # Use Femto lock-in settings
  variable femto_editable; # Allow range/tconst settings in the interface.
  variable femto_s1;     # Femto lock-in switch 1 (0 or 1 - High/Low dynamic resolution)
  variable femto_range;  # Femto lock-in range switch
  variable femto_ranges;   # range list, depends on $femto_s1, set in the cnstructor
  variable femto_ranges_v; # same, numerical values:
  variable femto_tconst; # time constant
  variable femto_tconsts; # time constant list
  variable femto_tconsts_v; # numerical values


  ##########################
  constructor {d ch id args} {
    set dev $d
    # Parse options.
    set options [list \
      {-x -chan_x}   chan_x   1\
      {-x -chan_y}   chan_y   2\
      {-s -single}   single   1\
      {-r -range}    range    2500\
      {-t -tconv}    tconv    60\
      {-d -divider}  divider  1\
      {-show_adc}    show_adc 0\
      {-use_femto}      use_femto 1\
      {-femto_editable} femto_editable 0\
      {-femto_s1}       femto_s1 0\
      {-femto_range}    femto_range 4\
      {-femto_tconst}   femto_tconst 6\
    ]
    xblt::parse_options "lock-in::femto_pico" $args $options

    if {!$single && ($chan_x%2 != 1 || $chan_y%2 != 1)} {
      error "can't set differential mode for even-numbered channels: $chan_x,$chan_y"
    }

    set ranges [Device2::ask $dev ranges]
    set tconvs [Device2::ask $dev tconvs]

    if {$femto_s1} {
      # ranges in Ultra stable/Low Drift mode (S1 = ON, low dynamic resolution)
      set femto_ranges {
        {0 - ultra stab. 1V}
        {1 - ultra stab. 300mV}
        {2 - ultra stab. 100mV}
        {3 - ultra stab. 30mV}
        {4 - ultra stab. 10mV}
        {5 - ultra stab. 3mV}
        {6 - ultra stab. 1mV}
        {7 - ultra stab. 300uV}
        {8 - low drift 100mV}
        {9 - low drift 30mV}
        {A - low drift 10mV}
        {B - low drift 3mV}
        {C - low drift 1mV}
        {D - low drift 300uV}
        {E - low drift 100uV}
        {F - low drift 30uV}
      }
      # same, numerical values:
      set femto_ranges_v {
        1 300e-3 100e-3 30e-3 10e-3 3e-3 1e-3 300e-6
        100e-3 30e-3 10e-3 3e-3 1e-3 300e-6 100e-6 30e-6
      }
    } else {
       # ranges in Low Drift/High Dynamic mode (S1 = OFF, high dynamic resolution)
      set femto_ranges {
        {0 - low drift 100mV}
        {1 - low drift 30mV}
        {2 - low drift 10mV}
        {3 - low drift 3mV}
        {4 - low drift 1mV}
        {5 - low drift 300uV}
        {6 - low drift 100uV}
        {7 - low drift 30uV}
        {8 - high dyn. 10mV}
        {9 - high dyn. 3mV}
        {A - high dyn. 1mV}
        {B - high dyn. 300uV}
        {C - high dyn. 100uV}
        {D - high dyn. 30uV}
        {E - high dyn. 10uV}
        {F - high dyn. 3uV}
      }
      set femto_ranges_v {
        100e-3 30e-3 10e-3 3e-3 1e-3 300e-6 100e-6 30e-6
         10e-3 3e-3 1e-3 300e-6 100e-6 30e-6 10e-6 3e-6
      }
    }

    # Femto lock-in time constants
    set femto_tconsts {
      {0 - 6dB/oct, 300us}
      {1 - 6dB/oct, 1ms}
      {2 - 6dB/oct, 3ms}
      {3 - 6dB/oct, 10ms}
      {4 - 6dB/oct, 30ms}
      {5 - 6dB/oct, 100ms}
      {6 - 6dB/oct, 300ms}
      {7 - 12dB/oct, 1s}
      {8 - 12dB/oct, 300us}
      {9 - 12dB/oct, 1ms}
      {A - 12dB/oct, 3ms}
      {B - 12dB/oct, 10ms}
      {C - 12dB/oct, 30ms}
      {D - 12dB/oct, 100ms}
      {E - 12dB/oct, 300ms}
      {F - 12dB/oct, 1s}
    }
    # same, numerical values:
    set femto_tconsts_v {
      3e-4 1e-3 3e-3 1e-2 3e-2 1e-1 3e-1 1
      3e-4 1e-3 3e-3 1e-2 3e-2 1e-1 3e-1 1
    }

    set femto_range_i [lsearch -regexp $femto_ranges "^$femto_range"]
    if {$femto_range_i>=0} {set femto_range [lindex $femto_ranges $femto_range_i] }

    set femto_tconst_i [lsearch -regexp $femto_tconsts "^$femto_tconst"]
    if {$femto_tconst_i>=0} {set femto_tconst [lindex $femto_tconsts $femto_tconst_i] }
  }


  ############################

  method make_widget {tkroot args} {
    chain $tkroot {*}$args
    set root $tkroot

    # Modify device label (include channels and divider):
    if {$divider!=1} {set div_l ", divider 1:$divider"} else {set div_l ""}
    $root.dev_l configure -text "Device: ${dev}:$chan_x,$chan_y$div_l"

    if {$show_adc} {
      # Range combobox:
      label $root.range_l -text "ADC range, mV:"
      ttk::combobox $root.range -width 9 -textvariable [itcl::scope range]\
        -values $ranges
      #bind $root.range <<ComboboxSelected>> "$this set_range"
      grid $root.range_l $root.range -padx 5 -pady 2 -sticky e

      # Conversion time combobox
      label $root.tconv_l -text "ADC conv.time, s:"
      ttk::combobox $root.tconv -width 9 -textvariable [itcl::scope tconv]\
        -values $tconvs
      #bind $root.tconv <<ComboboxSelected>> "$this set_tconv"
      grid $root.tconv_l $root.tconv -padx 5 -pady 2 -sticky e
    }

    #######
    if {$use_femto} {
      label $root.femto -text "Femto settings:" -font {-weight bold}
      label $root.femto_s1 -text "Switch1: [expr $femto_s1?{ON}:{OFF}]"
      grid $root.femto $root.femto_s1 -padx 5 -pady 2 -sticky w

      #label $root.femto_range_l -text "Range:"
      if {$femto_editable} {
        # Femto tconst setting
        ttk::combobox $root.femto_tconst -textvariable [itcl::scope femto_tconst]\
          -values $femto_tconsts -state disabled

        # Femto range setting
        ttk::combobox $root.femto_range -textvariable [itcl::scope femto_range]\
          -values $femto_ranges
        grid $root.femto_range -columnspan 2 -padx 5 -pady 2 -sticky e
      }\
      else {
        label $root.femto_tconst -textvariable [itcl::scope femto_tconst]
        label $root.femto_range -textvariable [itcl::scope femto_range]
      }
      grid $root.femto_tconst -columnspan 2 -padx 5 -pady 2 -sticky w
      grid $root.femto_range -columnspan 2 -padx 5 -pady 2 -sticky w
    }
    # Transformer setting
  }
  ############################

  ############################
  method get {} {

    # get values
    set X [Device2::ask $dev get_val $chan_x $single $range $tconv]
    set Y [Device2::ask $dev get_val $chan_y $single $range $tconv]
    set M [expr $range/1e3]

    if {abs($X)>=$M || abs($Y)>=$M} {set status "ADC OVERLOAD"}\
    else {set status "OK"}

    # apply divider setting
    if {$divider!=1} {
      set X [expr $X*$divider]
      set Y [expr $Y*$divider]
      set M [expr $M*$divider]
    }

    if {$use_femto} {
      if {abs($X)>10 || abs($Y)>10} {
        set status "FEMTO OVERLOAD"
      }
      set i [lsearch -exact $femto_ranges $femto_range]
      if {$i<0} {error "wrong Femto range: $femto_range"}
      set k [expr [lindex $femto_ranges_v $i]/10.0]
      set X [expr $X*$k]
      set Y [expr $Y*$k]
      set M [expr $M*$k]
    }

    # update interface values
    update_interface

    # this is Vrms!
    return [list $X $Y]
  }

  method get_tconst {} {
    if {$use_femto} {
      set i [lsearch -exact $femto_tconsts $femto_tconst]
      if {$i<0} {error "wrong Femto time constant: $femto_tconst"}
      return [lindex $femto_tconsts_v $i]
    }\
    else {return 0}
  }

  method get_range {} {
    set ret [expr $range/1e3]
    if {$divider!=1} { set ret [expr $ret*$divider]}
    if {$use_femto} {
      set i [lsearch -exact $femto_ranges $femto_range]
      if {$i<0} {error "wrong Femto range: $femto_range"}
      set ret [expr $ret*[lindex $femto_ranges_v $i]/10.0]
    }
  }

}

######################################################################
# Use Lockin SR830.
#
# ID string:
#   Stanford_Research_Systems,SR830,s/n46117,ver1.07
#

itcl::class sr830 {
  inherit interface
  proc test_id {id} {
    if {[regexp {,SR830,} $id]} {return 1}
  }

  variable T

  # lock-in ranges and time constants
  common ranges    {}
  common ranges_V  {2e-9 5e-9 1e-8 2e-8 5e-8 1e-7
                    2e-7 5e-7 1e-6 2e-6 5e-6 1e-5
                    2e-5 5e-5 1e-4 2e-4 5e-4 1e-3
                    2e-3 5e-3 1e-2 2e-2 5e-2 0.1
                    0.2 0.5 1.0}
  common ranges_A  {2e-15 5e-15 1e-14 2e-14 5e-14 1e-13
                    2e-13 5e-13 1e-12 2e-12 5e-12 1e-11
                    2e-11 5e-11 1e-10 2e-10 5e-10 1e-9
                    2e-9 5e-9 1e-8 2e-8 5e-8 1e-7
                    2e-7 5e-7 1e-6}
  common tconsts   {1e-5 3e-5 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2
                    0.1 0.3 1.0 3.0 10.0 30.0 1e2 3e3 1e3 3e3 1e4 3e4}
  common imodes    {A A-B I(1M) I(100M)}
  common imode      A

  constructor {d ch id args} {
    set dev $d
    get_range
    get_imode
    get
  }

  method make_widget {tkroot args} {
    chain $tkroot {*}$args
    set root $tkroot

    # Sensitivity combobox
    label $tkroot.range_l -text "Sensitivity, V:"
    ttk::combobox $tkroot.range -width 9 -values $ranges_V\
      -textvariable [itcl::scope M]
    bind $tkroot.range <<ComboboxSelected>> "$this set_range"
    grid $tkroot.range_l $tkroot.range -padx 5 -pady 2 -sticky e
    update_ranges

    # Time constant combobox
    label $tkroot.tconst_l -text "Time constant, s:"
    ttk::combobox $tkroot.tconst -width 9 -values $tconsts\
       -textvariable [itcl::scope T]
    bind $tkroot.tconst <<ComboboxSelected>> "$this set_tconst"
    grid $tkroot.tconst_l $tkroot.tconst -padx 5 -pady 2 -sticky e

    # Input mode combobox
    label $tkroot.imode_l -text "Input mode:"
    ttk::combobox $tkroot.imode -width 9 -values $imodes\
       -textvariable [itcl::scope imode]
    bind $tkroot.imode <<ComboboxSelected>> "$this set_imode"
    grid $tkroot.imode_l $tkroot.imode -padx 5 -pady 2 -sticky e
  }

  # Set ranges according with input mode (volts or amps)
  # called in the constructor and in set_imode method.
  method update_ranges {} {
    set isrc [$dev cmd "ISRC?"]
    if {$isrc == 0 || $isrc == 1} {
      set ranges $ranges_V
      set VA "V"
    } else {
      set ranges $ranges_A
      set VA "A"
    }
    $root.range_l configure -text "Sensitivity, $VA:"
    $root.range configure -values $ranges
    get_range
  }

  ############################
  method get {} {
    set r [split [$dev cmd SNAP?1,2]  ","]
    set X [lindex $r 0]
    set Y [lindex $r 1]
    get_status
    update_interface
    return [list $X $Y]
  }

  ############################
  method list_ranges {} {
    return [list {*}$ranges]
  }
  method list_tconsts {} {
    return [list {*}$tconsts]
  }
  method list_imodes {} {
    return [list {*}$imodes]
  }

  ############################
  method set_range  {{val {}}} {
    set ranges [list_ranges]
    if {$val != {}} {set M $val}
    set n [lsearch -real -exact $ranges $M]
    if {$n<0} {error "unknown range setting: $M"}
    $dev cmd "SENS $n"
  }
  method set_tconst {{val {}}} {
    if {$val != {}} {set T $val}
    set n [lsearch -real -exact $tconsts $T]
    if {$n<0} {error "unknown time constant setting: $T"}
    $dev cmd "OFLT $n"
  }
  method set_imode {{val {}}} {
    if {$val != {}} {set imode $val}
    set n [lsearch -exact $imodes $imode]
    if {$n<0} {error "unknown time constant setting: $imode"}
    $dev cmd "ISRC $n"
    update_ranges
  }

  ############################
  method get_range  {} {
    set ranges [list_ranges]
    set n [$dev cmd "SENS?"]
    set M [lindex $ranges $n]
    return $M
  }
  method get_tconst {} {
    set n [$dev cmd "OFLT?"]
    set T [lindex $tconsts $n]
    return $T
  }
  method get_imode {} {
    set n [$dev cmd "ISRC?"]
    set imode [lindex $imodes $n]
    return $imode
  }

  method get_status {} {
    set s [$dev cmd "LIAS?"]
    set status {}
    if {$s & (1<<0)} {lappend status "INP_OVR"}
    if {$s & (1<<1)} {lappend status "FLT_OVR"}
    if {$s & (1<<2)} {lappend status "OUTPT_OVR"}
    if {$s & (1<<3)} {lappend status "UNLOCK"}
    if {$s & (1<<4)} {lappend status "FREQ_LO"}
    if {$status == {}} {lappend status "OK"}
    return $status
  }

}

######################################################################
} # namespace
