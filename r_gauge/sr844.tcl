######################################################################
# Lockin SR844
#
# ID string:
#   Stanford_Research_Systems,SR844,s/n50066,ver1.006
#
# Use channels 1 or 2 to measure voltage from auxilary inputs,
# channels XY RT FXY FRT to measure lockin X Y R Theta values

package require Itcl
package require Device2
namespace eval device_role::gauge {

itcl::class sr844 {
  inherit base
  proc test_id {id} {
    if {[regexp {,SR844,} $id]} {return 1}
    return {}
  }

  variable chan;  # channel to use (1..2)

  # lock-in ranges and time constants
  common ranges  {1e-7 3e-7 1e-6 3e-6 1e-5 3e-5 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0}
  common tconsts {1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0 3.0 10.0 30.0 1e2 3e3 1e3 3e3 1e4 3e4}

  common aux_range 10;    # auxilary input range: +/- 10V
  common aux_tconst 3e-4; # auxilary input bandwidth: 3kHz

  constructor {d ch id} {
    switch -exact -- $ch {
      1   {set valnames {AUX1}}
      2   {set valnames {AUX2}}
      XY  {set valnames [list X Y]}
      RT  {set valnames [list R T]}
      FXY {set valnames [list F X Y]}
      FRT {set valnames [list F R T]}
      default {error "$this: bad channel setting: $ch"}
    }
    set chan $ch
    set dev $d
    get_status_raw
  }

  ############################
  method get {{auto 0}} {
    # If channel is 1 or 2 read auxilary input:
    if {$chan==1 || $chan==2} { return [Device2::ask $dev "AUXO?${chan}"] }

    # If autorange is needed, use AGAN command:
    if {$auto} {Device2::ask $dev "AGAN"; after 100}

    # Return space-separated values depending on channel setting
    if {$chan=="XY"} { return [string map {"," " "} [Device2::ask $dev SNAP?1,2]] }
    if {$chan=="RT"} { return [string map {"," " "} [Device2::ask $dev SNAP?3,5]] }
    if {$chan=="FXY"} { return [string map {"," " "} [Device2::ask $dev SNAP?8,1,2]] }
    if {$chan=="FRT"} { return [string map {"," " "} [Device2::ask $dev SNAP?8,3,5]] }
  }
  method get_auto {} { return [get 1] }

  ############################
  method list_ranges {} {
    if {$chan==1 || $chan==2} {return $aux_range}
    return $ranges
  }
  method list_tconsts {} {
    if {$chan==1 || $chan==2} {return $aux_tconst}
    return $tconsts
  }

  ############################
  method set_range  {val} {
    if {$chan==1 || $chan==2} { error "can't set range for auxilar input $chan" }
    set n [lsearch -real -exact $ranges $val]
    if {$n<0} {error "unknown range setting: $val"}
    Device2::ask $dev "SENS $n"
  }
  method set_tconst {val} {
    if {$chan==1 || $chan==2} { error "can't set time constant for auxilar input $chan" }
    set n [lsearch -real -exact $tconsts $val]
    if {$n<0} {error "unknown time constant setting: $val"}
    Device2::ask $dev "OFLT $n"
  }

  ############################
  method get_range  {} {
    if {$chan==1 || $chan==2} { return $aux_range}
    set n [Device2::ask $dev "SENS?"]
    return [lindex $ranges $n]
  }
  method get_tconst {} {
    if {$chan==1 || $chan==2} { return $aux_tconst}
    set n [Device2::ask $dev "OFLT?"]
    return [lindex $tconsts $n]
  }

  method get_status_raw {} {
    return [Device2::ask $dev "LIAS?"]
  }

  method get_status {} {
    set s [Device2::ask $dev "LIAS?"]
    set res {}
    if {$s & (1<<0)} {lappend res "UNLOCK"}
    if {$s & (1<<7)} {lappend res "FRE_CH"}
    if {$s & (1<<1)} {lappend res "FREQ_OVR"}
    if {$s & (1<<4)} {lappend res "INP_OVR"}
    if {$s & (1<<5)} {lappend res "AMP_OVR"}
    if {$s & (1<<6)} {lappend res "FLT_OVR"}
    if {$s & (1<<8)} {lappend res "CH1_OVR"}
    if {$s & (1<<9)} {lappend res "CH2_OVR"}
    if {$res == {}} {lappend res "OK"}
    return [join $res " "]
  }

}

}; # namespace
