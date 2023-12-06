######################################################################
# Pfeiffer HLT 2xx leak detectors

package require Itcl
package require Device2
namespace eval device_role::gauge {

itcl::class leak_pf {
  inherit base
  proc test_id {id} {
    set id [string map {"\n" " "} $id]
    if {[regexp {Pfeiffer HLT 2} $id]} {return 1}
  }

  constructor {d ch id} {
    set dev $d
  }

  ############################
  method get {} {
    set ret [Device2::ask $dev "leak?"]
    return $ret
  }
  method get_auto {} { return [get] }
}

}; # namespace
