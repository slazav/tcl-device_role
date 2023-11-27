######################################################################
# power_supply role

package require Itcl
package require Device2

namespace eval device_role::power_supply {

######################################################################
## Interface class. All power_supply driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}

  # variables which should be filled by driver:
  public variable max_i; # max current
  public variable min_i; # min current
  public variable max_v; # max voltage
  public variable min_v; # min voltage
  public variable min_i_step; # min step in current
  public variable min_v_step; # min step in voltage
  public variable i_prec; # current precision
                          # (how measured value can deviate from set value)

  # methods which should be defined by driver:
  method set_volt {val} {}; # set maximum voltage
  method set_curr {val} {}; # set current
  method set_ovp  {val} {}; # set/unset overvoltage protaction
  method set_ocp  {val} {}; # set/unset overcurrent protection
  method get_curr {} {};    # measure actual value of voltage
  method get_volt {} {};    # measure actual value of current

  ## cc_reset -- bring the device into a controlled state in a constant current mode.
  # If device in constant current mode it should do nothing.
  # If OVP is triggered, then set current to actial current value,
  # reset the OVP condition and and turn the output on.
  # This function should not do any current jumps.
  method cc_reset {} {}

  # same for CV mode
  method cv_reset {} {}

  # turn output off
  method off {} {}

  # get_stat -- get device status (short string to be shown in the interface).
  # Can have different values, depending on the device:
  #  CV  - constant voltage mode
  #  CC  - constant current mode
  #  OFF - turned off
  #  OV  - overvoltage protection triggered
  #  OC  - overcurent protection triggered
  # ...
  method get_stat {} {};
}

######################################################################
# Test power supply
# No channels are supported

