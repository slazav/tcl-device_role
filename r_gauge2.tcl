######################################################################
# gauge2 role

# Simplified interface:
# - remove set_range, set_tconst, get_range,
#   get_tconst, list_ranges, list_tconsts methods
#   use conf_* interface instead.
# - remove get_auto method.
# - remove get_val_num, get_val_name methods,
#   use configuration {names const} instead
# - avoid multi-channel operations with complicated channel names.
#   use conf_* interface instead of configuring device through channels
# - NaN/Inf return if overloaded
#
# `conf_*` interface should be used instead. Recommended parameter names:
# autorange bool   -- enable autorange
# range  {<list>}  -- set manual range
# tconst {<list>}  -- set time constant
# names  const     -- column names


package require Itcl
package require Device2

namespace eval device_role::gauge2 {

######################################################################
## Interface class. All gauge driver classes are children of it
itcl::class interface {
  inherit device_role::base_interface
  proc test_id {id} {}


  method get {} {}; # do the measurement, return one or more numbers
}

######################################################################
# Virtual gauge device.
#
# Channel settings:
#  * <device>         -- get one random number
#  * <device>:(T|R)+  -- get a few numbers, T - time sweep, R - random
#
# Configuration parameters:
#  * maxv         float        -- max value
#  * tsweep       int          -- time sweep length, s
#  * tsweep_list  {5 10 15 20} -- time sweep length, s
#  * names        const        -- column names
#

itcl::class TEST {
  inherit interface
  proc test_id {id} {}

  variable chan;  # channel to use (R, RR, RRT, etc.)
  variable maxv 1;    # amplitude of the output value
  variable tsweep 10; # time sweep length, s

  constructor {d ch id} {
    set chan $ch
    if {$chan == {}} {set chan {R}}

    foreach c [split $chan {}] {
      if {$c != {R} && $c != {T}} {error "bad channel setting: $c" }}
  }
  destructor {}

  ############################
  method get {} {
    set data {}
    foreach c [split $chan {}] {
      set v 0
      if {$c=={R}} { set v [expr {1.0*$maxv*rand()}] }
      if {$c=={T}} {
        set t [expr {[clock milliseconds]%($tsweep*1000)}]
        set v [expr {1e-3*$t*$maxv/$tsweep}]
      }
      lappend data $v
    }
    return $data
  }

  ############################
  method conf_list {} {
    return [list {
      maxv         float
      tsweep       int
      tsweep_list  {5 10 15 20}
      names        const
    }]
  }

  method conf_get {name} {
    switch -exact -- $name {
      maxv        { return $maxv}
      tsweep      { return $tsweep}
      tsweep_list { return $tsweep}
      names       { return [split $chan {}] }
      default {error "unknown configuration name: $name"}
    }
  }

  method conf_set {name val} {
    switch -exact -- $name {
      maxv        { set maxv $val}
      tsweep      { set tsweep $val}
      tsweep_list { set tsweep $val}
      default {error "unknown configuration name: $name"}
    }
  }
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
# Channels: ACI, DCI, ACV, DCV, R2, R4
# Configuration parameters:
#  - autorange (bool)-- use autorange
#  - range (float)-- set range
#  - nplc -- integration time, line cycles
#             Keysight (list): 0.02 0.2 1 10 100 MIN MAX
#             Keythley (float): 0.01..10
#  - names (const) -- column names (same as channel)
#
# Tested:
#   2020/10/05, Keythley-2020,   V.Z.
#   2020/10/05, Keysight-34410A, V.Z.

itcl::class keysight {
  inherit interface
  variable func
  variable names
  variable nplc_type; # type/range of nplc seetting

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
      default { error "$this: bad channel setting: $ch" }
    }
    switch -exact -- $id {
      Keythley2000 { set nplc_type {float} } # 0.01..10
      default {set nplc_type {0.02 0.2 1 10 100 MIN MAX}}
    }
    set dev $d
    set names $ch
    dev_check $dev "meas:$func?"
  }

  ############################
  method get {} { return [$dev cmd "read?"] }

  ############################
  method conf_list {} {
    return [list {
      autorange  bool
      range      string
      nplc       $nplc_type
      names      const
    }]
  }

