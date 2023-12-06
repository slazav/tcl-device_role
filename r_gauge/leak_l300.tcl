######################################################################
# Phoenix l300i leak detector

package require Itcl
package require Device2
namespace eval device_role::gauge {

itcl::class leak_l300 {
  inherit base
  proc test_id {id} {
    if {$id == {PhoeniXL300}} {return 1}
    return {}
  }

  constructor {args} {
    chain {*}$args
    set valnames [list "Leak" "Pin"]
  }

  ############################
  method get {} {
    # inlet pressure, measurement (calibrated)
    set pin   [Device2::ask $dev_name "*meas:p1:mbar?"]
    set leak  [Device2::ask $dev_name "*read:mbar*l/s?"]
    return [list $leak $pin]
  }
  method get_auto {} { return [get] }
}

}; # namespace
