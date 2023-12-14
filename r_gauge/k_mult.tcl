######################################################################
# Keysight/Agilent/HP 34401A, 34410A, 34461A multimeters,
# Keyley 2000 multimeter
#
# ID strings:
#   Keysight Technologies,34461A,MY53220594,A.02.14-02.40-02.14-00.49-01-01
#   Agilent Technologies,34461A,MY53200874,A.01.08-02.22-00.08-00.35-01-01
#   Agilent Technologies,34410A,MY47006594,2.35-2.35-0.09-46-09
#   HEWLETT-PACKARD,34401A,0,6-4-2
#   KEITHLEY INSTRUMENTS INC.,MODEL 2000,1234147,A20 /A02
#
# Use channels ACI, DCI, ACV, DCV, R2, R4
#
# Tested:
#   2020/10/05, Keythley-2020,   V.Z.
#   2020/10/05, Keysight-34410A, V.Z.
#

package require Itcl
package require Device2
namespace eval device_role::gauge {

######################################################################

itcl::class k_mult {
  inherit base

  # measurement function (volt:dc etc.), set in the constructor
  variable func

  proc test_id {id} {
    if {[regexp {,34461A,} $id]} {return {34461A}}
    if {[regexp {,34401A,} $id]} {return {34401A}}
    if {[regexp {,34410A,} $id]} {return {34410A}}
    if {[regexp {KEITHLEY.*MODEL.2000} $id]} {return {Keythley2000}}
    return {}
  }

  constructor {args} {
    chain {*}$args
    switch -exact -- $dev_chan {
      DCV {  set func volt:dc }
      ACV {  set func volt:ac }
      DCI {  set func curr:dc }
      ACI {  set func curr:ac }
      R2  {  set func res     }
      R4  {  set func fres    }
      default {
        error "$this: bad channel setting: $dev_chan"
        return
      }
    }
    set valnames $dev_chan
    dev_err_clear $dev_name
    Device2::ask $dev_name "meas:$func?"
    dev_err_check $dev_name
  }

  ############################
  method get {} {
    set data [Device2::ask $dev_name "read?"]
    update_widget $data
    return $data
  }
  method get_auto {} {
    return [get]
  }
}

}; # namespace