  method conf_get {name} {
    switch -exact -- $name {
      autorange  { return [$dev cmd "$func:RANGE:AUTO?"]}
      range      { return [expr {[$dev cmd "$func:RANGE?"]}]}
      nplc       { return [expr {[$dev cmd "$func:NPLC?"]}]}
      names      { return $names}
      default {error "unknown configuration name: $name"}
    }
  }

  method conf_set {name val} {
    switch -exact -- $name {
      autorange  { dev_set_par $dev "$func:RANGE:AUTO" $val}
      range      { dev_set_par $dev "$func:RANGE" $val}
      nplc       { dev_set_par $dev "$func:NPLC" $val}
      default {error "unknown configuration name: $name"}
    }
  }

}

######################################################################
# Use Keithley nanovoltmeter 2182A as a gauge device.
#
# ID strings:
# KEITHLEY INSTRUMENTS INC.,MODEL 2182A,1193143,C02 /A02
#
# Channels: DCV1 DCV2
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
  method get {} { return [$dev cmd "read?"] }

}

######################################################################
# Use Keysight/Agilent/HP multiplexer 34972A as a gauge device.
#
# ID strings:
#   Agilent Technologies,34972A,MY59000704,1.17-1.12-02-02
#
# Channels: operation and device channel numbers, e.g. ACI(101:102)
#   operations: DCI, ACV, DCV, R2, R4.
#   channel numbers are set as in the device: comma-separated lists: 101,105
#     or colon-separated ranges 101:105.
#
# For R4 measurement channels are paird with n+10 (34901A extension) or
# n+8 (34902A extension)
#
# Configuration parameters:
#  - autorange (bool)-- use autorange
#  - range (float)-- set range
#  - nplc -- integration time, line cycles
#             Keysight (list): 0.02 0.2 1 10 100 MIN MAX
#             Keythley (float): 0.01..10
#  - names (const) -- column names (same as channel)
#
# Parallel access: only for different channels
#  (channel configration is done only once)
#
# Tested:
#   2020/10/05, Keysight-34972A,   V.Z.


