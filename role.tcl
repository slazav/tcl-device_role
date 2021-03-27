######################################################################
# Usage:
#
#   set dev [DeviceRole <name>:<channel> <role>]
#
#  <name>    - Device name in Device library,
#              should me configured in /etc/devices.txt
#  <channel> - A parameter for the driver. Can be a physical channel
#              for multi-channel devices, operation mode, or something
#              else. See documenation/code of specific drivers.
#  <role>    - A "role", some interface supported by the device
#              such as "gauge", "power_supply", "ac_source", etc.
#  <dev>     - a returned object which implements the role interface.
#
# Example:
#   set dev [DeviceRole ps0:1L power_supply]
#   $dev set_curr 0.1
#
# This means "use channel 1L of Device ps0 as a power_supply".
# power_supply commands can be found in ./power_supply.tcl file.
# Channel can be set for some devices, see power_supply/*.tcl

package require Itcl
package require Device2

namespace eval device_role {}

######################################################################
# create the DeviceRole object
proc DeviceRole {name role} {
  ## parse device name:
  set chan {}
  if {[regexp {^([^:]*):(.*)} $name x n c]} {
    set name $n
    set chan $c
  }\

  # role namespace
  set n ::device_role::${role}

  # return test device
  if {$name == "TEST"} {return [${n}::TEST #auto ${name} $chan {}]}

  # Ask the Device for ID.
  set ID [Device2::ask $name *IDN?]
  if {$ID == {}} {error "Can't get device id: $name"}

  # old-style interface
  if {[info commands $name] eq {}} { Device $name}
  if {[lindex [$name info heritage] end] != {::Device}} {
    error "can't create device: non-device object exists: $name" }

  # Find all classes in the correct namespace.
  # Try to match ID string, return an object of the correct class.
  foreach m [itcl::find classes ${n}::*] {
    if {[${m}::test_id $ID] != {}} { return [$m ${m}::#auto ${name} $chan $ID] }
  }
  error "Do not know how to use device $name (id: $ID) as a $role"
}

######################################################################
# Check if <name> is a DeviceRole object
proc DeviceRoleExists {name} {
  if {[catch {set base [lindex [$name info heritage] end]} ]} { return 0 }
  return [expr {$base == {::device_role::base_interface}}]
}


######################################################################
# Delete the DeviceRole object.
proc DeviceRoleDelete {name} {

  if {![DeviceRoleExists $name]} {error "Not a DeviceRole object: $name"}

  # Close device (empty for TEST devices):
  set d [$name get_device]
  if {$d ne {}} {Device2::release $d}

  # delete the DeviceRole object:
  itcl::delete object $name
}

######################################################################
## Base interface class. All role interfaces are children of it
itcl::class device_role::base_interface {
  variable dev {}; ## Device handler (see Device library)

  # Drivers should provide constructor with "device" and "channel" parameters
  constructor {} {}

  method lock {} {Device2::lock $dev}
  method unlock {} {Device2::unlock $dev}
  method get_device {} {return $dev}

  # Get list of configuation options.
  # Each entry contains a list of two values: {name} {type}
  # types: <list>, string, bool, const
  #
  # Example:
  # {{range  {1 2 5 10 20 50}}
  #  {tconst {10ms 100ms 1s 10s}}
  #  {autorange bool}
  #  {status const}
  # }
  method conf_list {} {return {}}

  # Get configuration option
  method conf_get {name} { error "unknown configuration option: $name" }

  # Set configuration option
  method conf_set {name val} { error "unknown configuration option: $name" }
}
