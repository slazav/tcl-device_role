######################################################################
# Andeen Hagerling AH2500 capacitance bridge.
#
# Configuration for device2 server:
#   cap_br  gpib -board <N> -addr <M> -idn AH2500 -read_cond always -delay 0.05

package require Itcl
package require Device2
namespace eval device_role::gauge {

itcl::class ah2500 {
  inherit base
  proc test_id {id} {
    if {[regexp {^AH2500$} $id]} {return 1}
    return {}
  }

  constructor {args} {
    chain {*}$args
    if {$dev_chan ne {}} { error "ah2500: no channels supported" }
  }

  ############################
  method get {} {
    regexp {C=\s*([0-9.]+)\s+(PF)\s+L=\s*([0-9.]+)\s*(NS)} \
      [Device2::ask $dev_name "SI"] X CV CU LV LU
    update_widget "$CV $LV"
    return "$CV $LV"
  }
}

}; # namespace
