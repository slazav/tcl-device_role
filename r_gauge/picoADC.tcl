######################################################################
# Picoscope ADC (via pico_adc program)
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

package require Itcl
package require Device2
namespace eval device_role::gauge {

itcl::class picoADC {
  inherit base
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

}; # namespace
