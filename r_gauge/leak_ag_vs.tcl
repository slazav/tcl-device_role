######################################################################
# Agilent VS leak detector

package require Itcl
package require Device2
namespace eval device_role::gauge {

itcl::class leak_ag_vs {
  inherit base
  proc test_id {id} {
    set id [join [split $id "\n"] " "]
    if {$id == {Agilent VS leak detector}} {return 1}
    return {}
  }

  constructor {args} {
    chain {*}$args
    set valnames [list "Leak" "Pout" "Pin"]
  }

  ############################
  method get {} {
    set v "?LP"
    set ret [Device2::ask $dev_name $v]

    # cut command name (1st word) from response if needed
    if {[lindex {*}$ret 0] == $v} {set ret [lrange {*}$ret 1 end]}

    set leak [lindex $ret 0]
    set pout [lindex $ret 1]
    set pin  [lindex $ret 2]
    # Values can have leading zeros.
    if {[string first "." $leak] == -1} {set leak "$leak.0"}
    if {[string first "." $pout] == -1} {set pout "$pout.0"}
    if {[string first "." $pin]  == -1} {set pin  "$pin.0"}

    set pout [format %.4e [expr $pout/760000.0]]; # mtor->bar
    set pin  [format %.4e [expr $pin/760000000.0]]; # utor->bar

    return [list $leak $pout $pin]
  }
  method get_auto {} { return [get] }
}

}; # namespace
