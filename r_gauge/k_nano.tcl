######################################################################
# Keithley nanovoltmeter 2182A
#
# ID strings:
# KEITHLEY INSTRUMENTS INC.,MODEL 2182A,1193143,C02 /A02
# Use channels DCV1 DCV2
#
# Tested:
#   2020/10/13, Keythley-2182A,   V.Z.

package require Itcl
package require Device2
namespace eval device_role::gauge {

itcl::class k_nano {
  inherit base
  proc test_id {id} {
    if {[regexp {2182A,} $id]} {return {2182A}}
    return {}
  }

  constructor {d ch id} {
    switch -exact -- $ch {
      DCV1 { set chan 1 }
      DCV2 { set chan 2 }
      default { error "$this: bad channel setting: $ch" }
    }
    set dev $d
    dev_check $dev "conf:volt:DC"
    dev_check $dev "sens:chan $chan"
    dev_check $dev "sens:volt:rang:auto 1"
    dev_check $dev "samp:count 1"
  }

  ############################
  method get {} {
    return [Device2::ask $dev "read?"]
  }
  method get_auto {} {
    return [get]
  }

}

}; # namespace
