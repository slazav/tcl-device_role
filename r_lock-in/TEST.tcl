######################################################################
# TEST device

package require Itcl
namespace eval device_role::lock-in {

itcl::class TEST {
  inherit base
  proc test_id {id} {}

  constructor {d ch id args} {
    set dev "TEST"
    set M 1
  }
  destructor {}

  ############################
  method get {} {
    set X [expr rand()]
    set Y [expr rand()]
    update_interface $X $Y "OK"
    return [list $X $Y]
  }
  method get_tconst {} {return 1}
}

}; # namespace
