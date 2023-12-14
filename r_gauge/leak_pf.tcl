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

  constructor {args} {
    chain {*}$args
  }

  ############################
  method get {} {
    set data [Device2::ask $dev_name "leak?"]
    update_widget $data
    return $data
  }
  method get_auto {} { return [get] }
}

}; # namespace
