######################################################################
# gauge role

package require Itcl
package require Device2

namespace eval device_role::gauge {

######################################################################
## Interface class. All gauge driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}


  ##################
  # variables to be set in the driver:
  variable valnames; # Names of returned values (list)

  # Number of values returned by get command
  method get_val_num {} {
    return [llength valnames]
  }

  # Return text name of the n-th value
  # For lockin it can be X or Y,
  # For multi-channel ADC it could be CH1, CH2, etc.
  method get_val_name {n} {
    if {$n<0 || $n>=[llength valnames]} {
      error "get_val_name: value number $n is out of range 0..[llength valnames]"}
    return [lindex $valnames $n]
  }


  ##################
  # methods which should be defined by driver:
  method get {} {}; # do the measurement, return one or more numbers

  method get_auto {} {}; # set the range automatically, do the measurement

  method list_ranges  {} {}; # get list of possible range settings
  method list_tconsts {} {}; # get list of possible time constant settings

  method set_range  {val} {}; # set the range
  method set_tconst {val} {}; # set the time constant
  method get_range  {} {}; # get current range setting
  method get_tconst {} {}; # get current time constant setting

  method get_status {} {return ""}; # get current status
  method get_status_raw {} {return 0};
}

######################################################################
# Virtual multimeter
itcl::class TEST {
  inherit interface
  proc test_id {id} {}

  variable chan;  # channel to use (R1, R2,... T1, T2,...)
  variable type;  # R - random, T - 10s time sweep
  variable n;     # number of values 0..maxn
  variable maxn 10;
  variable tsweep 10;

  constructor {d ch id} {
    set chan $ch
    set type R
    set n    1
    if {$ch == {}} {
    }
    if {$ch!={} && ![regexp {^(T|R)([0-9]+$)} $chan v type n]} {
      error "Unknown channel setting: $ch"
    }
    if {$n<1 || $n>$maxn} {
      error "Bad number in the cannel setting: $ch"
    }
    for {set i 0} {$i<$n} {incr i} {lappend valnames $i}
  }
  destructor {}

  ############################
  method get {} {
    set data {}
    for {set i 0} {$i<$n} {incr i} {
      set v 0
      if {$type=={R}} { set v [expr rand()] }
      if {$type=={T}} { set v [expr {[clock milliseconds]%($tsweep*1000)}] }
      lappend data $v
    }
    return $data
  }
  method get_auto {} {
    return [get]
  }
  method list_ranges  {} {return [list 1.0 2.0 3.0]}
  method list_tconsts {} {return [list 0.1 0.2 0.3]}
  method get_range  {} {return 1.0}
  method get_tconst {} {return 0.1}
  method set_range  {v} {}
  method set_tconst {v} {}
  method get_status {} {return TEST}
}

######################################################################
# Use Keysight/Agilent/HP multimeters 34401A, 34410A, 34461A as a gauge device.
# Also works with Keyley 2000 multimeter
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

itcl::class keysight {
  inherit interface

  # measurement function (volt:dc etc.), set in the constructor
  variable func

  proc test_id {id} {
    if {[regexp {,34461A,} $id]} {return {34461A}}
    if {[regexp {,34401A,} $id]} {return {34401A}}
    if {[regexp {,34410A,} $id]} {return {34410A}}
    if {[regexp {KEITHLEY.*MODEL.2000} $id]} {return {Keythley2000}}
    return {}
  }

  constructor {d ch id} {
    switch -exact -- $ch {
      DCV {  set func volt:dc }
      ACV {  set func volt:ac }
      DCI {  set func curr:dc }
      ACI {  set func curr:ac }
      R2  {  set func res     }
      R4  {  set func fres    }
      default {
        error "$this: bad channel setting: $ch"
        return
      }
    }
    set dev $d
    set valnames $ch
    dev_err_clear $dev
    Device2::ask $dev "meas:$func?"
    dev_err_check $dev
  }

  ############################
  method get {} {
    return [Device2::ask $dev "read?"]
  }
  method get_auto {} {
    return [get]
  }

}

######################################################################
# Use Keithley nanovoltmeter 2182A as a gauge device.
#
# ID strings:
# KEITHLEY INSTRUMENTS INC.,MODEL 2182A,1193143,C02 /A02
# Use channels DCV1 DCV2
#
# Tested:
#   2020/10/13, Keythley-2182A,   V.Z.

