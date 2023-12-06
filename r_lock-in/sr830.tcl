######################################################################
# Lockin SR830
#
# ID string:
#   Stanford_Research_Systems,SR830,s/n46117,ver1.07
#

package require Itcl
package require Device2
namespace eval device_role::lock-in {

itcl::class sr830 {
  inherit base
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

  constructor {args} {
    chain {*}$args
    get_range
    get_tconst
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
    set isrc [Device2::ask $dev_name "ISRC?"]
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
    set r [split [Device2::ask $dev_name SNAP?1,2]  ","]
    set X [lindex $r 0]
    set Y [lindex $r 1]
    get_status
    update_interface $X $Y $status
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

  ############################
  method get_range  {} {
    set ranges [list_ranges]
    set n [Device2::ask $dev_name "SENS?"]
    set M [lindex $ranges $n]
    return $M
  }
  method get_tconst {} {
    set n [Device2::ask $dev_name "OFLT?"]
    set T [lindex $tconsts $n]
    return $T
  }
  method get_imode {} {
    set n [Device2::ask $dev_name "ISRC?"]
    set imode [lindex $imodes $n]
    return $imode
  }

  method get_status {} {
    set s [Device2::ask $dev_name "LIAS?"]
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

}; # namespace
