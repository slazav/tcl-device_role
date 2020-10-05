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
package require Device

namespace eval device_role {}

# Array for counting devices.
variable device_counter

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


  ## Create Device if needed, set device_counter.
  # The reference counter is used because many drivers
  # can work with a single device (different channels,
  # different roles) and device can be already opened
  # Is device exists?
  global device_counter
  if {[info commands $name]!={}} {
    # is it a Device?
    if {[lindex [$name info heritage] end] != {::Device}} {
      error "Not a Device object: $name"
    }
    # is counter exists (other role uses the device)?
    if {[array get device_counter $name] != {}} {
      incr device_counter($name)
    } else {
      # somebody else uses the device, start from 2
      set device_counter($name) 2
    }
  }\
  else {
    # Reference counter should be unset for closed devices.
    if {[array get device_counter $name] != {}} {
      error "DeviceRole reference counter is non-zero for non-opened device: $name"
    }
    # open the device
    Device $name
    set device_counter($name) 1
  }

  # puts "device_counter($name) -> $device_counter($name)"

  # Ask the Device for ID.
  set ID [$name cmd *IDN?]
  if {$ID == {}} {error "Can't get device id: $name"}

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

  # Get the device object (empty for TEST devices):
  set d [$name get_device]
  global device_counter
  if {$d!={}} {
    # Device should exists
    if {[info commands $d]=={}} {
      error "DeviceRoleDelete: Device is already closed: $d"
    }
    # Device should have the proper type
    if {[lindex [$d info heritage] end] != {::Device}} {
      error "DeviceRoleDelete: Not a Device object: $d"
    }
    # Reference counter for the device should exist
    if {[array get device_counter $d] == {}} {
      error "DeviceRoleDelete: No reference counter for the device: $d"
    }
    # Decrease the reference counter
    incr device_counter($d) -1
      # puts "device_counter($d) <- $device_counter($d)"
    # Close the device if needed:
    if {$device_counter($d)<1} {
      itcl::delete object $d
      array unset device_counter $d
    }
  }

  # delete the DeviceRole object:
  itcl::delete object $name
}

######################################################################
## Base interface class. All role interfaces are children of it
itcl::class device_role::base_interface {
  variable dev {}; ## Device handler (see Device library)

  # Drivers should provide constructor with "device" and "channel" parameters
  constructor {} {}

  method lock {} {$dev lock}
  method unlock {} {$dev unlock}
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
