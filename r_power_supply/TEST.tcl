######################################################################
# TEST device

package require Itcl
namespace eval device_role::power_supply {

itcl::class TEST {
  inherit base
  proc test_id {id} {}

  variable R 0.1
  variable I 0
  variable V 0
  variable OVP 0
  variable OCP 0
  variable mode OFF

  constructor {d ch id} {
    set dev {}
    set max_i 3.09
    set min_i 0.0
    set max_v 60.0
    set min_v 0.0
    set min_i_step 0.001
    set min_v_step 0.01
    set i_prec 0.01
  }
  destructor {}

  private method check_ocp {} {
    if {$mode=="OFF"} return
    if {$OCP==0 || $V/$R<=$OCP} return
    set I 0
    set V 0
    set mode OCP
  }
  private method check_ovp {} {
    if {$mode=="OFF"} return
    if {$OVP==0 || $I*$R<=$OVP} return
    set I 0
    set V 0
    set mode OVP
  }

  method set_volt {val} {
    set V $val
    if {$I*$R < $V} { set mode "CC"; return }
    set mode "CV"
    check_ocp
  }
  method set_curr {val} {
    set I $val
    if {$V/$R < $I} {
      set mode "CV"
    } else {
      set mode "CC"
    }
    check_ovp
  }
  method set_ovp  {val} {
    set V $val
    set OVP $val
    check_ovp
  }
  method set_ocp  {val} {
    set I $val
    set OCP $val
    check_ocp
  }
  method get_curr {} {
    if {$mode == "OFF"} {return 0}
    if {$mode == "CC"}  {return $I}
    return [expr $V/$R]
  }
  method get_volt {} {
    if {$mode == "OFF"} {return 0}
    if {$mode == "CV"}  {return $V}
    return [expr $I*$R]
  }

  method cc_reset {} {
    set mode CC
  }

  method cv_reset {} {
    set mode CV
  }

  method off {} {
    set mode OFF
    set I 0
    set V 0
  }

  method get_stat {} {
    return $mode
  }
}

}; # namespace
