######################################################################
# Keysight N6700B power supply frame
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

package require Itcl
package require Device2
namespace eval device_role::power_supply {

itcl::class keysight_n6700b {
  inherit base
  proc test_id {id} {
    if {[regexp {,N6700B,} $id]} {return 1}
    if {[regexp {,N6700C,} $id]} {return 1}
  }

  variable range; # range to use (H/L)
  variable sw_pos; # positive and negative pins of the polarity
  variable sw_neg; #   switch: 2..7 or 0 if no polarity switch used
                   #   pin 1 used for voltage check

  constructor {args} {
    chain {*}$args
    # parse channel name, range (H/L) and polarity pins (:P45):
    if {![regexp {([0-4])([HL]?)(:P([2-7])([2-7]))?} $chan x chan range p0 sw_pos sw_neg]} {
      error "$this: bad channel setting: $chan"}

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

}; # namespace
