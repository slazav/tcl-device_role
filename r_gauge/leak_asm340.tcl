######################################################################
# Pfeiffer Adixen ASM340 leak detector

package require Itcl
package require Device2
namespace eval device_role::gauge {

itcl::class leak_asm340 {
  inherit base
  proc test_id {id} {
    if {$id == {Adixen ASM340 leak detector}} {return 1}
    return {}
  }

  constructor {args} {
    chain {*}$args
    set valnames [list "Leak" "Pin"]
  }

  # convert numbers received from the leak detector:
  # 123+1 -> 1.23e+03
  method conv_number {v} {
    if { [regexp {^([0-9]+)([\+\-][0-9]+)$} $v a b c] } { set v "${b}e${c}" }
    return [format "%.2e" $v]
  }

  ############################
  method get {} {
    # inlet pressure, measurement (calibrated)
    set pin   [conv_number [Device2::ask $dev_name ?PE]]
    set leak  [conv_number [Device2::ask $dev_name ?LE2]]
    set data [list $leak $pin]
    update_widget $data
    return $data
  }
  method get_auto {} { return [get] }
}

}; # namespace
