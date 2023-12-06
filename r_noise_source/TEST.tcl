######################################################################
# TEST device

package require Itcl
namespace eval device_role::noise_source {

itcl::class TEST {
  inherit base
  proc test_id {id} {}
  variable volt
  variable bw
  variable offs
  variable onoff

  constructor {args} {
    chain {*}$args
    set volt 0
    set bw 1000
    set offs 0
    set onoff 1
    set max_v 10
    set min_v 0
  }
  method set_noise {b v {o 0}} {
    if {$v < $min_v} {set v $min_v}
    if {$v > $max_v} {set v $max_v}
    set volt $v
    set offs $o
    set bw   $b
    set onoff 1
  }
  method get_volt {} { return [expr {$onoff ? $volt:0}] }
  method get_bw   {} { return $bw }
  method get_offs {} { return [expr {$onoff ? $offs:0}] }
  method off {} {set onoff 0;}
  method on  {} {set onoff 1;}
}

}; # namespace
