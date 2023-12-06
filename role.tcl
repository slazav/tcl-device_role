######################################################################
# Usage:
#
#   set dev [DeviceRole <name>:<channel> <role> <options> ...]
#
#  <role>    - A "role", interface supported by the device
#              such as "gauge", "power_supply", "ac_source", etc.
#  <name>    - Device name used in Device2 server configuration,
#              should me configured in /etc/device2/devices.txt
#  <channel> - A parameter for the driver. Can be a physical channel
#              for multi-channel devices, operation mode, or something
#              else. See documenation/code of specific drivers.
#  <options> - Pairs of driver-specific "-<key> <value>" options.
#              Additional parameters for the driver.
#  <dev>     - A returned object which implements the role interface.
#
# Example:
#   set dev [DeviceRole power_supply ps0:1L --ovp 5]
#   $dev set_curr 0.1
#
# This means "use channel 1L of Device ps0 as a power_supply,
# with additional parameter -ovp 5".
# power_supply commands and parameters can be found in power_supply/<driver>.tcl file.
# Channel can be set for some devices, see power_supply/*.tcl
#
# Device role should be a namespace with drivers + BASE and TEST classes.
#
# Drivers is constructed with following arguments: dev_name, dev_chan, dev_id, dev_model, dev_opts
# Normally they should be passed to the base class with `chain {*}$args` command.
#
# The device_role::base class sets dev_name, dev_chan, dev_id, dev_model, dev_opts
# variables in the constructor.
#
# Drivers should implement `proc test_id {id}` - gets ID string, returns non-empty string ("model")
# if driver supports the device
#
# method dev_info {} - get device information for the interface, <name>:<chan>, can be overriden
# with a driver
#
# Driver may implement:
# - method make_widget {root opts} - make driver-specific widget for embedding in measurement interfaces
#
package require Itcl
package require Device2

namespace eval device_role {}

######################################################################
# create the DeviceRole object
proc DeviceRole {name role args} {
  ## parse device name:
  set chan {}
  if {[regexp {^([^:]*):(.*)} $name x n c]} {
    set name $n
    set chan $c
  }\

  # role namespace
  set ns ::device_role::${role}

  # return test device
  if {$name == "TEST"} { return [${ns}::TEST #auto ${name} $chan TEST TEST $args] }

  # Ask the Device for ID.
  set id [Device2::ask $name *IDN?]
  if {$id == {}} {error "Can't get device id: $name"}

  # Find all classes in the correct namespace.
  # Try to match ID string, return an object of the correct class.
  foreach drv [itcl::find classes ${ns}::*] {
    set model [${drv}::test_id $id]
    if {$model != {}} { return [$drv ${drv}::#auto ${name} $chan $id $model $args] }
  }
  error "Do not know how to use device $name (id: $id) as a $role"
}

######################################################################
# Check if <name> is a DeviceRole object
proc DeviceRoleExists {name} {
  if {[catch {set base [lindex [$name info heritage] end]} ]} { return 0 }
  return [expr {$base == {::device_role::base}}]
}


######################################################################
# Delete the DeviceRole object.
proc DeviceRoleDelete {name} {

  if {![DeviceRoleExists $name]} {error "Not a DeviceRole object: $name"}

  # Close device (empty for TEST devices):
  set d [$name get_dev_name]
  if {$d ne {}} {Device2::release $d}

  # delete the DeviceRole object:
  itcl::delete object $name
}

######################################################################
## Base interface class. All role interfaces are children of it
itcl::class device_role::base {

  # define all variables anf get_* methods
  foreach v {dev_name dev_chan dev_id dev_model dev_opts dev_info} {
    protected variable $v {}
    method get_$v {} [subst -nocommands { return [subst $$v] }]
  }

  constructor {args} {
    set dev_name  [lindex $args 0]
    set dev_chan  [lindex $args 1]
    set dev_id    [lindex $args 2]
    set dev_model [lindex $args 3]
    set dev_opts  [lindex $args 4]
    if {$dev_chan eq {}} {set dev_info $dev_name}\
    else {set dev_info "$dev_name:$dev_chan"}
  }
}
