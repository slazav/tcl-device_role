######################################################################
# Test device

package require Itcl
namespace eval device_role::burst_source {

itcl::class TEST {
  inherit base
  proc test_id {id} {}
  variable fre
  variable amp
  variable cyc
  variable offs
  variable ph

  constructor {args} {
    chain {*}$args
    set fre 1000
    set amp 0.1
    set cyc 10
    set offs 0
    set ph   0
    set max_v 10
    set min_v 0
  }

  method set_burst {f a c {o 0} {p 0}} {
    if {$a < $min_v} {set a $min_v}
    if {$a > $max_v} {set a $max_v}
    set fre  $f
    set amp  $a
    set cyc  $c
    set offs $o
    set ph   $p
  }

  method do_burst {} {}

  method get_volt {} { return $amp }
  method get_freq {} { return $fre }
  method get_offs {} { return $offs }
  method get_cycl {} { return $cyc }
  method get_phase {} { return $ph }

  method set_volt  {v} { set amp  $v }
  method set_freq  {v} { set fre  $v }
  method set_offs  {v} { set offs $v }
  method set_cycl  {v} { set cyc  $v }
  method set_phase {v} { set ph   $v }
}


}; # namespace
