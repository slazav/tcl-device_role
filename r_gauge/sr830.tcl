######################################################################
# Use Lockin SR830 as a gauge.
#
# ID string:
#   Stanford_Research_Systems,SR830,s/n46117,ver1.07
#
# Use channels 1 or 2 to measure voltage from auxilary inputs,
# channels XY RT FXY FRT to measure lockin X Y R Theta values
#
# Tested:
#   2020/10/05, SR830,   V.Z.
#

package require Itcl
package require Device2
namespace eval device_role::gauge {

itcl::class sr830 {
  inherit base
  proc test_id {id} {
    if {[regexp {,SR830,} $id]} {return 1}
    return {}
  }

  # lock-in ranges and time constants
  common ranges
  common ranges_V  {2e-9 5e-9 1e-8 2e-8 5e-8 1e-7 2e-7 5e-7 1e-6 2e-6 5e-6 1e-5 2e-5 5e-5 1e-4 2e-4 5e-4 1e-3 2e-3 5e-3 1e-2 2e-2 5e-2 0.1 0.2 0.5 1.0}
  common ranges_A  {2e-15 5e-15 1e-14 2e-14 5e-14 1e-13 2e-13 5e-13 1e-12 2e-12 5e-12 1e-11 2e-11 5e-11 1e-10 2e-10 5e-10 1e-9 2e-9 5e-9 1e-8 2e-8 5e-8 1e-7 2e-7 5e-7 1e-6}
  common tconsts   {1e-5 3e-5 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0 3.0 10.0 30.0 1e2 3e3 1e3 3e3 1e4 3e4}

  common aux_range 10;    # auxilary input range: +/- 10V
  common aux_tconst 3e-4; # auxilary input bandwidth: 3kHz

  common isrc;            # input 0-3 A/A-B/I_1MOhm/I_100MOhm

  constructor {args} {
    chain {*}$args
    switch -exact -- $dev_chan {
      1   {set valnames {AUX1}}
      2   {set valnames {AUX2}}
      XY  {set valnames [list X Y]}
      RT  {set valnames [list R T]}
      FXY {set valnames [list F X Y]}
      FRT {set valnames [list F R T]}
      default {error "$this: bad channel setting: $dev_chan"}
    }
  }

  ############################
  method get {{auto 0}} {
    # If channel is 1 or 2 read auxilary input:
    if {$dev_chan==1 || $dev_chan==2} { return [Device2::ask $dev_name "OAUX?${dev_chan}"] }

    # If autorange is needed, use AGAN command:
    if {$auto} {Device2::ask $dev_name "AGAN"; after 100}

    # Return space-separated values depending on channel setting
    if {$dev_chan=="XY"} { return [string map {"," " "} [Device2::ask $dev_name SNAP?1,2]] }
    if {$dev_chan=="RT"} { return [string map {"," " "} [Device2::ask $dev_name SNAP?3,4]] }
    if {$dev_chan=="FXY"} { return [string map {"," " "} [Device2::ask $dev_name SNAP?9,1,2]] }
    if {$dev_chan=="FRT"} { return [string map {"," " "} [Device2::ask $dev_name SNAP?9,3,4]] }
  }
  method get_auto {} { return [get 1] }

  ############################
  method list_ranges {} {
    if {$dev_chan==1 || $dev_chan==2} {return $aux_range}
    set isrc [Device2::ask $dev_name "ISRC?"]
    if {$isrc == 0 || $isrc == 1} { set ranges $ranges_V } { set ranges $ranges_A }
    return $ranges
  }
  method list_tconsts {} {
    if {$dev_chan==1 || $dev_chan==2} {return $aux_tconst}
    return $tconsts
  }

  ############################
  method set_range  {val} {
    if {$dev_chan==1 || $dev_chan==2} { error "can't set range for auxilar input $dev_chan" }
    set n [lsearch -real -exact $ranges $val]
    if {$n<0} {error "unknown range setting: $val"}
    Device2::ask $dev_name "SENS $n"
  }
  method set_tconst {val} {
    if {$dev_chan==1 || $dev_chan==2} { error "can't set time constant for auxilar input $dev_chan" }
    set n [lsearch -real -exact $tconsts $val]
    if {$n<0} {error "unknown time constant setting: $val"}
    Device2::ask $dev_name "OFLT $n"
  }

  ############################
  method get_range  {} {
    if {$dev_chan==1 || $dev_chan==2} { return $aux_range}
    set isrc [Device2::ask $dev_name "ISRC?"]
    if {$isrc == 0 || $isrc == 1} { set ranges $ranges_V } { set ranges $ranges_A }
    set n [Device2::ask $dev_name "SENS?"]
    return [lindex $ranges $n]
  }
  method get_tconst {} {
    if {$dev_chan==1 || $dev_chan==2} { return $aux_tconst}
    set n [Device2::ask $dev_name "OFLT?"]
    return [lindex $tconsts $n]
  }

  method get_status_raw {} {
    return [Device2::ask $dev_name "LIAS?"]
  }

  method get_status {} {
    set s [Device2::ask $dev_name "LIAS?"]
    set res {}
    if {$s & (1<<0)} {lappend res "INP_OVR"}
    if {$s & (1<<1)} {lappend res "FLT_OVR"}
    if {$s & (1<<2)} {lappend res "OUTPT_OVR"}
    if {$s & (1<<3)} {lappend res "UNLOCK"}
    if {$s & (1<<4)} {lappend res "FREQ_LO"}
    if {$res == {}} {lappend res "OK"}
    return [join $res " "]
  }

}

}; # namespace
