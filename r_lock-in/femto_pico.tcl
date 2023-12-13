######################################################################
# Use Femto lock-in + PicoADC.
#
# Usage:
#   DeviceRole <name> lock-in[:<X>,<Y>] [options]
#
# Options:
#   -x -chan_x   -- X channel (default: 1)
#   -y -chan_y   -- Y channel (default: 2)
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
# If channel (:<X>,<Y> suffix) is not empty, it overrides X and Y channel numbers,
# set by -x and -y perameters.

package require Itcl
package require Device2
package require xBlt; # parse_options
namespace eval device_role::lock-in {

itcl::class femto_pico {
  inherit base
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
  constructor {args} {
    chain {*}$args
    # Parse options.
    set options [list \
      {-x -chan_x}   chan_x   1\
      {-y -chan_y}   chan_y   2\
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
    xblt::parse_options "lock-in::femto_pico" $dev_opts $options

    # If channel is not empty, it should contain channel numbers: <n1>,<n2>
    # This overrides -x and -y settings.
    if {$dev_chan != {}} {
      set xy [split $dev_chan ","]
      if {[llength $xy] != 2} { error "bad channel setting: $dev_chan"}
      set chan_x [lindex $xy 0]
      set chan_y [lindex $xy 1]
    }

    if {!$single && ($chan_x%2 != 1 || $chan_y%2 != 1)} {
      error "can't set differential mode for even-numbered channels: $chan_x,$chan_y"
    }

    set ranges [Device2::ask $dev_name ranges]
    set tconvs [Device2::ask $dev_name tconvs]

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
  method get_device_info {} {
    if {$divider!=1} {set div ", divider 1:$divider"} else {set div ""}
    return ${dev_name}:$chan_x,$chan_y$div
  }

  method make_widget {tkroot args} {
    chain $tkroot {*}$args
    set root $tkroot

    if {$show_adc} {
      # Range combobox:
      label $root.range_l -text "ADC range, mV:"
      ttk::combobox $root.range -width 9 -textvariable [itcl::scope range]\
        -values $ranges
      #bind $root.range <<ComboboxSelected>> "$this set_range"
      grid $root.range_l $root.range -padx 2 -pady 1 -sticky e

      # Conversion time combobox
      label $root.tconv_l -text "ADC conv.time, s:"
      ttk::combobox $root.tconv -width 9 -textvariable [itcl::scope tconv]\
        -values $tconvs
      #bind $root.tconv <<ComboboxSelected>> "$this set_tconv"
      grid $root.tconv_l $root.tconv -padx 2 -pady 1 -sticky e
    }

    #######
    if {$use_femto} {
      label $root.femto -text "Femto settings:" -font {-weight bold}
      label $root.femto_s1 -text "Switch1: [expr $femto_s1?{ON}:{OFF}]"
      grid $root.femto $root.femto_s1 -padx 2 -pady 1 -sticky w

      #label $root.femto_range_l -text "Range:"
      if {$femto_editable} {
        # Femto tconst setting
        ttk::combobox $root.femto_tconst -textvariable [itcl::scope femto_tconst]\
          -values $femto_tconsts

        # Femto range setting
        ttk::combobox $root.femto_range -textvariable [itcl::scope femto_range]\
          -values $femto_ranges

        grid $root.femto_tconst $root.femto_range -padx 2 -pady 1 -sticky w
      }\
      else {
        label $root.femto_tconst -textvariable [itcl::scope femto_tconst]
        label $root.femto_range -textvariable [itcl::scope femto_range]
        grid $root.femto_tconst $root.femto_range -padx 2 -pady 1 -sticky w
      }
    }
    # Transformer setting
  }
  ############################

  ############################
  method get {} {

    # get values
    set X [Device2::ask $dev_name get_val $chan_x $single $range $tconv]
    set Y [Device2::ask $dev_name get_val $chan_y $single $range $tconv]
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
    update_interface $X $Y $status

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

}; # namespace
