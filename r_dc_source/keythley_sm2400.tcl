######################################################################
# Keithley SorceMeter 2400
#
# ID string:
#   KEITHLEY INSTRUMENTS INC.,MODEL 2400,1197778,C30 Mar 17 2006 09:29:29/A02 /K/J
#
# ranges:
#   -- current 1uA..1A;
#   -- voltage 200mV..200V;
# limits:
#   --current -1.05 to 1.05 (A)
#   --voltage -210 to 210 (V)
# overvoltage protection:
#     20 40 60 80 100 120 160 V

package require Itcl
package require Device2
namespace eval device_role::dc_source {

itcl::class keythley_sm2400 {
  inherit base
  proc test_id {id} {
    if {[regexp {,MODEL 2400,} $id]} {return 1}
  }

  variable chan;  # channel to use (1..2)
  constructor {d ch id} {
    switch -exact -- $ch {
      DCV {  set cmd ":sour:func volt"; set cmd "sour:volt:range:auto on" }
      DCI {  set cmd ":sour:func curr"; set cmd "sour:curr:range:auto on" }
      default {
        error "$this: bad channel setting: $ch"
        return
      }
    }
    set chan $ch
    set dev $d
  }
  method set_volt {val} {
    Device2::ask $dev ":sour:volt:lev $val"
  }
  method set_curr {val} {
    Device2::ask $dev ":sour:curr:lev $val"
  }

  method set_volt_range {val} {
    Device2::ask $dev ":sour:volt:range $val"
  }
  method set_curr_range {val} {
    Device2::ask $dev ":sour:curr:range $val"
  }

  method get_volt {} {
    Device2::ask $dev ":sour:volt:lev?"
  }
  method get_curr {} {
    Device2::ask $dev ":sour:curr:lev?"
  }

  method get_volt_range {} {
    Device2::ask $dev ":sour:volt:range?"
  }
  method get_curr_range {} {
    Device2::ask $dev ":sour:curr:range?"
  }

  method on {} {
    Device2::ask $dev ":outp on"
  }
  method off {} {
    Device2::ask $dev ":outp off"
  }
}

}; # namespace
