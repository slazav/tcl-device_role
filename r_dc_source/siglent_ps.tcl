######################################################################
# Siglent SPD 1168X/1305X/3303C power supplies
# See ../power_supply/siglent.tcl

package require Itcl
package require Device2
namespace eval device_role::dc_source {

itcl::class siglent {
  variable base ::device_role::power_supply::siglent
  inherit ::device_role::power_supply::siglent
  proc test_id {id} {::device_role::power_supply::siglent::test_id $id}
  # we use Device from $base class
  method get_device {} {return $dev_name}

  constructor {args} {
    chain {*}$args
    # set max current
    ${base}::set_curr $max_i
  }
  method set_volt {val} {
    ${base}::set_volt $val
    if {[${base}::get_stat] == {OFF}} { ${base}::on }
  }
  method off {} { ${base}::off }
  method get_volt {} { ${base}::get_volt }
}

}; # namespace
