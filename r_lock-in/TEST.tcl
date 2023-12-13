######################################################################
# lock-in role
package require Itcl
namespace eval device_role::lock-in {

######################################################################
# TEST driver

itcl::class TEST {
  inherit base
  proc test_id {id} {}
  constructor {args} { chain {*}$args }

  variable T {1.0}
  variable R {1.0}

  common ranges  {0.1 0.2 0.5 1.0 2.0 5.0}
  common tconsts {0.1 0.3 1.0 3.0}

  ##########################################################
  # Interface methods

  method get {} {
    set S "OK"
    set X [expr {2*rand()-1}]
    set Y [expr {2*rand()-1}]
    if {$X>+$R} {set S "OVL"; set X $R;}
    if {$X<-$R} {set S "OVL"; set X [expr -$R]}
    if {$Y>+$R} {set S "OVL"; set Y $R}
    if {$Y<-$R} {set S "OVL"; set Y [expr -$R]}
    update_widget $X $Y $S
    return [list $X $Y $S]
  }

  method get_range  {} {return $R}
  method get_tconst {} {return $T}

  ##########################################################
  # Other methods

  method set_range  {} {return $R}
  method set_tconst {} {return $T}

  ##########################################################
  # Widget - add Sensitivity and TimeConstant comboboxes

  method make_widget {tkroot args} {
    chain $tkroot {*}$args

    frame $tkroot.f
    grid $tkroot.f
    # Sensitivity combobox
    label $tkroot.f.range_l -text "Sensitivity, V:"
    ttk::combobox $tkroot.f.range -width 9 -values $ranges\
      -textvariable [itcl::scope R]
    bind $tkroot.f.range <<ComboboxSelected>> "$this set_range"
    grid $tkroot.f.range_l $tkroot.f.range -padx 5 -pady 2 -sticky e

    # Time constant combobox
    label $tkroot.f.tconst_l -text "Time constant, s:"
    ttk::combobox $tkroot.f.tconst -width 9 -values $tconsts\
       -textvariable [itcl::scope T]
    bind $tkroot.f.tconst <<ComboboxSelected>> "$this set_tconst"
    grid $tkroot.f.tconst_l $tkroot.f.tconst -padx 5 -pady 2 -sticky e
  }


}

######################################################################
} # namespace
