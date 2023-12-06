######################################################################
# Korad/Velleman/Tenma power suppies
# See also d_tenma_ps.tcl

package require Itcl
package require Device2
namespace eval device_role::dc_source {

itcl::class tenma {
  variable base ::device_role::power_supply::tenma
  inherit ::device_role::power_supply::tenma
  proc test_id {id} {::device_role::power_supply::tenma::test_id $id}
  # we use Device from $base class
  method get_device {} {return ${base}::dev}

  constructor {args} {
    chain {*}$args
    ${base}::set_curr $max_i
    Device2::ask $dev_name"OVP0";  # clear OVP/OCP
    Device2::ask $dev_name"OCP0";  #
    Device2::ask $dev_name"BEEP1"; # beep off
  }
  method set_volt {val} {
    ${base}::set_volt $val
    if {[${base}::get_stat] == {OFF}} { ${base}::on }
  }
  method off {} { ${base}::off }
  method get_volt {} { ${base}::get_volt }
}

}; # namespace
