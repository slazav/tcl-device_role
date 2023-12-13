######################################################################
# lock-in role

package require Itcl
package require Device2
namespace eval device_role::lock-in {

######################################################################
# Use Stanford Research Systems Lock-in SR844.
#
# ID string:
#  Stanford_Research_Systems,SR844,s/n43078,ver1.005
#
# Channels: no
#
# Options:
#   -editable (0|1) -- allow setting parameters via the widget
#   -range <value>  -- set range
#   -tconst <value>  -- set time constant

itcl::class sr844 {
  inherit base
  proc test_id {id} {
    if {[regexp {,SR844,} $id]} {return 1}
  }

  variable editable
  constructor {args} {
    chain {*}$args
    xblt::parse_options "lock_in::sr844" $dev_opts \
    [list \
      {-editable} editable 1\
      {-range}    range  {}\
      {-tconst}   tconst {}\
    ]
    if {$range  ne {}} {set_range  $range}
    if {$tconst ne {}} {set_tconst $tconst}
    set dev_info "$dev_name (SR844)"
  }

  variable R
  variable T

  # lock-in ranges and time constants
  common ranges  {1e-7 3e-7 1e-6 3e-6
                  1e-5 3e-5 1e-4 3e-4
                  1e-3 3e-3 1e-2 3e-2
                  0.1 0.3 1}
  common tconsts   {1e-4 3e-4 1e-3 3e-3 1e-2 3e-2
                    0.1 0.3 1.0 3.0 10.0 30.0 1e2 3e3 1e3 3e3 1e4 3e4}

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

  method on_update {} {
    get_range
    get_tconst
  }

  ##########################################################
  # Widget

  method make_widget {tkroot args} {
    chain $tkroot {*}$args
    frame $tkroot.f
    grid $tkroot.f

    label $tkroot.f.range_l -text "Range, Vrms:" -font {-size 8}
    label $tkroot.f.tconst_l -text "TConst, s:" -font {-size 8}
    if {$editable} {
      ttk::combobox $tkroot.f.range -width 6 -values $ranges\
        -textvariable [itcl::scope R] -justify right
      bind $tkroot.f.range <<ComboboxSelected>> "$this set_range"
      ttk::combobox $tkroot.f.tconst -width 5 -values $tconsts\
         -textvariable [itcl::scope T] -justify right
      bind $tkroot.f.tconst <<ComboboxSelected>> "$this set_tconst"
    } else {
      label $tkroot.f.range -textvariable [itcl::scope R]
      label $tkroot.f.tconst -textvariable [itcl::scope T]
    }
    grid $tkroot.f.range_l $tkroot.f.tconst_l -padx 2 -pady 0 -sticky w
    grid $tkroot.f.range $tkroot.f.tconst -padx 1 -pady 0 -sticky e

    # Update button
    button $tkroot.upd -text "Update" -command "$this on_update" -pady 0
    grid $tkroot.upd -padx 5 -pady 2 -sticky w
    on_update
  }

}
######################################################################
} # namespace
