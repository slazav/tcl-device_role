######################################################################
# TEST device

package require Itcl
namespace eval device_role::ac_source {

itcl::class TEST {
  inherit base
  proc test_id {id} {}
  variable onoff

  constructor {args} {
    chain {*}$args
    set freq 1000
    set volt 0.1
    set offs  0
    set phase 0
    set onoff 1
    set min_v 0
    set max_v 10
    set out 1
  }

}

}; # namespace
