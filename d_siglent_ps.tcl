## Common functions for Siglent power supplies
## In inherit statement this class should go before interface class
## to override dev, min_*,max_* variables

# ID strings:
#   Siglent Technologies,SPD1168X,SPD13DCC6R0348,2.1.1.9,V1.0
#   Siglent Technologies,SPD3303C,SPD3EEDC6R0113,1.02.01.01.03R9,V1.3
#
# SPD1168X - 1channel, LAN/USB, 16V/8A
# SPD1305X - 1channel, LAN/USB, 30V/5A, not tested
# SPD3303C - 3channels, USB only, 32V/3.2A, 32V/3.2A, fixed
#
itcl::class siglent_ps {
  # redefine lock/unlock methods with our dev
  method lock {} {$dev lock}
  method unlock {} {$dev unlock}

  proc test_id {id} {
    if {[regexp {,SPD1168X,} $id]} {return {SPD1168X}}
    if {[regexp {,SPD1305X,} $id]} {return {SPD1305X}}
    if {[regexp {,SPD3303C,} $id]} {return {SPD3303C}}
    error "Unknown id: $id"
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
  public variable i_prec 0.01;

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
    }\
    else {error "Unknown model: $model"}

  }

  method set_volt {val} { $dev cmd "CH$chan:VOLT $val" }
  method set_curr {val} { $dev cmd "CH$chan:CURR $val" }
  method get_volt {} { $dev cmd "MEAS:VOLT? CH$chan" }
  method get_curr {} { $dev cmd "MEAS:CURR? CH$chan" }
  method on  {} { $dev cmd "OUTP CH$chan,ON" }
  method off {} { $dev cmd "OUTP CH$chan,OFF" }

  ## set current to actual current, turn output on
  method cc_reset {} {
    set_curr [get_curr]
    on
  }

  ## set voltage to actual value, turn output on
  method cv_reset {} {
    set_volt [get_volt]
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
    set n [$dev cmd "SYST:STAT?"]
    scan $n 0x%x n;  # hex->num
    set n [expr { $n & 0xFFFF }]; # convert to unsigned
    if {($n&(1<<$onbit)) == 0} {return "OFF"}
    if {($n&(1<<$ccbit)) == 0} {return "CV"}
    return "CC"
  }
}
