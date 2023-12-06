######################################################################
# TEST device

package require Itcl
package require Device2
namespace eval device_role::dc_source {

itcl::class TEST {
  inherit base
  proc test_id {id} {}
  variable volt

  constructor {args} {
    chain {*}$args
    set volt  0
    set max_v 10
    set min_v -10
    set min_v_step 0.01
  }

  method set_volt {v}      {
    if {$v < $min_v} {set v $min_v}
    if {$v > $max_v} {set v $max_v}
    set volt $v
  }
  method off {}            { set volt 0  }
  method get_volt {}       { return $volt }
}

}; # namespace
