######################################################################
# HP/Agilent/Keysight 1- and 2-channel generators
#
# 2-channel devices (Use channels 1 or 2 to set output):
# Agilent Technologies,33510B,MY52201807,3.05-1.19-2.00-52-00
# Agilent Technologies,33522A,MY50005619,2.03-1.19-2.00-52-00
#
# 1-channel devices (No channels supported):
# Agilent
# Technologies,33511B,MY52300310,2.03-1.19-2.00-52-00
# Agilent Technologies,33521B,MY52701054,2.09-1.19-2.00-52-00

package require Itcl
package require Device2
namespace eval device_role::ac_source {

itcl::class keysight {
  inherit base
  proc test_id {id} { return [keysight_gen_model $id] }

  method get_device_info {} {return $dev_info}

  variable spref
  constructor {args} {
    chain {*}$args
    set max_v 20
    set min_v 0.002
    set spref [keysight_gen_spref $dev_model $dev_chan]

    dev_set_par $dev_name "${spref}BURST:STATE" "0"
    dev_set_par $dev_name "${spref}VOLT:UNIT" "VPP"
    dev_set_par $dev_name "UNIT:ANGL"         "DEG"
    dev_set_par $dev_name "${spref}FUNC"      "SIN"
    dev_set_par $dev_name "OUTP${dev_chan}:LOAD"  "INF"
  }

  # get_* methods do NOT update interface.
  # If they are called regularly, it should not
  # prevent user from typing new values in the interface.
  method get_volt {}  {
    set v [expr [Device2::ask $dev_name "${spref}VOLT?"]]
    if {$ac_shift != 0} {set v [expr $v-$ac_shift]}
    return $v
  }
  method get_freq {} {
    return [expr [Device2::ask $dev_name "${spref}FREQ?"]]
  }
  method get_offs {} {
    return [expr [Device2::ask $dev_name "${spref}VOLT:OFFS?"]]
  }
  method get_phase {} {
    return [expr [Device2::ask $dev_name "${spref}PHAS?"]]
  }
  method get_out {} {
    return [Device2::ask $dev_name "OUTP${dev_chan}?"]
  }


  method set_ac {f v {o 0} {p {}}} {
    chain $f $v $o $p; # update interface
    dev_check $dev_name "${spref}APPLY:SIN $f,[expr $v+$ac_shift],$o"
    if {$p ne {}} {set_phase $p}
  }
  method set_volt {v} {
    chain $v;  # set value in the base class (update interface)
    if {$ac_shift != 0} {set v [expr $v+$ac_shift]}
    dev_set_par $dev_name "${spref}VOLT" $v
  }
  method set_freq {v} {
    chain $v
    dev_set_par $dev_name "${spref}FREQ" $v
  }
  method set_offs {v}  {
    chain $v
    dev_set_par $dev_name "${spref}VOLT:OFFS" $v
  }
  method set_phase {v} {
    chain $v
    set v [expr $v-int($v/360.0)*360]
    dev_set_par $dev_name "${spref}PHAS" $v
  }
  method set_out {v} {
  # For Keysight generators it maybe useful to switch to burst mode
  # to reduce signal leakage.
    chain $v
    dev_set_par $dev_name "OUTP${dev_chan}" [expr {$v?1:0}]
  }

  method set_sync {state} {
    if {$dev_chan != {}} {
      dev_set_par $dev_name "OUTP:SYNC:SOUR" "CH${dev_chan}"
    }
    if {$state} { dev_set_par $dev_name "OUTP:SYNC" 1 }\
    else        { dev_set_par $dev_name "OUTP:SYNC" 0 }
  }
}

}; # namespace
