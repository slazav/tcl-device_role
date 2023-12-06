######################################################################
# TEST device

package require Itcl
namespace eval device_role::dgen {

itcl::class TEST {
  inherit base
  proc test_id {id} {}

  constructor {args} {
    chain {*}$args
    set dev_ac1 [DeviceRole TEST:1 ac_source]
    set dev_ac2 [DeviceRole TEST:2 ac_source]
  }
}

}; # namespace
