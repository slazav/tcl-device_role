######################################################################
package require Itcl
package require Device2
namespace eval device_role::lock-in {

######################################################################
# Use Stanford Research Systems Lock-in SR830.
#
# ID string:
#   Stanford_Research_Systems,SR830,s/n46117,ver1.07
#
# Channels: no
#
# Options:
#   -editable (0|1) -- allow setting parameters via the widget
#   -range <value>  -- set range
#   -tconst <value>  -- set time constant
#   -imode  <value>  -- set input mode ("A" "A-B" "I(1M)" "I(100M)")

itcl::class sr830 {
  inherit base
  proc test_id {id} {
    if {[regexp {,SR830,} $id]} {return 1}
  }

  variable editable
  constructor {args} {
    chain {*}$args

    xblt::parse_options "lock_in::sr830" $dev_opts \
    [list \
      {-editable} editable 1\
      {-range}    range  {}\
      {-tconst}   tconst {}\
      {-imode}    imode  {}\
    ]
    if {$imode  ne {}} {set_imode  $imode}; # should go before range setting!
    if {$range  ne {}} {set_range  $range}
    if {$tconst ne {}} {set_tconst $tconst}

    set dev_info "$dev_name (SR830)"
  }

  variable T
  variable R
  variable imode A

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

  ##########################################################
  # Interface methods

  method get {} {
    set r [split [Device2::ask $dev_name SNAP?1,2]  ","]
    set X [lindex $r 0]
    set Y [lindex $r 1]
    set S [get_status]
    update_widget $X $Y $S
    return [list $X $Y $S]
  }

  method get_range  {} {
    set n [Device2::ask $dev_name "SENS?"]
    set R [lindex $ranges $n]
    return $R
  }

  method get_tconst {} {
    set n [Device2::ask $dev_name "OFLT?"]
    set T [lindex $tconsts $n]
    return $T
  }

  ##########################################################
  # Other methods

  # Set ranges according with input mode (volts or amps)
  # called in the constructor and in set_imode method.
  method update_ranges {} {
    set isrc [Device2::ask $dev_name "ISRC?"]
    if {$isrc == 0 || $isrc == 1} {
      set ranges $ranges_V
      set VA "V"
    } else {
      set ranges $ranges_A
      set VA "A"
    }
    if {[has_widget]} {
      $root.f.range_l configure -text "Range, $VA:"
      if {$editable} {
        $root.f.range configure -values $ranges
      }
    }
    get_range
  }

  method set_range  {{val {}}} {
    if {$val != {}} {set R $val}
    set n [lsearch -real -exact $ranges $R]
    if {$n<0} {error "unknown range setting: $R"}
    Device2::ask $dev_name "SENS $n"
  }

  method set_tconst {{val {}}} {
    if {$val != {}} {set T $val}
    set n [lsearch -real -exact $tconsts $T]
    if {$n<0} {error "unknown time constant setting: $T"}
    Device2::ask $dev_name "OFLT $n"
  }

  method set_imode {{val {}}} {
    if {$val != {}} {set imode $val}
    set n [lsearch -exact $imodes $imode]
    if {$n<0} {error "unknown time constant setting: $imode"}
    Device2::ask $dev_name "ISRC $n"
    update_ranges
  }

  method get_imode {} {
    set n [Device2::ask $dev_name "ISRC?"]
    set imode [lindex $imodes $n]
    return $imode
  }

  method get_status {} {
    set s [Device2::ask $dev_name "LIAS?"]
    if { [string is integer $s] == 0} {return "UNKNOWN"}
    set status {}
    if {$s & (1<<0)} {lappend status "INP_OVR"}
    if {$s & (1<<1)} {lappend status "FLT_OVR"}
    if {$s & (1<<2)} {lappend status "OUTPT_OVR"}
    if {$s & (1<<3)} {lappend status "UNLOCK"}
    if {$s & (1<<4)} {lappend status "FREQ_LO"}
    if {$status == {}} {lappend status "OK"}
    return $status
  }

  method on_update {} {
    get_range
    get_tconst
    get_imode
  }


  ##########################################################
  # Widget - add Sensitivity, TimeConstant, InputMode comboboxes,
  # Update/Apply buttons

  method make_widget {tkroot args} {
    chain $tkroot {*}$args
    frame $tkroot.f
    grid $tkroot.f

    label $tkroot.f.range_l -text "Range, Vrms:" -font {-size 8}
    label $tkroot.f.tconst_l -text "TConst, s:" -font {-size 8}
    label $tkroot.f.imode_l -text "Input:" -font {-size 8}
    if {$editable} {
      ttk::combobox $tkroot.f.range -width 6 -values $ranges\
        -textvariable [itcl::scope R] -justify right
      bind $tkroot.f.range <<ComboboxSelected>> "$this set_range"
      ttk::combobox $tkroot.f.tconst -width 5 -values $tconsts\
         -textvariable [itcl::scope T] -justify right
      bind $tkroot.f.tconst <<ComboboxSelected>> "$this set_tconst"
      ttk::combobox $tkroot.f.imode -width 8 -values $imodes\
        -textvariable [itcl::scope imode] -justify right
      bind $tkroot.f.imode <<ComboboxSelected>> "$this set_imode"
    } else {
      label $tkroot.f.range -textvariable [itcl::scope R]
      label $tkroot.f.tconst -textvariable [itcl::scope T]
      label $tkroot.f.imode -textvariable [itcl::scope imode]
    }
    grid $tkroot.f.range_l $tkroot.f.tconst_l $tkroot.f.imode_l -padx 2 -pady 0 -sticky w
    grid $tkroot.f.range $tkroot.f.tconst $tkroot.f.imode -padx 1 -pady 0 -sticky e

    # Update button
    button $tkroot.upd -text "Update" -command "$this on_update" -pady 0
    grid $tkroot.upd -padx 5 -pady 2 -sticky w
    update_ranges
    on_update
  }
}

######################################################################
} # namespace
