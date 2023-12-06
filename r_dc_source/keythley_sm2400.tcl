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
    if {[regexp {,MODEL 2400,} $id]} {return 2400}
  }

  constructor {args} {
    chain {*}$args
    switch -exact -- $dev_chan {
      DCV {  set cmd ":sour:func volt"; set cmd "sour:volt:range:auto on" }
      DCI {  set cmd ":sour:func curr"; set cmd "sour:curr:range:auto on" }
      default {
        error "$this: bad channel setting: $dev_chan"
        return
      }
    }
  }
  method set_volt {val} {
    Device2::ask $dev_name ":sour:volt:lev $val"
  }
  method set_curr {val} {
    Device2::ask $dev_name ":sour:curr:lev $val"
  }

  method set_volt_range {val} {
    Device2::ask $dev_name ":sour:volt:range $val"
  }
  method set_curr_range {val} {
    Device2::ask $dev_name ":sour:curr:range $val"
  }

  method get_volt {} {
    Device2::ask $dev_name ":sour:volt:lev?"
  }
  method get_curr {} {
    Device2::ask $dev_name ":sour:curr:lev?"
  }

  method get_volt_range {} {
    Device2::ask $dev_name ":sour:volt:range?"
  }
  method get_curr_range {} {
    Device2::ask $dev_name ":sour:curr:range?"
  }

  method on {} {
    Device2::ask $dev_name ":outp on"
  }
  method off {} {
    Device2::ask $dev_name ":outp off"
  }
}

}; # namespace
