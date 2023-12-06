######################################################################
# Picoscope (via pico_osc program)
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

package require Itcl
package require Device2
namespace eval device_role::gauge {

itcl::class picoscope {
  inherit base
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

  constructor {args} {
    chain {*}$args
    set ch $dev_chan

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

    # oscilloscope ranges
    set ranges [lindex [split [Device2::ask $dev_name ranges A] "\n"] 0]
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
        Device2::ask $dev_name chan_set $c1 1 AC $range
        if {$c1 != $c2} { Device2::ask $dev_name chan_set $c2 1 AC $range_ref }
        }
    }
    if {$osc_meas=="DC"} {
        # oscilloscope setup
        foreach ch $osc_ch {
          Device2::ask $dev_name chan_set $ch 1 DC $range
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
        Device2::ask $dev_name trig_set NONE 0.1 FALLING 0
        # record signal
        Device2::ask $dev_name block $osc_ach 0 $npt $dt $sigfile

        # check for overload (any signal channel)
        set ovl 0
        foreach {c1 c2} $osc_ch {
          if {[Device2::ask $dev_name filter -c $osc_nch($c1) -f overload $sigfile]} {set ovl 1}
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
          set v [Device2::ask $dev_name filter -f lockin -c $osc_nch($c1),$osc_nch($c2) $sigfile]
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
        Device2::ask $dev_name trig_set NONE 0.1 FALLING 0
        # record signal
        Device2::ask $dev_name block $osc_ach 0 $npt $dt $sigfile

        # check for overload
        set ovl 0
        foreach ch $osc_ch {
          if {[Device2::ask $dev_name filter -c $osc_nch($ch) -f overload $sigfile]} {set ovl 1}
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
        set ret [Device2::ask $dev_name filter -c $nch -f dc $sigfile]

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
    set res [Device2::ask $dev_name chan_get $c]
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

}; # namespace
