######################################################################
# EastTester ET4502, ET1091 LCR meters
#
# ZC,ET1091B        ,V1.01.2026.016,V1.12.2035.007,10762110001
#
# Channels: <v1>-<v2>
#  v1: R C L Z DCR ECAP
#  v2: X D Q THR ESR

package require Itcl
package require Device2
namespace eval device_role::gauge {

itcl::class lcr_et4502 {
  inherit base
  proc test_id {id} {
    if {[regexp {,ET4502}  $id]} {return "ET4502"}
    if {[regexp {,ET1091B} $id]} {return "ET1091B"}
    return {}
  }

  constructor {args} {
    chain {*}$args
    set c [split $dev_chan {-}]
    if {[llength $c] == 0} {
      set A "C"
      set B "Q"
    }\
    elseif {[llength $c] == 2} {
      set A [lindex $c 0]
      set B [lindex $c 1]
      if {[lsearch -exact {R C L Z DCR ECAP} $A] < 0} {
        error "lcr_et4502: wrong A measurement: $A, should be one of R C L Z DCR ECAP"
      }
      if {[lsearch -exact {X D Q THR ESR} $B] < 0} {
        error "lcr_et4502: wrong B measurement: $B, should be one of X D Q THR ESR"
      }
    }\
    else {
      error "lcr_et4502: bad channel setting: $dev_chan"
    }
    set names [list $A $B]
    Device2::ask $dev_name FUNC:DEV:MODE OFF
    Device2::ask $dev_name FUNC:IMP:A $A
    Device2::ask $dev_name FUNC:IMP:B $B
    Device2::ask $dev_name FUNC:IMP:RANG:AUTO ON
    Device2::ask $dev_name FUNC:IMP:EQU SER
    after 100
  }

  ############################
  method get {} {
    return [join [split [Device2::ask $dev_name fetch?] {,}]]
  }
}

}; # namespace