itcl::class TEST {
  inherit interface
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
  method lock {} {}
  method unlock {} {}

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

######################################################################
# Use Keysight N6700B device in a power_suply role.
# ID string:
#  Agilent Technologies,N6700B,MY54010313,D.04.07
#  Keysight Technologies,N6700C,MY56003645,E.02.03.3189
#
# Supported modules:
#  * N6731B
#  * N6761A
#  * N6762A
# Use channels 1..4
# For module N6762A use specify also range, L or H
# For polarity switch (see elsewhere) add :P<N><M> suffix
#  (pin N should switch to positive polarity, M to negative)
#
# Example:
#  ps0:1H -- use device ps0, 1st channel (N6762A module in high range)
#  ps0:2L -- use device ps0, 2nd channel (N6762A module in low range)
#  ps0:3  -- use device ps0, 3rd channel (N6731B module)
#  ps0:4:P67 -- use device ps0, 3rd channel with polarity switch (N6731B module)

itcl::class keysight_n6700b {
  inherit interface
  proc test_id {id} {
    if {[regexp {,N6700B,} $id]} {return 1}
    if {[regexp {,N6700C,} $id]} {return 1}
  }

  variable chan;  # channel to use (1..4)
  variable range; # range to use (H/L)
  variable sw_pos; # positive and negative pins of the polarity
  variable sw_neg; #   switch: 2..7 or 0 if no polarity switch used
                   #   pin 1 used for voltage check

  constructor {d ch id} {
    set dev $d
    # parse channel name, range (H/L) and polarity pins (:P45):
    if {![regexp {([0-4])([HL]?)(:P([2-7])([2-7]))?} $ch x chan range p0 sw_pos sw_neg]} {
      error "$this: bad channel setting: $ch"}

    # sw_pos = sw_neg = 0 -- no polarity switch
    if {$sw_pos != {} && $sw_pos == $sw_neg} {
       error "same setting for positive and negative pin of polarity switch"
    }

    # detect module type:
    set mod [Device2::ask $dev "syst:chan:mod? (@$chan)"]
    switch -glob -- $mod {
      N6731B {
        set min_i 0.06
        set min_i_step 1e-2
        set i_prec 0.7; # we can set 0 and be at 0.06
      }
      N676[12]A {
        # modules has two current ranges: 0.1 and 1.5 or 3A
        switch -- $range {
          H {
            Device2::ask $dev "curr:rang 1,(@$chan)"
            set min_i 1e-3;
            set min_i_step 1e-4
            set i_prec 1.2e-3; # we can set 0 and be at 0.001
          }
          L {
            Device2::ask $dev "curr:rang 0.09,(@$chan)"
            set min_i 1e-4;
            set min_i_step 2e-6
            set i_prec 1.2e-4
          }
          default { error "$this: unknown range for $mod: $range" }
        }
      }
      default { error "$this: unknown module: $mod"}
    }
    set max_i [Device2::ask $dev "curr:rang? (@$chan)"]
    set max_v [Device2::ask $dev "volt:rang? (@$chan)"]
    set min_v 0
    # if polarity switch is used, we can go to -max_i, -max_v
    if {$sw_pos!={} && $sw_neg!={}} {
      set min_i [expr {-$max_i}]
      set min_v [expr {-$max_v}]
    }
  }

  #################
  ## methods for polarity switch

  # check relay power
  method check_power {} {
    # pin1 should be 1 with NEG or POS polarity
    # depending on the pin state (which we do not know)
    set data [Device2::ask $dev "dig:inp:data?"]
    if { [get_pin $data 1] } { return }
    # revert polarity and try again:
    set pol [string equal [Device2::ask $dev "dig:pin1:pol?"] "NEG"]
    Device2::ask $dev "dig:pin1:pol [expr $pol?{POS}:{NEG}]"
    set data [Device2::ask $dev "dig:inp:data?"]
    if { [get_pin $data 1] } { return }
    # fail:
    error "Failed to operate polarity switch. Check relay power."
  }

  # Get digital port pin state (n=1..7).
  # Value should be inverted if polarity is negative.
  method get_pin {data n} {
    set pol [string equal [Device2::ask $dev "dig:pin$n:pol?"] "NEG"]
    return [ expr {(($data >> ($n-1)) + $pol)%2} ]
  }
  # Set pin in the data.
  # Value should be inverted if polarity is negative.
  method set_pin {data n v} {
    set pol [string equal [Device2::ask $dev "dig:pin$n:pol?"] "NEG"]
    set v [expr {($v+$pol)%2}]
    set data [expr {1 << ($n-1) | $data}]
    if {$v==0} { set data [expr {$data ^ 1 << ($n-1)}] }
    return $data
  }
  # Get output polarity
  method get_pol {chan sw_pos sw_neg} {
    check_power
    # Read current pin settings (this works only of power is on)
    set data [expr int([Device2::ask $dev "dig:inp:data?"])]
    set d1 [get_pin $data $sw_pos]
    set d2 [get_pin $data $sw_neg]
    if {$d1 == 0 && $d2 == 1} { return +1 }
    if {$d1 == 1 && $d2 == 0} { return -1 }
    # wrong ping setting, we do not know what is relay position now
    # if current is zero we can cwitch pins to some good state:
    if { [get_curr_abs]-$min_i < $i_prec} {
      set_pol +1 $chan $sw_pos $sw_neg
      return +1
    }
    error "Wrong pin settings: check polarities and values of digital pins"
  }
  # Set output polarity
  method set_pol {pol chan sw_pos sw_neg} {
    check_power
    # Set pins if needed
    set data [expr int([Device2::ask $dev "dig:inp:data?"])]
    set data1 $data
    set data1 [set_pin $data1 $sw_pos [expr {$pol<=0}]]
    set data1 [set_pin $data1 $sw_neg [expr {$pol>0}]]
    if {$data1 != $data } {Device2::ask $dev "DIG:OUTP:DATA $data1"}
    # Check new state:
    if { $data1 != [Device2::ask $dev "DIG:INP:DATA?"] } {
      error "Failed to operate polarity switch. Wrong pin setting."}
  }

  #################
  method set_volt {val} {
    # No polarity switch or zero current:
    if {($sw_pos == {} || $sw_neg == {}) || $val == 0} {
      Device2::ask $dev "volt $val,(@$chan)"
      return
    }
    # set channel polarity, set current
    set_pol $val $chan $sw_pos $sw_neg
    Device2::ask $dev "volt [expr abs($val)],(@$chan)"
  }

  method set_curr {val} {
    # No polarity switch or zero current:
    if {($sw_pos=={} || $sw_neg=={}) || $val == 0} {
      Device2::ask $dev "curr $val,(@$chan)"
      return
    }
    # set channel polarity, set current
    set_pol $val $chan $sw_pos $sw_neg
    Device2::ask $dev "curr [expr abs($val)],(@$chan)"
  }

  method get_volt {} {
    set val [Device2::ask $dev "meas:volt? (@$chan)"]
    if {$sw_pos!={} && $sw_neg!={}} {
      set val [expr {$val*[get_pol $chan $sw_pos $sw_neg]}] }
    return $val
  }
  method get_curr_abs {} {
    return [Device2::ask $dev "meas:curr? (@$chan)"]
  }
  method get_curr {} {
    set val [get_curr_abs]
    if {$sw_pos!={} && $sw_neg!={}} {
      set val [expr {$val*[get_pol $chan $sw_pos $sw_neg]}] }
    return $val
  }

  method set_ovp  {val} {
    Device2::ask $dev "volt $val,(@$chan)"
    Device2::ask $dev "volt:prot $val,(@$chan)"
  }
  method set_ocp  {val} {
    Device2::ask $dev "curr $val,(@$chan)"
    Device2::ask $dev "curr:prot $val,(@$chan)"
  }

  method cc_reset {} {
    set oc [Device2::ask $dev "stat:oper:cond? (@$chan)"]
    set qc [Device2::ask $dev "stat:ques:cond? (@$chan)"]

    # if device is in CC mode and no error conditions - do nothing
    if {$oc&2 && $qc==0} {return}


    # if OVP is triggered set zero current and clear the OVP
    if {$oc&4 && $qc&1} {
      Device2::ask $dev "curr 0,(@$chan)"
      after 100
      Device2::ask $dev "outp:prot:cle (@$chan)"
      after 100
      return
    }

    # if output is off, set zero current and turn on the output
    if {$oc&4} {
      Device2::ask $dev "curr 0,(@$chan)"
      after 100
      Device2::ask $dev "outp on,(@$chan)"
      after 100
      return
    }

    error "device is in strange state: [get_stat] ($oc:$qc)"
  }

  # fixme
  method cv_reset {} {
    puts stderr "FIXME: cv_reset method is not supported for this DeviceRole driver"
  }

  method off {} {
    puts stderr "FIXME: off method is not supported for this DeviceRole driver"
  }

  method get_stat {} {
    # error states
    set n [Device2::ask $dev "stat:ques:cond? (@$chan)"]
    if {! [string is integer $n] } {return BadQCond}
    if {$n & 1} {return OV}
    if {$n & 2} {return OC}
    if {$n & 4} {return PF}
    if {$n & 8} {return CP+}
    if {$n & 16} {return OT}
    if {$n & 32} {return CP-}
    if {$n & 64} {return OV-}
    if {$n & 128} {return LIM+}
    if {$n & 256} {return LIM-}
    if {$n & 512} {return INH}
    if {$n & 1024} {return UNR}
    if {$n & 2048} {return PROT}
    if {$n & 4096} {return OSC}
    set n [Device2::ask $dev "stat:oper:cond? (@$chan)"]
    if {! [string is integer $n] } {return BadOCond}
    if {$n & 1} {return CV}
    if {$n & 2} {return CC}
    if {$n & 4} {return OFF}
    return Unknown
  }

}

######################################################################
## Korad/Velleman/Tenma power supplies

# See:
# https://sigrok.org/wiki/Korad_KAxxxxP_series
# https://sigrok.org/gitweb/?p=libsigrok.git (src/hardware /korad-kaxxxxp/)
#
# There are many devices with different id strings and limits
#   KORADKA6003PV2.0    tenma 2550 60V 3A
#   TENMA72-2540V2.0    tenma 2540 30V 5A
#   TENMA 72-2540 V2.1  tenma 2540 30V 5A
# No channels are supported

itcl::class tenma {
  inherit interface
  protected variable dev;
  protected variable model;
  public variable min_i;
  public variable min_v;
  public variable max_i;
  public variable max_v;
  public variable min_i_step 0.001;
  public variable min_v_step 0.01;
  public variable i_prec 0.01;

  # redefine lock/unlock methods with our dev
  method lock {} {Device2::lock $dev}
  method unlock {} {Device2::unlock $dev}

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

  constructor {d ch id} {
    if {$ch!={}} {error "channels are not supported for the device $d"}
    set model [test_id $id]
    switch -exact -- $model {
      72-2550 { set max_i 3.09; set max_v 60.0 }
      72-2540 { set max_i 5.09; set max_v 31.0 }
      72-2535 { set max_i 3.09; set max_v 31.0 }
      default { error "tenma_ps: unknown model: $model" }
    }
    set dev $d
    set min_i 0.0
    set min_v 0.0
    set min_i_step 0.001
    set min_v_step 0.01
    set i_prec 0.02
  }

  method set_volt {val} {
    set val [expr {round($val*100)/100.0}]
    Device2::ask $dev "VSET1:$val"
  }
  method set_curr {val} {
    set val [expr {round($val*1000)/1000.0}]
    Device2::ask $dev "ISET1:$val"
  }
  method set_ovp  {val} {
    set_volt $val
    Device2::ask $dev "OVP1"
  }
  method set_ocp  {val} {
    set_curr $val
    Device2::ask $dev "OCP1"
  }
  method get_curr {} { return [Device2::ask $dev "IOUT1?"] }
  method get_volt {} { return [Device2::ask $dev "VOUT1?"] }

  method cc_reset {} {
    ## set current to actual current, turn output on
    set c [Device2::ask $dev "IOUT1?"]
    Device2::ask $dev "ISET1:$c"
    Device2::ask $dev "BEEP1"; # beep off
    Device2::ask $dev "OUT1"
  }

  method cv_reset {} {
    ## set voltage to actual value, turn output on
    set c [Device2::ask $dev "VOUT1?"]
    Device2::ask $dev "VSET1:$c"
    Device2::ask $dev "BEEP1"; # beep off
    Device2::ask $dev "OUT1"
  }

  method off {} {
    # turn output off
    Device2::ask $dev "OUT0"
  }

  method on {} {
    # turn output on
    Device2::ask $dev "OUT1"
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
    set n [Device2::ask $dev "STATUS?"]
    binary scan $n c nv;          # convert char -> 8-bit integer
    set nv [expr { $nv & 0xFF }]; # convert to unsigned
    if {($nv&(1<<6)) == 0} {return "OFF"}
    if {($nv&1) == 1} {return "CV"}
    return "CC"
  }

}

######################################################################
## Siglent SPD 1168X/1305X/3303C power supplies

# ID strings:
#   Siglent Technologies,SPD1168X,SPD13DCC6R0348,2.1.1.9,V1.0
#   Siglent Technologies,SPD3303C,SPD3EEDC6R0113,1.02.01.01.03R9,V1.3
#
# SPD1168X - 1channel, LAN/USB, 16V/8A
# SPD1305X - 1channel, LAN/USB, 30V/5A, not tested
# SPD3303C - 3channels, USB only, 32V/3.2A, 32V/3.2A, fixed
#
itcl::class siglent {
  inherit interface
  # redefine lock/unlock methods with our dev
  method lock {} {Device2:lock $dev}
  method unlock {} {Device2::unlock $dev}

  proc test_id {id} {
    if {[regexp {,SPD1168X,} $id]} {return {SPD1168X}}
    if {[regexp {,SPD1305X,} $id]} {return {SPD1305X}}
    if {[regexp {,SPD3303C,} $id]} {return {SPD3303C}}
  }

  protected variable dev;
  protected variable chan;
  protected variable model;

  public variable min_i;
  public variable min_v;
  public variable max_i;
  public variable max_v;
  public variable min_i_step;
  public variable min_v_step;
  public variable i_prec 0.02;

  constructor {d ch id} {
    set dev $d
    set model [test_id $id]
    set min_i 0
    set min_v 0
    set chan 1
    if {$model eq {SPD1168X}} {
      set max_i 8
      set max_v 16
      set min_v_step 0.001
      set min_i_step 0.001
      if {$ch ne {}} {
        error "$this: bad channel setting: $ch"
        return
      }
    }\
    elseif {$model eq {SPD1305X}} {
      set max_i 5
      set max_v 30
      set min_v_step 0.001
      set min_i_step 0.001
      if {$ch ne {}} {
        error "$this: bad channel setting: $ch"
        return
      }
    }\
    elseif {$model eq {SPD3303C}} {
      set max_i 3.2
      set max_v 32
      set min_v_step 0.01
      set min_i_step 0.01
      if {$ch !=1 && $ch!=2} {
        error "$this: bad channel setting: $ch"
        return
      }
      set chan $ch
    }\
    else {error "Unknown model: $model"}

  }

  method set_volt {val} { Device2::ask $dev "CH$chan:VOLT $val" }
  method set_curr {val} { Device2::ask $dev "CH$chan:CURR $val" }
  method get_volt {} { Device2::ask $dev "MEAS:VOLT? CH$chan" }
  method get_curr {} { Device2::ask $dev "MEAS:CURR? CH$chan" }
  method on  {} { Device2::ask $dev "OUTP CH$chan,ON" }
  method off {} { Device2::ask $dev "OUTP CH$chan,OFF" }

  ## Set current to actual current, turn output on.
  ## For Siglent devices switching from V0-OFF to 0-ON
  ## will produce peak to V0 and then to zero.
  ## 1s delay is added to avoid this effect
  method cc_reset {} {
    set_curr [get_curr]
    after 1000
    on
  }

  ## set voltage to actual value, turn output on
  method cv_reset {} {
    set_volt [get_volt]
    after 1000
    on
  }

  ##
  # Status bits (from documentation):
  # SDG1000X
  # 0    0: CV mode           1: CC mode
  # 4    0: Output OFF        1: Output ON
  # 5    0: 2W mode           1: 4W mode
  # 6    0: TIMER OFF         1: TIMER ON
  # 8    0: digital display;  1: waveform display
  #
  # SDG3303X
  # 0    0: CH1 CV mode       1: CH1 CC mode
  # 1    0: CH2 CV mode       1: CH2 CC mode
  # 2,3  01: Independent mode
  #      10: Parallel mode
  #      11: Series mode
  # 4    0: CH1 OFF      1: CH1 ON
  # 5    0: CH2 OFF      1: CH2 ON
  method get_stat {} {
    # status bits
    set ccbit [expr $chan-1]
    set onbit [expr $chan+3]
    # get status from the device
    set n [Device2::ask $dev "SYST:STAT?"]
    scan $n 0x%x n;  # hex->num
    set n [expr { $n & 0xFFFF }]; # convert to unsigned
    if {($n&(1<<$onbit)) == 0} {return "OFF"}
    if {($n&(1<<$ccbit)) == 0} {return "CV"}
    return "CC"
  }
}

######################################################################
} # namespace