itcl::class keysight_mplex {
  inherit interface
  proc test_id {id} {
    if {[regexp {,34972A,} $id]} {return {34972A}}
    return {}
  }

  variable func;   # measurement function (volt:dc, etc.)
  variable chans;  # device channels (101:105, etc.)
  variable names;  # column names

  constructor {d ch id} {
    set dev $d
    if {![regexp {^([A-Z0-9]+)\(([0-9:,]+)\)$} $ch v0 vmeas chans]} {
      error "bad channel setting: $ch" }

    switch -exact -- $vmeas {
      DCV {  set func volt:dc }
      ACV {  set func volt:ac }
      DCI {  set func curr:dc }
      ACI {  set func curr:ac }
      R2  {  set func res     }
      R4  {  set func fres    }
      default { error "$this: bad channel setting: $c" }
    }

    # Construct column names, check if channel setting is correct
    foreach c [split $chans {,}] {
      if {[regexp {^ *([0-9]+) *$} $c v0 n1]} {
        lappend names "$vmeas-$n1"
      }\
      elseif {[regexp {^ *([0-9]+):([0-9]+) *$} $c v0 n1 n2]} {
        if {$n2<=$n1} {error "non-increasing channel range: $c"}
        for {set n $n1} {$n<=$n2} {incr n} {
          lappend names "$vmeas-$n"
        }
      } else { error "bad channel setting: $c" }
    }

    # Setup channels
    dev_check $dev "conf:$func (@$chans)"
  }

  ############################
  method get {} {
    dev_check $dev "rout:scan (@$chans)"; # set scan list
    set ret [dev_check $dev "read?"]
    set ret [string map {, " "} $ret]
    return $ret
  }
  ############################

  # when reading settings for mltiple channels (range, autoconf)
  # they are comma-separated values. Merge them into single value
  method merge_conf {vals} {
    set v0 {}
    foreach v [split $vals {,}] {
      if {$v0 != {} && $v0!=$v } {return {MULT_VAL}}
      set v0 $v
    }
    return $v0
  }

  ############################
  method conf_list {} {
    return [list {
      autorange  bool
      range      string
      autodelay  float
      delay      float
      nplc       {0.02 0.2 1 10 100 MIN MAX}
      names      const
    }]
  }

  method conf_get {name} {
    switch -exact -- $name {
      autorange  { return [merge_conf [$dev cmd "$func:RANGE:AUTO? (@$chans)"]]}
      range      { return [merge_conf [$dev cmd "$func:RANGE? (@$chans)"]]}
      autodelay  { return [merge_conf [$dev cmd "ROUT:CHAN:DEL:AUTO? (@$chans)"]]}
      delay      { return [merge_conf [$dev cmd "ROUT:CHAN:DEL? (@$chans)"]]}
      nplc       { return [merge_conf [$dev cmd "$func:NPLC? (@$chans)"]]}
      names      { return $names}
      default {error "unknown configuration name: $name"}
    }
  }

  method conf_set {name val} {
    switch -exact -- $name {
      autorange  { dev_check $dev "$func:RANGE:AUTO $val,(@$chans)"}
      range      { dev_check $dev "$func:RANGE $val,(@$chans)"}
      autodelay  { dev_check $dev "ROUT:CHAN:DEL:AUTO $val,(@$chans)"}
      delay      { dev_check $dev "ROUT:CHAN:DEL $val,(@$chans)"}
      nplc       { dev_check $dev "$func:NPLC $val,(@$chans)"}
      default {error "unknown configuration name: $name"}
    }
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
#
# Configuration parameters:
#
#      autorange  bool
#      range      <list>
#      tconst     <list>
#      src        int    -- # input 0-3: A/A-B/I_1MOhm/I_100MOhm
#      names      const
#      status     const
#

itcl::class sr844 {
  inherit interface
  proc test_id {id} {
    if {[regexp {,SR844,} $id]} {return 1}
  }

  variable chan;  # channel to use (1..2)
  variable names;
  variable autorange;

  # lock-in ranges and time constants
  common ranges  {1e-7 3e-7 1e-6 3e-6 1e-5 3e-5 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0}
  common tconsts {1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0 3.0 10.0 30.0 1e2 3e3 1e3 3e3 1e4 3e4}
  common aux_range 10;    # auxilary input range: +/- 10V
  common aux_tconst 3e-4; # auxilary input bandwidth: 3kHz

  constructor {d ch id} {
    switch -exact -- $ch {
      1   {set names {AUX1}}
      2   {set names {AUX2}}
      XY  {set names [list X Y]}
      RT  {set names [list R T]}
      FXY {set names [list F X Y]}
      FRT {set names [list F R T]}
      default {error "$this: bad channel setting: $ch"}
    }
    set chan $ch
    set dev $d
    set autorange 0;
  }

  ############################
  method get {} {
    # If channel is 1 or 2 read auxilary input:
    if {$chan==1 || $chan==2} { return [$dev cmd "AUXO?${chan}"] }

    # If autorange is needed, use AGAN command:
    if {$autorange} {$dev cmd "AGAN"; after 100}

    # check status and return NaN in needed
    set s [$dev cmd "LIAS?"]
    if {$s != 0} { return [lrepeat [llength $names] NaN] }

    # Return space-separated values depending on channel setting
    if {$chan=="XY"} { return [string map {"," " "} [$dev cmd SNAP?1,2]] }
    if {$chan=="RT"} { return [string map {"," " "} [$dev cmd SNAP?3,5]] }
    if {$chan=="FXY"} { return [string map {"," " "} [$dev cmd SNAP?8,1,2]] }
    if {$chan=="FRT"} { return [string map {"," " "} [$dev cmd SNAP?8,3,5]] }
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

  method set_range  {val} {
    if {$chan==1 || $chan==2} { error "can't set range for auxilar input $chan" }
    set n [lsearch -real -exact $ranges $val]
    if {$n<0} {error "unknown range setting: $val"}
    $dev cmd "SENS $n"
  }

  method set_tconst {val} {
    if {$chan==1 || $chan==2} { error "can't set time constant for auxilar input $chan" }
    set n [lsearch -real -exact $tconsts $val]
    if {$n<0} {error "unknown time constant setting: $val"}
    $dev cmd "OFLT $n"
  }

  method get_range  {} {
    if {$chan==1 || $chan==2} { return $aux_range}
    set n [$dev cmd "SENS?"]
    return [lindex $ranges $n]
  }

  method get_tconst {} {
    if {$chan==1 || $chan==2} { return $aux_tconst}
    set n [$dev cmd "OFLT?"]
    return [lindex $tconsts $n]
  }

  method get_status_raw {} {
    return [$dev cmd "LIAS?"]
  }

  method get_status {} {
    set s [$dev cmd "LIAS?"]
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

  ############################
  method conf_list {} {
    return [list {
      autorange  bool
      range      [list_ranges]
      tconst     [list_tconsts]
      names      const
      status     const
    }]
  }

  method conf_get {name} {
    switch -exact -- $name {
      autorange  { return $autorange}
      range      { return [get_range]}
      tconst     { return [get_tconst]}
      names      { return $names}
      status     { return [get_status]}
      default {error "unknown configuration name: $name"}
    }
  }

  method conf_set {name val} {
    switch -exact -- $name {
      autorange  { set autorange 1}
      range      { set_range $val}
      tconst     { set_tconst $val}
      default {error "unknown configuration name: $name"}
    }
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
# Configuration parameters:
#
#      autorange  bool
#      range      <list>
#      tconst     <list>
#      src        int    -- # input 0-3: A/A-B/I_1MOhm/I_100MOhm
#      names      const
#      status     const
#
# Tested:
#   2020/10/05, SR830,   V.Z.
#

itcl::class sr830 {
  inherit interface
  proc test_id {id} {
    if {[regexp {,SR830,} $id]} {return 1}
  }

  variable chan;  # channel to use (1..2)

  # lock-in ranges and time constants
  common ranges_V  {2e-9 5e-9 1e-8 2e-8 5e-8 1e-7 2e-7 5e-7 1e-6 2e-6 5e-6 1e-5 2e-5 5e-5 1e-4 2e-4 5e-4 1e-3 2e-3 5e-3 1e-2 2e-2 5e-2 0.1 0.2 0.5 1.0}
  common ranges_A  {2e-15 5e-15 1e-14 2e-14 5e-14 1e-13 2e-13 5e-13 1e-12 2e-12 5e-12 1e-11 2e-11 5e-11 1e-10 2e-10 5e-10 1e-9 2e-9 5e-9 1e-8 2e-8 5e-8 1e-7 2e-7 5e-7 1e-6}
  common tconsts   {1e-5 3e-5 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1.0 3.0 10.0 30.0 1e2 3e3 1e3 3e3 1e4 3e4}
  common aux_range 10;    # auxilary input range: +/- 10V
  common aux_tconst 3e-4; # auxilary input bandwidth: 3kHz

  common names;     # column names
  common autorange;

  constructor {d ch id} {
    switch -exact -- $ch {
      1   {set names {AUX1}}
      2   {set names {AUX2}}
      XY  {set names [list X Y]}
      RT  {set names [list R T]}
      FXY {set names [list F X Y]}
      FRT {set names [list F R T]}
      default {error "$this: bad channel setting: $ch"}
    }
    set chan $ch
    set dev $d
    set autorange 0;
  }

  ############################
  method get {} {
    # If channel is 1 or 2 read auxilary input:
    if {$chan==1 || $chan==2} { return [$dev cmd "OAUX?${chan}"] }

    # If autorange is needed, use AGAN command:
    if {$autorange} {$dev cmd "AGAN"; after 100}

    # check status and return NaN in needed
    set s [$dev cmd "LIAS?"]
    if {$s != 0} { return [lrepeat [llength $names] NaN] }

    # Return space-separated values depending on channel setting
    if {$chan=="XY"}  { return [string map {"," " "} [$dev cmd SNAP?1,2]] }
    if {$chan=="RT"}  { return [string map {"," " "} [$dev cmd SNAP?3,4]] }
    if {$chan=="FXY"} { return [string map {"," " "} [$dev cmd SNAP?9,1,2]] }
    if {$chan=="FRT"} { return [string map {"," " "} [$dev cmd SNAP?9,3,4]] }
  }
  method get_auto {} { return [get 1] }

  ############################
  method list_ranges {} {
    if {$chan==1 || $chan==2} {return $aux_range}
    set src [$dev cmd "ISRC?"]
    if {$src == 0 || $src == 1} { set ranges $ranges_V } { set ranges $ranges_A }
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
    $dev cmd "SENS $n"
  }
  method set_tconst {val} {
    if {$chan==1 || $chan==2} { error "can't set time constant for auxilar input $chan" }
    set n [lsearch -real -exact $tconsts $val]
    if {$n<0} {error "unknown time constant setting: $val"}
    $dev cmd "OFLT $n"
  }

  ############################
  method get_range  {} {
    if {$chan==1 || $chan==2} { return $aux_range}
    set src [$dev cmd "ISRC?"]
    if {$src == 0 || $src == 1} { set ranges $ranges_V }\
    else { set ranges $ranges_A }
    set n [$dev cmd "SENS?"]
    return [lindex $ranges $n]
  }

  method get_tconst {} {
    if {$chan==1 || $chan==2} { return $aux_tconst}
    set n [$dev cmd "OFLT?"]
    return [lindex $tconsts $n]
  }

  method get_status_raw {} {
    return [$dev cmd "LIAS?"]
  }

  method get_status {} {
    set s [$dev cmd "LIAS?"]
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

itcl::class picoscope {
  inherit interface
  proc test_id {id} {
    if {[regexp {pico_rec} $id]} {return 1}
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
  common autorange 0

  constructor {d ch id} {

    set osc_meas {}
    if {[regexp {^DC(\(([A-D]+)\))?$} $ch v0 v1 v2]} {
      set osc_meas DC
      set_osc_ch [split $v2 {}]
      set names [split $v2 {}]
      # defaults
      if {$osc_ch == {}} {
        set_osc_ch A
        set names "A"
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
          XY  {lappend names "X$i"; lappend names "Y$i"}
          FXY {lappend names "F$i"; lappend names "X$i"; lappend names "Y$i"}
          default {error "$this: bad channel setting: only XY or FXY output is supported: $ch"}
        }
      }
    }
    if {$osc_meas == {}} { error "$this: bad channel setting: $ch" }

    set dev $d

    # oscilloscope ranges
    set ranges [$dev cmd ranges A]
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
        $dev cmd chan_set $c1 1 AC $range
        if {$c1 != $c2} { $dev cmd chan_set $c2 1 AC $range_ref }
        }
    }
    if {$osc_meas=="DC"} {
        # oscilloscope setup
        foreach ch $osc_ch {
          $dev cmd chan_set $ch 1 DC $range
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
  method get {} {
    if {$osc_meas=="lockin"} {
      set dt [expr $tconst/$npt]
      set justinc 0; # avoid inc->dec loops
      while {1} {
        $dev cmd trig_set NONE 0.1 FALLING 0
        # record signal
        $dev cmd block $osc_ach 0 $npt $dt $sigfile

        # check for overload (any signal channel)
        set ovl 0
        foreach {c1 c2} $osc_ch {
          if {[$dev cmd filter -c $osc_nch($c1) -f overload $sigfile]} {set ovl 1}
        }

        # try to increase the range and repeat
        if {$autorange == 1 && $ovl == 1} {
          set justinc 1
          if {![catch {inc_range}]} continue
        }

        set status "OK"

        # measure the value
        set max_amp 0
        set ret {}
        foreach {c1 c2} $osc_ch {
          set v [$dev cmd filter -f lockin -c $osc_nch($c1),$osc_nch($c2) $sigfile]
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
        if {$autorange == 1 && $justinc == 0 && $status == {OK} && $max_amp < [expr 0.5*$range]} {
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
        $dev cmd trig_set NONE 0.1 FALLING 0
        # record signal
        $dev cmd block $osc_ach 0 $npt $dt $sigfile

        # check for overload
        set ovl 0
        foreach ch $osc_ch {
          if {[$dev cmd filter -c $osc_nch($ch) -f overload $sigfile]} {set ovl 1}
        }

        # try to increase the range and repeat
        if {$autorange == 1 && $ovl == 1} {
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
        set ret [$dev cmd filter -c $nch -f dc $sigfile]

        # if it is still overloaded
        if {$ovl == 1} {
          set status "OVL"
          break
        }

        # if amplitude is too small, try to decrease the range and repeat
        if {[llength $ret] > 1} { set max [expr max([join $ret ,])]}\
        else {set max $ret}
        if {$autorange == 1 && $justinc==0 && $max < [expr 0.5*$range]} {
          if {![catch {dec_range}]} continue
        }
        break
      }
      return $ret
    }
  }

  ############################
  method set_range  {val} {
    set n [lsearch -real -exact $ranges $val]
    if {$n<0} {error "unknown range setting: $val"}
    set range $val
    setup_osc_chans
  }
  method get_range {} {
    set c [lindex $osc_ch 0]
    set ch_cnf [$dev cmd chan_get $c]
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
  method conf_list {} {
    return [list {
      autorange  bool
      range      $ranges
      tconst     $tconsts
      names      const
      status     const
    }]
  }

  method conf_get {name} {
    switch -exact -- $name {
      autorange  { return $autorange}
      range      { return [get_range]}
      tconst     { return $tconst}
      names      { return $names}
      status     { return $status}
      default {error "unknown configuration name: $name"}
    }
  }

  method conf_set {name val} {
    switch -exact -- $name {
      autorange  { set autorange 1}
      range      { set_range $val}
      tconst     { set tconst $val}
      default {error "unknown configuration name: $name"}
    }
  }

}

######################################################################
# Use Picoscope ADC as a gauge.
#
# Channels:
#
#   <chan>(s|d), ...
#   Measure a few channels with same range/tconst settings.
#
# Configuration parameters:
#
#      range      <list>
#      tconst     <list>
#      names      const
#
# Parallel access: supported
#
# Tested:
#   2020/10/05, ADC24,   V.Z.

itcl::class picoADC {
  inherit interface
  proc test_id {id} {
    if {[regexp {pico_adc} $id]} {return 1}
  }

  common chans {};   # channels 1..16
  common modes {};   # 1: single,  0: differential
  common range 2500; # range or all channels
  common convt  180; # conversion time for all channels
  common names   {};

  constructor {d ch id} {

    set dev $d

    foreach v [split $ch ","] {
      if {![regexp {^([0-9]+)([sd])$} $v v0 vch vsd]} {
        error "wrong channel setting: $v" }
      set vs [expr {"$vsd"=="s"? 1:0}]
      if {!$vs && $vch%2 != 1} {
        error "can't set double-ended mode for even-numbered channel: $vch" }
      lappend chans $vch
      lappend modes $vs
    }

  }

  ############################
  method get {} {
    set ret {}
    foreach c $chans m $modes {
      lappend ret [$dev cmd get_val $c $m $range $convt]
    }
    return $ret
  }

  ############################
  method conf_list {} {
    return [list {
      range      [$dev cmd ranges]
      tconst     [$dev cmd tconvs]
      names      const
    }]
  }

  method conf_get {name} {
    switch -exact -- $name {
      range      {return $range}
      tconst     {return $convt}
      names      {return $chans}
      default {error "unknown configuration name: $name"}
    }
  }

  method conf_set {name val} {
    switch -exact -- $name {
      range      { set range $val}
      tconst     { set convt $val}
      default {error "unknown configuration name: $name"}
    }
  }

}

######################################################################
# Use Agilent VS leak detector as a gauge.
#

itcl::class leak_ag_vs {
  inherit interface
  proc test_id {id} {
    if {$id == {Agilent VS leak detector}} {return 1}
  }

  variable chan;  # channel to use

  constructor {d ch id} {
    # channels are not supported now
    set names [list "Leak" "Pout" "Pin"]
    set dev $d
  }

  ############################
  method get {} {
    set ret [$dev cmd "?LP"]

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
}

######################################################################
# Pfeiffer Adixen ASM340 leak detector
#

itcl::class leak_asm340 {
  inherit interface
  proc test_id {id} {
    if {$id == {Adixen ASM340 leak detector}} {return 1}
  }

  variable chan;  # channel to use

  constructor {d ch id} {
    # channels are not supported now
    set names [list "Leak" "Pin"]
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
    set pin   [conv_number [$dev cmd ?PE]]
    set leak  [conv_number [$dev cmd ?LE2]]
    return [list $leak $pin]
  }
}

######################################################################
} # namespace
