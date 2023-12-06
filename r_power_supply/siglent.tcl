######################################################################
# Siglent SPD 1168X/1305X/3303C power supplies

# ID strings:
#   Siglent Technologies,SPD1168X,SPD13DCC6R0348,2.1.1.9,V1.0
#   Siglent Technologies,SPD3303C,SPD3EEDC6R0113,1.02.01.01.03R9,V1.3
#
# SPD1168X - 1channel, LAN/USB, 16V/8A
# SPD1305X - 1channel, LAN/USB, 30V/5A, not tested
# SPD3303C - 3channels, USB only, 32V/3.2A, 32V/3.2A, fixed
#

package require Itcl
package require Device2
namespace eval device_role::power_supply {

itcl::class siglent {
  inherit base

  proc test_id {id} {
    if {[regexp {,SPD1168X,} $id]} {return {SPD1168X}}
    if {[regexp {,SPD1305X,} $id]} {return {SPD1305X}}
    if {[regexp {,SPD3303C,} $id]} {return {SPD3303C}}
  }

  public variable min_i;
  public variable min_v;
  public variable max_i;
  public variable max_v;
  public variable min_i_step;
  public variable min_v_step;
  public variable i_prec 0.02;

  constructor {args} {
    chain {*}$args
    set min_i 0
    set min_v 0
    if {$dev_model eq {SPD1168X}} {
      set max_i 8
      set max_v 16
      set min_v_step 0.001
      set min_i_step 0.001
      if {$dev_chan ne {}} {
        error "$this: bad channel setting: $dev_chan"
        return
      }
      set chan 1
    }\
    elseif {$dev_model eq {SPD1305X}} {
      set max_i 5
      set max_v 30
      set min_v_step 0.001
      set min_i_step 0.001
      if {$dev_chan ne {}} {
        error "$this: bad channel setting: $dev_chan"
        return
      }
      set chan 1
    }\
    elseif {$dev_model eq {SPD3303C}} {
      set max_i 3.2
      set max_v 32
      set min_v_step 0.01
      set min_i_step 0.01
      if {$dev_chan !=1 && $dev_chan!=2} {
        error "$this: bad channel setting: $dev_chan"
        return
      }
    }\
    else {error "Unknown model: $dev_model"}

  }

  method set_volt {val} { Device2::ask $dev_name "CH$dev_chan:VOLT $val" }
  method set_curr {val} { Device2::ask $dev_name "CH$dev_chan:CURR $val" }
  method get_volt {} { Device2::ask $dev_name "MEAS:VOLT? CH$dev_chan" }
  method get_curr {} { Device2::ask $dev_name "MEAS:CURR? CH$dev_chan" }
  method on  {} { Device2::ask $dev_name "OUTP CH$dev_chan,ON" }
  method off {} { Device2::ask $dev_name "OUTP CH$dev_chan,OFF" }

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
    set ccbit [expr $dev_chan-1]
    set onbit [expr $dev_chan+3]
    # get status from the device
    set n [Device2::ask $dev_name "SYST:STAT?"]
    scan $n 0x%x n;  # hex->num
    set n [expr { $n & 0xFFFF }]; # convert to unsigned
    if {($n&(1<<$onbit)) == 0} {return "OFF"}
    if {($n&(1<<$ccbit)) == 0} {return "CV"}
    return "CC"
  }
}

}; # namespace
