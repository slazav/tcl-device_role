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
    set mod [$dev cmd "syst:chan:mod? (@$chan)"]
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
            $dev cmd "curr:rang 1,(@$chan)"
            set min_i 1e-3;
            set min_i_step 1e-4
            set i_prec 1.2e-3; # we can set 0 and be at 0.001
          }
          L {
            $dev cmd "curr:rang 0.09,(@$chan)"
            set min_i 1e-4;
            set min_i_step 2e-6
            set i_prec 1.2e-4
          }
          default { error "$this: unknown range for $mod: $range" }
        }
      }
      default { error "$this: unknown module: $mod"}
    }
    set max_i [$dev cmd "curr:rang? (@$chan)"]
    set max_v [$dev cmd "volt:rang? (@$chan)"]
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
    set data [$dev cmd "dig:inp:data?"]
    if { [get_pin $data 1] } { return }
    # revert polarity and try again:
    set pol [string equal [$dev cmd "dig:pin1:pol?"] "NEG"]
    $dev cmd "dig:pin1:pol [expr $pol?{POS}:{NEG}]"
    set data [$dev cmd "dig:inp:data?"]
    if { [get_pin $data 1] } { return }
    # fail:
    error "Failed to operate polarity switch. Check relay power."
  }

  # Get digital port pin state (n=1..7).
  # Value should be inverted if polarity is negative.
  method get_pin {data n} {
    set pol [string equal [$dev cmd "dig:pin$n:pol?"] "NEG"]
    return [ expr {(($data >> ($n-1)) + $pol)%2} ]
  }
  # Set pin in the data.
  # Value should be inverted if polarity is negative.
  method set_pin {data n v} {
    set pol [string equal [$dev cmd "dig:pin$n:pol?"] "NEG"]
    set v [expr {($v+$pol)%2}]
    set data [expr {1 << ($n-1) | $data}]
    if {$v==0} { set data [expr {$data ^ 1 << ($n-1)}] }
    return $data
  }
  # Get output polarity
  method get_pol {chan sw_pos sw_neg} {
    check_power
    # Read current pin settings (this works only of power is on)
    set data [expr int([$dev cmd "dig:inp:data?"])]
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
    set data [expr int([$dev cmd "dig:inp:data?"])]
    set data1 $data
    set data1 [set_pin $data1 $sw_pos [expr {$pol<=0}]]
    set data1 [set_pin $data1 $sw_neg [expr {$pol>0}]]
    if {$data1 != $data } {$dev cmd "DIG:OUTP:DATA $data1"}
    # Check new state:
    if { $data1 != [$dev cmd "DIG:INP:DATA?"] } {
      error "Failed to operate polarity switch. Wrong pin setting."}
  }

  #################
  method set_volt {val} {
    # No polarity switch or zero current:
    if {($sw_pos == {} || $sw_neg == {}) || $val == 0} {
      $dev cmd "volt $val,(@$chan)"
      return
    }
    # set channel polarity, set current
    set_pol $val $chan $sw_pos $sw_neg
    $dev cmd "volt [expr abs($val)],(@$chan)"
  }

  method set_curr {val} {
    # No polarity switch or zero current:
    if {($sw_pos=={} || $sw_neg=={}) || $val == 0} {
      $dev cmd "curr $val,(@$chan)"
      return
    }
    # set channel polarity, set current
    set_pol $val $chan $sw_pos $sw_neg
    $dev cmd "curr [expr abs($val)],(@$chan)"
  }

  method get_volt {} {
    set val [$dev cmd "meas:volt? (@$chan)"]
    if {$sw_pos!={} && $sw_neg!={}} {
      set val [expr {$val*[get_pol $chan $sw_pos $sw_neg]}] }
    return $val
  }
  method get_curr_abs {} {
    return [$dev cmd "meas:curr? (@$chan)"]
  }
  method get_curr {} {
    set val [get_curr_abs]
    if {$sw_pos!={} && $sw_neg!={}} {
      set val [expr {$val*[get_pol $chan $sw_pos $sw_neg]}] }
    return $val
  }

  method set_ovp  {val} {
    $dev cmd "volt $val,(@$chan)"
    $dev cmd "volt:prot $val,(@$chan)"
  }
  method set_ocp  {val} {
    $dev cmd "curr $val,(@$chan)"
    $dev cmd "curr:prot $val,(@$chan)"
  }

  method cc_reset {} {
    set oc [$dev cmd "stat:oper:cond? (@$chan)"]
    set qc [$dev cmd "stat:ques:cond? (@$chan)"]

    # if device is in CC mode and no error conditions - do nothing
    if {$oc&2 && $qc==0} {return}


    # if OVP is triggered set zero current and clear the OVP
    if {$oc&4 && $qc&1} {
      $dev cmd "curr 0,(@$chan)"
      after 100
      $dev cmd "outp:prot:cle (@$chan)"
      after 100
      return
    }

    # if output is off, set zero current and turn on the output
    if {$oc&4} {
      $dev cmd "curr 0,(@$chan)"
      after 100
      $dev cmd "outp on,(@$chan)"
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
    set n [$dev cmd "stat:ques:cond? (@$chan)"]
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
    set n [$dev cmd "stat:oper:cond? (@$chan)"]
    if {! [string is integer $n] } {return BadOCond}
    if {$n & 1} {return CV}
    if {$n & 2} {return CC}
    if {$n & 4} {return OFF}
    return Unknown
  }

}

######################################################################
# Use Korad/Velleman/Tenma device in a power_suply role.
itcl::class tenma {
  inherit tenma_ps interface
  proc test_id {id} {tenma_ps::test_id $id}
  # we use Device from tenma_ps class
  method get_device {} {return $tenma_ps::dev}

  constructor {d ch id} {tenma_ps::constructor $d $ch $id} {}

  method set_volt {val} { tenma_ps::set_volt $val}
  method set_curr {val} { tenma_ps::set_curr $val}
  method set_ovp  {val} { tenma_ps::set_ovp $val}
  method set_ocp  {val} { tenma_ps::set_ocp $val}
  method get_curr {} { tenma_ps::get_curr}
  method get_volt {} { tenma_ps::get_volt }
  method cc_reset {} { tenma_ps::cc_reset }
  method cv_reset {} { tenma_ps::cv_reset }
  method off {}      { tenma_ps::off }
  method get_stat {} { tenma_ps::get_stat }
}

######################################################################
} # namespace
