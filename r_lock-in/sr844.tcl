######################################################################
# Use Lockin SR844.
#
# ID string:
#  Stanford_Research_Systems,SR844,s/n43078,ver1.005
#

package require Itcl
package require Device2
namespace eval device_role::lock-in {

itcl::class sr844 {
  inherit base
  proc test_id {id} {
    if {[regexp {,SR844,} $id]} {return 1}
  }

  variable T

  # lock-in ranges and time constants
  common ranges  {1e-7 3e-7 1e-6 3e-6
                  1e-5 3e-5 1e-4 3e-4
                  1e-3 3e-3 1e-2 3e-2
                  0.1 0.3 1}
  common tconsts   {1e-4 3e-4 1e-3 3e-3 1e-2 3e-2
                    0.1 0.3 1.0 3.0 10.0 30.0 1e2 3e3 1e3 3e3 1e4 3e4}

  constructor {args} {
    chain {*}$args
    get_range
    get_tconst
    get
  }

  method make_widget {tkroot args} {
    chain $tkroot {*}$args
    set root $tkroot

    # Sensitivity combobox
    label $tkroot.range_l -text "Sensitivity, V:"
    ttk::combobox $tkroot.range -width 9 -values $ranges\
      -textvariable [itcl::scope M]
    bind $tkroot.range <<ComboboxSelected>> "$this set_range"
    grid $tkroot.range_l $tkroot.range -padx 5 -pady 2 -sticky e

    # Time constant combobox
    label $tkroot.tconst_l -text "Time constant, s:"
    ttk::combobox $tkroot.tconst -width 9 -values $tconsts\
       -textvariable [itcl::scope T]
    bind $tkroot.tconst <<ComboboxSelected>> "$this set_tconst"
    grid $tkroot.tconst_l $tkroot.tconst -padx 5 -pady 2 -sticky e
  }

  ############################
  method get {} {
    set r [split [Device2::ask $dev_name SNAP?1,2]  ","]
    set X [lindex $r 0]
    set Y [lindex $r 1]
    get_status
    update_interface $x $y $status
    return [list $X $Y]
  }

  ############################
  method list_ranges {} {
    return [list {*}$ranges]
  }
  method list_tconsts {} {
    return [list {*}$tconsts]
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
