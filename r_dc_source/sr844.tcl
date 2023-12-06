######################################################################
# Lockin SR844 auxilary outputs
#
# ID string:
#   Stanford_Research_Systems,SR844,s/n50066,ver1.006
#
# Use channels 1 or 2 to set auxilary output

package require Itcl
package require Device2
namespace eval device_role::dc_source {

itcl::class sr844 {
  inherit base
  proc test_id {id} {
    if {[regexp {,SR844,} $id]} {return 1}
  }

  variable chan;  # channel to use (1..2)
  constructor {d ch id} {
    if {$ch!=1 && $ch!=2} {
      error "$this: bad channel setting: $ch"}
    set chan $ch

    set dev $d
    set max_v +10.5
    set min_v -10.5
    set min_v_step 0.001
  }
  method set_volt {val} {
    Device2::ask $dev "AUXO${chan},$val"
  }
  method off {} {
    set_volt 0
  }
  method get_volt {} { return [Device2::ask $dev "AUXO?${chan}"] }
}

}; # namespace
