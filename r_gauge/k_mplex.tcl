######################################################################
# Keysight/Agilent/HP multiplexer 34972A
#
# ID strings:
#   Agilent Technologies,34972A,MY59000704,1.17-1.12-02-02
#
# Channels: space-separated list of channel settings:
#   ACI(101-102) DCV(103-104),etc.
# Channel numbers are set as in the device: comma-separated lists: 101,105
# or colon-separated ranges 101:105.
# Valid prefixes are: DCI, ACV, DCV, R2, R4
# For R4 measurement channels are pairs with n+10 (34901A extension or
# n+8 (34902A extension)
#
# Tested:
#   2020/10/05, Keysight-34972A,   V.Z.
#

package require Itcl
package require Device2
namespace eval device_role::gauge {

itcl::class k_mplex {
  inherit base
  proc test_id {id} {
    foreach n {34970A 34972A} {if {[regexp ",$n," $id]} {return $n}}
    return {}
  }

  variable cmds {};  # list of measurement commands

  constructor {d ch id} {
    set dev $d
    foreach c [split $ch { +}] {
      if {[regexp {^([A-Z0-9]+)\(([0-9:,]+)\)$} $c v0 vmeas vch]} {

        # Add measurement commend for a group of channels:
        switch -exact -- $vmeas {
          DCV {  lappend cmds "meas:volt:dc? (@$vch)" }
          ACV {  lappend cmds "meas:volt:ac? (@$vch)" }
          DCI {  lappend cmds "meas:curr:dc? (@$vch)" }
          ACI {  lappend cmds "meas:curr:ac? (@$vch)" }
          R2  {  lappend cmds "meas:res? (@$vch)"     }
          R4  {  lappend cmds "meas:fres? (@$vch)"    }
          default {
            error "$this: bad channel setting: $c"
            return
          }
        }

        # Calculate number of device channels
        #  N1:N2,N3,N3 etc.
        foreach c [split $vch {,}] {
          if {[regexp {^ *([0-9]+) *$} $c v0 n1]} {
            lappend valnames $n1
          }\
          elseif {[regexp {^ *([0-9]+):([0-9]+) *$} $c v0 n1 n2]} {
            if {$n2<=$n1} {error "non-increasing channel range: $c"}
            for {set n $n1} {$n<=$n2} {incr n} {
              lappend valnames $n
            }
          }
        }

      } else {
        error "bad channel setting: $c"
      }
    }
  }

  ############################
  method get {} {
    set ret {}
    foreach c $cmds {
      dev_err_clear $dev
      set ret [concat $ret [split [Device2::ask $dev $c] {,}]]
      dev_err_check $dev
    }
    return $ret
  }
  method get_auto {} {
    return [get]
  }

}

}; # namespace