itcl::class keithley_nanov {
  inherit interface
  proc test_id {id} {
    if {[regexp {2182A,} $id]} {return {2182A}}
    return {}
  }

  constructor {d ch id} {
    switch -exact -- $ch {
      DCV1 { set chan 1 }
      DCV2 { set chan 2 }
      default { error "$this: bad channel setting: $ch" }
    }
    set dev $d
    dev_check $dev "conf:volt:DC"
    dev_check $dev "sens:chan $chan"
    dev_check $dev "sens:volt:rang:auto 1"
    dev_check $dev "samp:count 1"
  }

  ############################
  method get {} {
    return [Device2::ask $dev "read?"]
  }
  method get_auto {} {
    return [get]
  }


}

######################################################################
# Use Keysight/Agilent/HP multiplexer 34972A as a gauge device.
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

itcl::class keysight_mplex {
  inherit interface
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


######################################################################
# Use Lockin SR844 as a gauge.
#
# ID string:
#   Stanford_Research_Systems,SR844,s/n50066,ver1.006
#
# Use channels 1 or 2 to measure voltage from auxilary inputs,
# channels XY RT FXY FRT to measure lockin X Y R Theta values

itcl::class sr844 {
  inherit interface
  proc test_id {id} {
    if {[regexp {,SR844,} $id]} {return 1}
    return {}
  }

  variable chan;  # channel to use (1..2)

  # lock-in ranges and time constants
  common ranges  {1e-7 3e-7 1e-6 3e-6 1e-5 3e-5 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0}
  common tconsts {1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0 3.0 10.0 30.0 1e2 3e3 1e3 3e3 1e4 3e4}

  common aux_range 10;    # auxilary input range: +/- 10V
  common aux_tconst 3e-4; # auxilary input bandwidth: 3kHz

  constructor {d ch id} {
    switch -exact -- $ch {
      1   {set valnames {AUX1}}
      2   {set valnames {AUX2}}
      XY  {set valnames [list X Y]}
      RT  {set valnames [list R T]}
      FXY {set valnames [list F X Y]}
      FRT {set valnames [list F R T]}
      default {error "$this: bad channel setting: $ch"}
    }
    set chan $ch
    set dev $d
    get_status_raw
  }

  ############################
  method get {{auto 0}} {
    # If channel is 1 or 2 read auxilary input:
    if {$chan==1 || $chan==2} { return [Device2::ask $dev "AUXO?${chan}"] }

    # If autorange is needed, use AGAN command:
    if {$auto} {Device2::ask $dev "AGAN"; after 100}

    # Return space-separated values depending on channel setting
    if {$chan=="XY"} { return [string map {"," " "} [Device2::ask $dev SNAP?1,2]] }
    if {$chan=="RT"} { return [string map {"," " "} [Device2::ask $dev SNAP?3,5]] }
    if {$chan=="FXY"} { return [string map {"," " "} [Device2::ask $dev SNAP?8,1,2]] }
    if {$chan=="FRT"} { return [string map {"," " "} [Device2::ask $dev SNAP?8,3,5]] }
  }
  method get_auto {} { return [get 1] }

  ############################
  method list_ranges {} {
    if {$chan==1 || $chan==2} {return $aux_range}
    return $ranges
  }
  method list_tconsts {} {
    if {$chan==1 || $chan==2} {return $aux_tconst}
    return $tconsts
  }

  ############################
  method set_range  {val} {
    if {$chan==1 || $chan==2} { error "can't set range for auxilar input $chan" }
    set n [lsearch -real -exact $ranges $val]
    if {$n<0} {error "unknown range setting: $val"}
    Device2::ask $dev "SENS $n"
  }
  method set_tconst {val} {
    if {$chan==1 || $chan==2} { error "can't set time constant for auxilar input $chan" }
    set n [lsearch -real -exact $tconsts $val]
    if {$n<0} {error "unknown time constant setting: $val"}
    Device2::ask $dev "OFLT $n"
  }

  ############################
  method get_range  {} {
    if {$chan==1 || $chan==2} { return $aux_range}
    set n [Device2::ask $dev "SENS?"]
    return [lindex $ranges $n]
  }
  method get_tconst {} {
    if {$chan==1 || $chan==2} { return $aux_tconst}
    set n [Device2::ask $dev "OFLT?"]
    return [lindex $tconsts $n]
  }

  method get_status_raw {} {
    return [Device2::ask $dev "LIAS?"]
  }

  method get_status {} {
    set s [Device2::ask $dev "LIAS?"]
    set res {}
    if {$s & (1<<0)} {lappend res "UNLOCK"}
    if {$s & (1<<7)} {lappend res "FRE_CH"}
    if {$s & (1<<1)} {lappend res "FREQ_OVR"}
    if {$s & (1<<4)} {lappend res "INP_OVR"}
    if {$s & (1<<5)} {lappend res "AMP_OVR"}
    if {$s & (1<<6)} {lappend res "FLT_OVR"}
    if {$s & (1<<8)} {lappend res "CH1_OVR"}
    if {$s & (1<<9)} {lappend res "CH2_OVR"}
    if {$res == {}} {lappend res "OK"}
    return [join $res " "]
  }

}

######################################################################
# Use Lockin SR830 as a gauge.
#
# ID string:
#   Stanford_Research_Systems,SR830,s/n46117,ver1.07
#
# Use channels 1 or 2 to measure voltage from auxilary inputs,
# channels XY RT FXY FRT to measure lockin X Y R Theta values
#
# Tested:
#   2020/10/05, SR830,   V.Z.
#

itcl::class sr830 {
  inherit interface
  proc test_id {id} {
    if {[regexp {,SR830,} $id]} {return 1}
    return {}
  }

  variable chan;  # channel to use (1..2)

  # lock-in ranges and time constants
  common ranges
  common ranges_V  {2e-9 5e-9 1e-8 2e-8 5e-8 1e-7 2e-7 5e-7 1e-6 2e-6 5e-6 1e-5 2e-5 5e-5 1e-4 2e-4 5e-4 1e-3 2e-3 5e-3 1e-2 2e-2 5e-2 0.1 0.2 0.5 1.0}
  common ranges_A  {2e-15 5e-15 1e-14 2e-14 5e-14 1e-13 2e-13 5e-13 1e-12 2e-12 5e-12 1e-11 2e-11 5e-11 1e-10 2e-10 5e-10 1e-9 2e-9 5e-9 1e-8 2e-8 5e-8 1e-7 2e-7 5e-7 1e-6}
  common tconsts   {1e-5 3e-5 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0 3.0 10.0 30.0 1e2 3e3 1e3 3e3 1e4 3e4}

  common aux_range 10;    # auxilary input range: +/- 10V
  common aux_tconst 3e-4; # auxilary input bandwidth: 3kHz

  common isrc;            # input 0-3 A/A-B/I_1MOhm/I_100MOhm

  constructor {d ch id} {
    switch -exact -- $ch {
      1   {set valnames {AUX1}}
      2   {set valnames {AUX2}}
      XY  {set valnames [list X Y]}
      RT  {set valnames [list R T]}
      FXY {set valnames [list F X Y]}
      FRT {set valnames [list F R T]}
      default {error "$this: bad channel setting: $ch"}
    }
    set chan $ch
    set dev $d
  }

  ############################
  method get {{auto 0}} {
    # If channel is 1 or 2 read auxilary input:
    if {$chan==1 || $chan==2} { return [Device2::ask $dev "OAUX?${chan}"] }

    # If autorange is needed, use AGAN command:
    if {$auto} {Device2::ask $dev "AGAN"; after 100}

    # Return space-separated values depending on channel setting
    if {$chan=="XY"} { return [string map {"," " "} [Device2::ask $dev SNAP?1,2]] }
    if {$chan=="RT"} { return [string map {"," " "} [Device2::ask $dev SNAP?3,4]] }
    if {$chan=="FXY"} { return [string map {"," " "} [Device2::ask $dev SNAP?9,1,2]] }
    if {$chan=="FRT"} { return [string map {"," " "} [Device2::ask $dev SNAP?9,3,4]] }
  }
  method get_auto {} { return [get 1] }

  ############################
  method list_ranges {} {
    if {$chan==1 || $chan==2} {return $aux_range}
    set isrc [Device2::ask $dev "ISRC?"]
    if {$isrc == 0 || $isrc == 1} { set ranges $ranges_V } { set ranges $ranges_A }
    return $ranges
  }
  method list_tconsts {} {
    if {$chan==1 || $chan==2} {return $aux_tconst}
    return $tconsts
  }

  ############################
  method set_range  {val} {
    if {$chan==1 || $chan==2} { error "can't set range for auxilar input $chan" }
    set n [lsearch -real -exact $ranges $val]
    if {$n<0} {error "unknown range setting: $val"}
    Device2::ask $dev "SENS $n"
  }
  method set_tconst {val} {
    if {$chan==1 || $chan==2} { error "can't set time constant for auxilar input $chan" }
    set n [lsearch -real -exact $tconsts $val]
    if {$n<0} {error "unknown time constant setting: $val"}
    Device2::ask $dev "OFLT $n"
  }

  ############################
  method get_range  {} {
    if {$chan==1 || $chan==2} { return $aux_range}
    set isrc [Device2::ask $dev "ISRC?"]
    if {$isrc == 0 || $isrc == 1} { set ranges $ranges_V } { set ranges $ranges_A }
    set n [Device2::ask $dev "SENS?"]
    return [lindex $ranges $n]
  }
  method get_tconst {} {
    if {$chan==1 || $chan==2} { return $aux_tconst}
    set n [Device2::ask $dev "OFLT?"]
    return [lindex $tconsts $n]
  }

  method get_status_raw {} {
    return [Device2::ask $dev "LIAS?"]
  }

  method get_status {} {
    set s [Device2::ask $dev "LIAS?"]
    set res {}
    if {$s & (1<<0)} {lappend res "INP_OVR"}
    if {$s & (1<<1)} {lappend res "FLT_OVR"}
    if {$s & (1<<2)} {lappend res "OUTPT_OVR"}
    if {$s & (1<<3)} {lappend res "UNLOCK"}
    if {$s & (1<<4)} {lappend res "FREQ_LO"}
    if {$res == {}} {lappend res "OK"}
    return [join $res " "]
  }

}

######################################################################
# Use Picoscope as a gauge.
#
# Channels:

# * `DC(<channels>)` -- measure DC signal on all oscilloscope channels
#   (`A`, `B`, etc) channels, return multiple values, one for each channel.
#   Any number of channels with any order and repeats can be used. For example
#   `DC(ABA)` returns three values: DC components on A, B, and A channels.
#
# * `DC` -- same as DC(A).
#
# * `lockin(<channels>):FXY` -- do a lock-in measurement. Channel list should
#   contain even number of oscilloscope channels (`A`, `B`, etc.) to be used
#   as signal+reference pairs. Three numbers per each channel pair are returned:
#   frequency (Hz) and two signal components (V). Any number of channels with
#   any order and repeats can be used. For reference channels 10V range is
#   used unless signal and reference channel are same.
#   Examples: `lockin(AB):FXY`, `lockin(AA):FXY`, `lockin(ABCD):FXY`,
#   `lockin(ADBDCD):FXY`.
#
# * `lockin(<channels>):XY` -- same, but returns two numbers per channel,
#   X and Y components.
#
# * If `(<channels>)` is skipped then `(AB)` is used. If `:FXY` or `:XY`
#   suffix is skipped then `:FXY` is used. Thus using just `lockin` is same as
#   `lockin(AB):FXY`.
#
# Tested:
#   2020/10/05, Pico 4224, 4262,   V.Z.

itcl::class picoscope {
  inherit interface
  proc test_id {id} {
    if {[regexp {pico_rec} $id]} {return 1}
    return {}
  }

  variable osc_meas;  # measurement type: DC, lockin
  variable osc_ch;    # list of oscilloscope channels (A B)
  variable osc_out;   # output format for lockin measurement (XY, FXY)
  variable osc_ach;   # unique channel sequence: ABCD
  variable osc_nch;   # number of each channel in osc_ach: osc_nch(A)=0, osc_nch(B)=1

  # lock-in ranges and time constants
  common ranges
  common tconsts {1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0 3.0 10.0}
  common tconst
  common range
  common range_ref
  common npt 1e6; # point number
  common sigfile
  common status

  constructor {d ch id} {

    set osc_meas {}
    if {[regexp {^DC(\(([A-D]+)\))?$} $ch v0 v1 v2]} {
      set osc_meas DC
      set_osc_ch [split $v2 {}]
      set valnames [split $v2 {}]
      # defaults
      if {$osc_ch == {}} {
        set_osc_ch A
        set valnames "A"
      }

    }
    if {[regexp {^lockin(\(([A-D]+)\))?(:([FRXY]+))?$} $ch v0 v1 v2 v3 v4]} {
      set osc_meas lockin
      set_osc_ch [split $v2 {}]
      set osc_out $v4
      # defaults
      if {$osc_ch  == {}} {set_osc_ch [list A B]}
      if {$osc_out == {}} {set osc_out FXY}

      # we want 2,4,6... channels
      if {[llength $osc_ch] %2 != 0} {
        error "$this: bad channel setting: 2,4... oscilloscope channels expected: $ch"}

      # output format
      for {set i 0} {$i<[llength $osc_ch]/2} {incr i} {
        switch -exact -- $osc_out {
          XY  {lappend valnames "X$i"; lappend valnames "Y$i"}
          FXY {lappend valnames "F$i"; lappend valnames "X$i"; lappend valnames "Y$i"}
          default {error "$this: bad channel setting: only XY or FXY output is supported: $ch"}
        }
      }
    }
    if {$osc_meas == {}} { error "$this: bad channel setting: $ch" }

    set dev $d

    # oscilloscope ranges
    set ranges [lindex [split [Device2::ask $dev ranges A] "\n"] 0]
    if {[llength $ranges]==1} {set ranges {*}$ranges}
    set range [get_range]
    if { $range == "undef" } {set range 1.0}
    set range_ref 10.0
    setup_osc_chans

    set tconst 1.0

    set sigfile "/tmp/$dev:gauge.sig"
    set status "OK"
  }

  ############################
  method setup_osc_chans {} {
    # oscilloscope setup (pairs of channels: signal+reference)
    if {$osc_meas=="lockin"} {
      foreach {c1 c2} $osc_ch {
        Device2::ask $dev chan_set $c1 1 AC $range
        if {$c1 != $c2} { Device2::ask $dev chan_set $c2 1 AC $range_ref }
        }
    }
    if {$osc_meas=="DC"} {
        # oscilloscope setup
        foreach ch $osc_ch {
          Device2::ask $dev chan_set $ch 1 DC $range
        }
    }
  }

  ############################
  method set_osc_ch  {val} {
    set osc_ch $val
    # fill osc_ach and osc_nch
    set i 0
    set osc_ach {}
    array unset osc_nch
    foreach ch $osc_ch {
      if {[array names osc_nch $ch] == {}} {
        set osc_ach "$osc_ach$ch"
        set osc_nch($ch) $i
        incr i
      }
    }
  }

  ############################
  method get {{auto 0}} {
    if {$osc_meas=="lockin"} {
      set dt [expr $tconst/$npt]
      set justinc 0; # avoid inc->dec loops
      while {1} {
        Device2::ask $dev trig_set NONE 0.1 FALLING 0
        # record signal
        Device2::ask $dev block $osc_ach 0 $npt $dt $sigfile

        # check for overload (any signal channel)
        set ovl 0
        foreach {c1 c2} $osc_ch {
          if {[Device2::ask $dev filter -c $osc_nch($c1) -f overload $sigfile]} {set ovl 1}
        }

        # try to increase the range and repeat
        if {$auto == 1 && $ovl == 1} {
          set justinc 1
          if {![catch {inc_range}]} continue
        }

        set status "OK"

        # measure the value
        set max_amp 0
        set ret {}
        foreach {c1 c2} $osc_ch {
          set v [Device2::ask $dev filter -f lockin -c $osc_nch($c1),$osc_nch($c2) $sigfile]
          if {[llength $v] == 1} {set v [lindex $v 0]}

          set v [lindex [split $v "\n"] 0]
          if {$v == {}} {
            set f 0
            set x 0
            set y 0
            set status "ERR"
          } else {
            set f [lindex $v 0]
            set x [lindex $v 1]
            set y [lindex $v 2]
          }
          set amp [expr sqrt($x**2+$y**2)]
          set max_amp [expr max($amp,$max_amp)]

          if {$osc_out == "XY"} {
            lappend ret $x $y
          } else {
            lappend ret $f $x $y
          }

          # if it is still overloaded
          if {$ovl == 1} { set status "OVL" }
        }

        # if amplitude is too small, try to decrease the range and repeat
        if {$auto == 1 && $justinc == 0 && $status == {OK} && $max_amp < [expr 0.5*$range]} {
          if {![catch {dec_range}]} continue
        }
        break
      }
      return $ret
    }
    if {$osc_meas=="DC"} {
      set dt [expr $tconst/$npt]
      set justinc 0; # avoid inc->dec loops

      while {1} {
        Device2::ask $dev trig_set NONE 0.1 FALLING 0
        # record signal
        Device2::ask $dev block $osc_ach 0 $npt $dt $sigfile

        # check for overload
        set ovl 0
        foreach ch $osc_ch {
          if {[Device2::ask $dev filter -c $osc_nch($ch) -f overload $sigfile]} {set ovl 1}
        }

        # try to increase the range and repeat
        if {$auto == 1 && $ovl == 1} {
          set justinc 1;
          if {![catch {inc_range}]} continue
        }

        set status "OK"

        # measure the value
        set nch {}
        foreach ch $osc_ch {
          lappend nch $osc_nch($ch)
        }
        set nch [join $nch {,}]
        set ret [Device2::ask $dev filter -c $nch -f dc $sigfile]

        # if it is still overloaded
        if {$ovl == 1} {
          set status "OVL"
          break
        }

        # if amplitude is too small, try to decrease the range and repeat
        #  -- for DC $ret value can be negative
        #  -- also max/min sometimes fail with only 1 arg
        if {$auto == 1} {
          set max 0
          foreach v $ret {
            set av [expr abs($v)]
            if {$max < $av} {set max $av}
          }
          if {$justinc==0 && $max < [expr 0.5*$range]} {
            if {![catch {dec_range}]} continue
          }
        }
        break
      }
      return $ret
    }
  }
  method get_auto {} { return [get 1] }

  ############################
  method list_ranges {} { return $ranges }
  method list_tconsts {} { return $tconsts }


  ############################
  method set_range  {val} {
    set n [lsearch -real -exact $ranges $val]
    if {$n<0} {error "unknown range setting: $val"}
    set range $val
    setup_osc_chans
  }
  method get_range {} {
    set c [lindex $osc_ch 0]
    set res [Device2::ask $dev chan_get $c]
    if {[llength $res] == 1} {set res [lindex $res 0]}
    set ch_cnf [lindex [split $res "\n"] 0]
    return [lindex $ch_cnf end]
  }
  method dec_range {} {
    set n [lsearch -real -exact $ranges $range]
    if {$n<0} {error "unknown range setting: $range"}
    if {$n==0} {error "range already at minimum: $range"}
    set_range [lindex $ranges [expr $n-1]]
  }
  method inc_range {} {
    set n [lsearch -real -exact $ranges $range]
    set nmax [expr {[llength $ranges] - 1}]
    if {$n<0} {error "unknown range setting: $range"}
    if {$n>=$nmax} {error "range already at maximum: $range"}
    set_range [lindex $ranges [expr $n+1]]
  }

  ############################
  method set_tconst {val} {
    # can work with any tconst!
    set tconst $val
  }
  method get_tconst {} { return $tconst }

  ############################
  method get_status_raw {} { return $status }
  method get_status {} { return $status }

}

######################################################################
# Use Picoscope ADC as a gauge.
#
# Channels:
#
# * Channel setting V1:
#   `<channels>(r<range>)` -- measure DC signal on any oscilloscope channels
#   (`01`, `02`, etc), return multiple values, one for each channel.
#   Any number of channels with any order and repeats can be used. For example
#   `110711(r1250)` returns three values: on 11, 07, and 11 channels.
#   Conversion time is always 180 ms.
#
# * Channel setting V2:
#   <chan1>(s|d)<range>,<chan2>(s|d)<range>,...
#   Configure multiple channels for single/double-ended measurements,
#   with separate ranges. Conversion time is always 180 ms.
#
# * Channel setting V3:
#   <chan>(s|d)
#   Measure only one channel, range and conversion time is controlled
#   with get_/set_tconst and get_/set_range.
#   This mode is sutable for using the device by multiple users.
#   Other modes should be removed in the future...
#
# Tested:
#   2020/10/05, PicoADC24,   V.Z.
#

itcl::class picoADC {
  inherit interface
  proc test_id {id} {
    if {[regexp {pico_adc} $id]} {return 1}
    return {}
  }

  # Variables for multi-channel modes
  variable adc_ach {};    # list of channels: {01 12 05 12}
  variable adc_uch {};    # list of channels, unique and sorted: {01 05 12}
  common tconv_multi  180

  # Variables for single-channel mode
  common chan  {};   # channel
  common sngl   1;   # single/differential
  common range 2500; # range
  common convt  180; # conversion time

  constructor {d ch id} {

    set dev $d

    # V3 Single-channel mode: device:1s
    # Here only channel number and single/differential mode is set.
    # Range and conversion time is controlled with get_/set_tconst and get_/set_range.
    # This mode is sutable for using the device by multiple users:
    if {[regexp {^([0-9]+)([sd])$} $ch v0 chan vsd]} {
      set sngl [expr {"$vsd"=="s"? 1:0}]
      if {!$sngl && $chan%2 != 1} {
        error "can't set double-ended mode for even-numbered channel: $chan" }
      return
    }

    array unset range_;  # range array (for each channel)
    array unset single_; # single-ended mode, 1 or 0, array (for each channel)

    # V1 channel setting: "device:010203(r2500)".
    # Any channel order, single rande for all channels,
    # only single-ended measurements.
    if {[regexp {^([0-9]+)\(r([0-9\.]+)\)?$} $ch v0 v1 v2]} {
      if {[string length $v1] %2 != 0} {
        error "$this: bad channel setting: 2-digits oscilloscope channels expected: $ch"}

      foreach {c1 c2} [split $v1 {}] {
        set c "$c1$c2"
        lappend adc_ach $c
        lappend valnames $c
        set range_($c) $v2
        set single_($c) 1
      }

    # V2 channel setting: "device:1s2500,2d1000,12s1000"
    # Single/double-ended measurements, separate ranges.
    # Duplicated channels are not allowed.
    } else {
      foreach c [split $ch {,}] {
        if {[regexp {^([0-9]+)([sd])([0-9\.]+)} $c v0 vch vsd vrng]} {

          set vch [format {%d} $vch]
          if {[lsearch $adc_ach $vch] >=0 } {
            error "duplicated channel $vch in $c"}

          lappend adc_ach $vch
          lappend valnames $vch
          set range_($vch) $vrng
          set single_($vch) [expr {"$vsd"=="s"? 1:0}]

          if {!$single_($vch) && $vch%2 != 1} {
            error "can't set double-ended mode for even-numbered channel: $vch" }
        }\
        else {error "wrong channel setting: $c"}
      }
    }

    # V1 and V2 modes only
    if {$chan == {}} {
      # no channels set
      if {[llength $adc_ach] == 0} {error "no channels"}

      # list of sorted unique channels
      set adc_uch [lsort -integer -unique $adc_ach]

      # set ADC channels
      foreach c $adc_uch {
        Device2::ask $dev chan_set [format "%02d" $c] 1 $single_($c) $range_($c)
      }
      # set ADC time intervals.
      set dt [expr [llength $adc_uch]*$convt+100]
      Device2::ask $dev set_t $dt $convt
    }
  }

  ############################
  method get {{auto 0}} {
    # V1 and V2 modes:
    if {$chan == {}} {
      array unset ures
      array unset ares
      set uvals [Device2::ask $dev get]
      foreach v $uvals ch $adc_uch {
        set ures($ch) $v
      }
      foreach ch $adc_ach {
        lappend ares $ures($ch)
      }
      return $ares

    # V3 mode:
    } else {
      return [Device2::ask $dev get_val $chan $sngl $range $convt]
    }
  }
  method get_auto {} { return [get 1] }

  ############################
  method list_ranges  {} {return [Device2::ask $dev ranges]}
  method list_tconsts {} {return [Device2::ask $dev tconvs]}
  method set_range  {val} {set range $val}
  method set_tconst {val} {set convt $val}
  method get_range  {} {return $range}
  method get_tconst {} {return $convt}

}

######################################################################
# Use Agilent VS leak detector as a gauge.
#

itcl::class leak_ag_vs {
  inherit interface
  proc test_id {id} {
    set id [join [split $id "\n"] " "]
    if {$id == {Agilent VS leak detector}} {return 1}
    return {}
  }

  constructor {d ch id} {
    set valnames [list "Leak" "Pout" "Pin"]
    set dev $d
  }

  ############################
  method get {} {
    set v "?LP"
    set ret [Device2::ask $dev $v]

    # cut command name (1st word) from response if needed
    if {[lindex {*}$ret 0] == $v} {set ret [lrange {*}$ret 1 end]}

    set leak [lindex $ret 0]
    set pout [lindex $ret 1]
    set pin  [lindex $ret 2]
    # Values can have leading zeros.
    if {[string first "." $leak] == -1} {set leak "$leak.0"}
    if {[string first "." $pout] == -1} {set pout "$pout.0"}
    if {[string first "." $pin]  == -1} {set pin  "$pin.0"}

    set pout [format %.4e [expr $pout/760000.0]]; # mtor->bar
    set pin  [format %.4e [expr $pin/760000000.0]]; # utor->bar

    return [list $leak $pout $pin]
  }
  method get_auto {} { return [get] }
}

######################################################################
# Pfeiffer Adixen ASM340 leak detector
#

itcl::class leak_asm340 {
  inherit interface
  proc test_id {id} {
    if {$id == {Adixen ASM340 leak detector}} {return 1}
    return {}
  }

  variable chan;  # channel to use

  constructor {d ch id} {
    # channels are not supported now
    set valnames [list "Leak" "Pin"]
    set dev $d
  }

  # convert numbers received from the leak detector:
  # 123+1 -> 1.23e+03
  method conv_number {v} {
    if { [regexp {^([0-9]+)([\+\-][0-9]+)$} $v a b c] } { set v "${b}e${c}" }
    return [format "%.2e" $v]
  }

  ############################
  method get {} {
    # inlet pressure, measurement (calibrated)
    set pin   [conv_number [Device2::ask $dev ?PE]]
    set leak  [conv_number [Device2::ask $dev ?LE2]]
    return [list $leak $pin]
  }
  method get_auto {} { return [get] }
}

######################################################################
# Use Pfeiffer HLT 2xx leak detector as a gauge.
#
itcl::class leak_pf {
  inherit interface
  proc test_id {id} {
    set id [string map {"\n" " "} $id]
    if {[regexp {Pfeiffer HLT 2} $id]} {return 1}
  }

  constructor {d ch id} {
    set dev $d
  }

  ############################
  method get {} {
    set ret [Device2::ask $dev "leak?"]
    return $ret
  }
  method get_auto {} { return [get] }
}

######################################################################
# Phoenix l300i leak detector
#

itcl::class leak_l300 {
  inherit interface
  proc test_id {id} {
    if {$id == {PhoeniXL300}} {return 1}
    return {}
  }

  variable chan;  # channel to use

  constructor {d ch id} {
    # channels are not supported now
    set valnames [list "Leak" "Pin"]
    set dev $d
  }

  ############################
  method get {} {
    # inlet pressure, measurement (calibrated)
    set pin   [Device2::ask $dev "*meas:p1:mbar?"]
    set leak  [Device2::ask $dev "*read:mbar*l/s?"]
    return [list $leak $pin]
  }
  method get_auto {} { return [get] }
}


######################################################################
# EastTester ET4502, ET1091 LCR meters
#
# ZC,ET1091B        ,V1.01.2026.016,V1.12.2035.007,10762110001
#
# Channels: <v1>-<v2>
#  v1: R C L Z DCR ECAP
#  v2: X D Q THR ESR

itcl::class lcr_et4502 {
  inherit interface
  proc test_id {id} {
    if {[regexp {,ET4502}  $id]} {return "ET4502"}
    if {[regexp {,ET1091B} $id]} {return "ET1091B"}
    return {}
  }

  constructor {d ch id} {
    set c [split $ch {-}]
    if {[llength $c] == 0} {
      set A "C"
      set B "Q"
    }\
    elseif {[llength $c] == 2} {
      set A [lindex $c 0]
      set B [lindex $c 1]
      if {[lsearch -exact {R C L Z DCR ECAP} $A] < 0} {
        error "lcr_et4502: wrong A measurement: $A, should be one of R C L Z DCR ECAP"
      }
      if {[lsearch -exact {X D Q THR ESR} $B] < 0} {
        error "lcr_et4502: wrong B measurement: $B, should be one of X D Q THR ESR"
      }
    }\
    else {
      error "lcr_et4502: bad channel setting: $ch"
    }
    set names [list $A $B]
    set dev $d
    Device2::ask $dev FUNC:DEV:MODE OFF
    Device2::ask $dev FUNC:IMP:A $A
    Device2::ask $dev FUNC:IMP:B $B
    Device2::ask $dev FUNC:IMP:RANG:AUTO ON
    Device2::ask $dev FUNC:IMP:EQU SER
    after 100
  }

  ############################
  method get {} {
    return [join [split [Device2::ask $dev fetch?] {,}]]
  }
}


######################################################################
# Andeen Hagerling AH2500 capacitance bridge.
#
# Configuration for device2 server:
#   cap_br  gpib -board <N> -addr <M> -idn AH2500 -read_cond always -delay 0.05

itcl::class ah2500 {
  inherit interface
  proc test_id {id} {
    if {[regexp {^AH2500$} $id]} {return 1}
    return {}
  }

  constructor {d ch id} {
    set dev $d
    if {$ch ne {}} {
      error "ah2500: no channels supported"
    }
  }

  ############################
  method get {} {
    regexp {C=\s*([0-9.]+)\s+(PF)\s+L=\s*([0-9.]+)\s*(NS)} \
      [Device2::ask $dev "SI"] X CV CU LV LU
    return "$CV $LV"
  }
}

######################################################################
} # namespace
