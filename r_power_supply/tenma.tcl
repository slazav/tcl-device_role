######################################################################
# Korad/Velleman/Tenma power supplies

# See:
# https://sigrok.org/wiki/Korad_KAxxxxP_series
# https://sigrok.org/gitweb/?p=libsigrok.git (src/hardware /korad-kaxxxxp/)
#
# There are many devices with different id strings and limits
#   KORADKA6003PV2.0    tenma 2550 60V 3A
#   TENMA72-2540V2.0    tenma 2540 30V 5A
#   TENMA 72-2540 V2.1  tenma 2540 30V 5A
# No channels are supported

package require Itcl
package require Device2
namespace eval device_role::power_supply {

itcl::class tenma {
  inherit base
  protected variable model;
  public variable min_i;
  public variable min_v;
  public variable max_i;
  public variable max_v;
  public variable min_i_step 0.001;
  public variable min_v_step 0.01;
  public variable i_prec 0.01;

  proc test_id {id} {
    if {[regexp {KORADKA6003PV2.0} $id]}   {return {72-2550}}; # Tenma 72-2550
    if {[regexp {TENMA72-2550V2.0} $id]}   {return {72-2550}}; # Tenma 72-2550
    if {[regexp {TENMA72-2540V2.0} $id]}   {return {72-2540}}; # Tenma 72-2540
    if {[regexp {TENMA 72-2540 V2.1} $id]} {return {72-2540}}; # Tenma 72-2540
    if {[regexp {TENMA 72-2535 V2.1} $id]} {return {72-2535}}; # Tenma 72-2535
    # from https://sigrok.org
    if {[regexp {VELLEMANPS3005DV2.0}    $id]} {return {72-2550}}; # Velleman PS3005D
    if {[regexp {VELLEMANLABPS3005DV2.0} $id]} {return {72-2550}}; # Velleman LABPS3005D
    if {[regexp {KORADKA3005PV2.0}       $id]} {return {72-2550}}; # Korad KA3005P
    if {[regexp {KORAD KD3005P V2.0}     $id]} {return {72-2550}}; # Korad KA3005P
    if {[regexp {KORADKD3005PV2.0}       $id]} {return {72-2550}}; # Korad KA3005P
    if {[regexp {RND 320-KA3005P V2.0}   $id]} {return {72-2550}}; # RND KA3005P
    if {[regexp {S-LS-31 V2.0}           $id]} {return {72-2550}}; # Stamos Soldering S-LS-31
  }

  constructor {args} {
    chain {*}$args
    if {$dev_chan!={}} {error "channels are not supported for the device: $dev_name"}
    switch -exact -- $dev_model {
      72-2550 { set max_i 3.09; set max_v 60.0 }
      72-2540 { set max_i 5.09; set max_v 31.0 }
      72-2535 { set max_i 3.09; set max_v 31.0 }
      default { error "tenma_ps: unknown model: $dev_model" }
    }
    set min_i 0.0
    set min_v 0.0
    set min_i_step 0.001
    set min_v_step 0.01
    set i_prec 0.02
  }

  method set_volt {val} {
    set val [expr {round($val*100)/100.0}]
    Device2::ask $dev_name "VSET1:$val"
  }
  method set_curr {val} {
    set val [expr {round($val*1000)/1000.0}]
    Device2::ask $dev_name "ISET1:$val"
  }
  method set_ovp  {val} {
    set_volt $val
    Device2::ask $dev_name "OVP1"
  }
  method set_ocp  {val} {
    set_curr $val
    Device2::ask $dev_name "OCP1"
  }
  method get_curr {} { return [Device2::ask $dev_name "IOUT1?"] }
  method get_volt {} { return [Device2::ask $dev_name "VOUT1?"] }

  method cc_reset {} {
    ## set current to actual current, turn output on
    set c [Device2::ask $dev_name "IOUT1?"]
    Device2::ask $dev_name "ISET1:$c"
    Device2::ask $dev_name "BEEP1"; # beep off
    Device2::ask $dev_name "OUT1"
  }

  method cv_reset {} {
    ## set voltage to actual value, turn output on
    set c [Device2::ask $dev_name "VOUT1?"]
    Device2::ask $dev_name "VSET1:$c"
    Device2::ask $dev_name "BEEP1"; # beep off
    Device2::ask $dev_name "OUT1"
  }

  method off {} {
    # turn output off
    Device2::ask $dev_name "OUT0"
  }

  method on {} {
    # turn output on
    Device2::ask $dev_name "OUT1"
  }

  ##
  # Status bits (from documentation):
  #  0 - CH1:      1/0 - voltage/current
  #  1 - CH2:      1/0 - voltage/current ??
  #  2 - Tracking: 1/0 - parallel/series ??
  #  3 - Device:   1/0 - tracking/independent ??
  #  4 - Device:   1/0 - beeping/silent ??
  #  5 - Buttons:  1/0 - locked/unlocked ??
  #  6 - output:   1/0 - enabled/disabled
  #  7 - ? (usually 0)
  #
  # Status bits test on real devices:
  # pst1 TENMA72-2550V2.0
  # pst2 TENMA 72-2535 V2.1
  # pst5 TENMA 72-2540 V2.1
  #
  #                     pst1 pst2 pst5
  # ==================================
  # CC ON      01010000  80  80  80
  # CC OFF     00010000  16  16  16
  # CV ON      01010001  81  81  81
  # CV OFF     00010001  17  17  17
  # CC ON OVP  11010000 208 208 208
  # CC OFF OVP 10010000 144 144 144
  # CV ON OVP  11010001 209 209 209
  # CV OFF OVP 10010001 145 145 145
  # OVP trig   10010001 145 145 145

  method get_stat {} {
    set n [Device2::ask $dev_name "STATUS?"]
    binary scan $n c nv;          # convert char -> 8-bit integer
    set nv [expr { $nv & 0xFF }]; # convert to unsigned
    if {($nv&(1<<6)) == 0} {return "OFF"}
    if {($nv&1) == 1} {return "CV"}
    return "CC"
  }

}

}; # namespace
