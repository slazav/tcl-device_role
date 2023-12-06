######################################################################
# TEST device

package require Itcl
namespace eval device_role::gauge {

itcl::class TEST {
  inherit base
  proc test_id {id} {}

  variable type;  # R - random, T - 10s time sweep
  variable n;     # number of values 0..maxn
  variable maxn 10;
  variable tsweep 10;

  constructor {args} {
    chain {*}$args
    set type R
    set n    1
    if {$dev_chan == {}} {
    }
    if {$dev_chan!={} && ![regexp {^(T|R)([0-9]+$)} $dev_chan v type n]} {
      error "Unknown channel setting: $dev_chan"
    }
    if {$n<1 || $n>$maxn} {
      error "Bad number in the cannel setting: $dev_chan"
    }
    for {set i 0} {$i<$n} {incr i} {lappend valnames $i}
  }
  destructor {}

  ############################
  method get {} {
    set data {}
    for {set i 0} {$i<$n} {incr i} {
      set v 0
      if {$type=={R}} { set v [expr rand()] }
      if {$type=={T}} { set v [expr {[clock milliseconds]%($tsweep*1000)}] }
      lappend data $v
    }
    return $data
  }
  method get_auto {} {
    return [get]
  }
  method list_ranges  {} {return [list 1.0 2.0 3.0]}
  method list_tconsts {} {return [list 0.1 0.2 0.3]}
  method get_range  {} {return 1.0}
  method get_tconst {} {return 0.1}
  method set_range  {v} {}
  method set_tconst {v} {}
  method get_status {} {return TEST}
}

}; # namespace
